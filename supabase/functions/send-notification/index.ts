// Edge Function: send-notification
// Sends push notifications via FCM v1 API to business owner/admin devices.
// Called from Flutter client after order, payment, discount, stock, and shift events.

import { createClient } from "https://esm.sh/@supabase/supabase-js@2";

// ── Types ──────────────────────────────────────────────────

type EventType =
  | "new_order"
  | "payment_collected"
  | "discount_pending"
  | "low_stock"
  | "shift_opened"
  | "shift_closed";

const ALLOWED_EVENTS: EventType[] = [
  "new_order",
  "payment_collected",
  "discount_pending",
  "low_stock",
  "shift_opened",
  "shift_closed",
];

interface NotificationRequest {
  event_type: string;
  data: Record<string, string>;
}

// ── OAuth2 Token Cache (module-level, persists across warm invocations) ──

let cachedAccessToken: string | null = null;
let tokenExpiresAt = 0;

// ── Notification Content (Arabic) ──────────────────────────

function buildNotification(
  eventType: EventType,
  data: Record<string, string>
): { title: string; body: string } {
  switch (eventType) {
    case "new_order":
      return {
        title: "طلب جديد",
        body: `طلب جديد من ${data.driver || ""} في ${data.store || ""}`,
      };
    case "payment_collected":
      return {
        title: "تحصيل دفعة",
        body: `${data.driver || ""} حصّل ${data.amount || ""} د.ج من ${data.store || ""}`,
      };
    case "discount_pending":
      return {
        title: "طلب خصم",
        body: `${data.driver || ""} يطلب خصم ${data.amount || ""} د.ج في ${data.store || ""}`,
      };
    case "low_stock":
      return {
        title: "مخزون منخفض",
        body: `${data.product || ""}: بقي ${data.quantity || ""} فقط`,
      };
    case "shift_opened":
      return {
        title: "بداية وردية",
        body: `${data.driver || ""} بدأ وردية جديدة`,
      };
    case "shift_closed":
      return {
        title: "نهاية وردية",
        body: `${data.driver || ""} أنهى ورديته`,
      };
  }
}

// ── Target Roles Per Event ─────────────────────────────────

function getTargetRoles(eventType: EventType): string[] {
  if (eventType === "discount_pending") {
    return ["owner"];
  }
  return ["owner", "admin"];
}

// ── OAuth2 Token Generation ────────────────────────────────

async function getAccessToken(
  serviceAccount: { client_email: string; private_key: string; project_id: string }
): Promise<string> {
  // Return cached token if still valid (5-minute buffer)
  const now = Math.floor(Date.now() / 1000);
  if (cachedAccessToken && tokenExpiresAt > now + 300) {
    return cachedAccessToken;
  }

  // Build JWT header + payload
  const header = { alg: "RS256", typ: "JWT" };
  const payload = {
    iss: serviceAccount.client_email,
    sub: serviceAccount.client_email,
    aud: "https://oauth2.googleapis.com/token",
    scope: "https://www.googleapis.com/auth/firebase.messaging",
    iat: now,
    exp: now + 3600,
  };

  // Encode header and payload
  const encoder = new TextEncoder();
  const headerB64 = base64urlEncode(encoder.encode(JSON.stringify(header)));
  const payloadB64 = base64urlEncode(encoder.encode(JSON.stringify(payload)));
  const unsignedToken = `${headerB64}.${payloadB64}`;

  // Sign with RS256
  const privateKey = await crypto.subtle.importKey(
    "pkcs8",
    pemToBinary(serviceAccount.private_key),
    { name: "RSASSA-PKCS1-v1_5", hash: "SHA-256" },
    false,
    ["sign"]
  );

  const signature = await crypto.subtle.sign(
    "RSASSA-PKCS1-v1_5",
    privateKey,
    encoder.encode(unsignedToken)
  );

  const jwt = `${unsignedToken}.${base64urlEncode(new Uint8Array(signature))}`;

  // Exchange JWT for access token
  const tokenResponse = await fetch("https://oauth2.googleapis.com/token", {
    method: "POST",
    headers: { "Content-Type": "application/x-www-form-urlencoded" },
    body: `grant_type=urn%3Aietf%3Aparams%3Aoauth%3Agrant-type%3Ajwt-bearer&assertion=${jwt}`,
  });

  if (!tokenResponse.ok) {
    const error = await tokenResponse.text();
    throw new Error(`OAuth2 token exchange failed: ${error}`);
  }

  const tokenData = await tokenResponse.json();
  cachedAccessToken = tokenData.access_token;
  tokenExpiresAt = now + (tokenData.expires_in || 3600);

  return cachedAccessToken!;
}

// ── Utility: PEM to binary ─────────────────────────────────

function pemToBinary(pem: string): ArrayBuffer {
  const lines = pem.split("\n");
  const base64 = lines
    .filter((line) => !line.startsWith("-----"))
    .join("");
  const binary = atob(base64);
  const buffer = new Uint8Array(binary.length);
  for (let i = 0; i < binary.length; i++) {
    buffer[i] = binary.charCodeAt(i);
  }
  return buffer.buffer;
}

// ── Utility: Base64url encoding ────────────────────────────

function base64urlEncode(data: Uint8Array): string {
  const base64 = btoa(String.fromCharCode(...data));
  return base64.replace(/\+/g, "-").replace(/\//g, "_").replace(/=+$/, "");
}

// ── Send single FCM message ────────────────────────────────

async function sendFcmMessage(
  accessToken: string,
  projectId: string,
  deviceToken: string,
  title: string,
  body: string,
  data: Record<string, string>
): Promise<{ success: boolean; unregistered: boolean }> {
  const response = await fetch(
    `https://fcm.googleapis.com/v1/projects/${projectId}/messages:send`,
    {
      method: "POST",
      headers: {
        Authorization: `Bearer ${accessToken}`,
        "Content-Type": "application/json",
      },
      body: JSON.stringify({
        message: {
          token: deviceToken,
          notification: { title, body },
          data: Object.fromEntries(
            Object.entries(data).map(([k, v]) => [k, String(v)])
          ),
          android: { priority: "high" },
        },
      }),
    }
  );

  if (response.ok) {
    return { success: true, unregistered: false };
  }

  // Check for unregistered/stale token
  const errorBody = await response.text();
  const isUnregistered =
    errorBody.includes("UNREGISTERED") || errorBody.includes("NOT_FOUND");

  return { success: false, unregistered: isUnregistered };
}

// ── CORS Headers ───────────────────────────────────────────

const corsHeaders = {
  "Access-Control-Allow-Origin": "*",
  "Access-Control-Allow-Headers":
    "authorization, x-client-info, apikey, content-type",
};

// ── Main Handler ───────────────────────────────────────────

Deno.serve(async (req: Request) => {
  // Handle CORS preflight
  if (req.method === "OPTIONS") {
    return new Response("ok", { headers: corsHeaders });
  }

  try {
    // 1. Verify auth header
    const authHeader = req.headers.get("Authorization");
    if (!authHeader) {
      return new Response(
        JSON.stringify({ error: "Missing Authorization header" }),
        { status: 401, headers: { ...corsHeaders, "Content-Type": "application/json" } }
      );
    }

    // 2. Parse request body
    const { event_type, data }: NotificationRequest = await req.json();

    // 3. Validate event_type against allowed values
    if (!event_type || !ALLOWED_EVENTS.includes(event_type as EventType)) {
      return new Response(
        JSON.stringify({
          error: "unknown event_type",
          allowed: ALLOWED_EVENTS,
        }),
        { status: 400, headers: { ...corsHeaders, "Content-Type": "application/json" } }
      );
    }

    // 4. Create Supabase client with service_role
    const supabaseUrl = Deno.env.get("SUPABASE_URL")!;
    const serviceRoleKey = Deno.env.get("SUPABASE_SERVICE_ROLE_KEY")!;
    const supabase = createClient(supabaseUrl, serviceRoleKey);

    // 5. Get caller info from JWT
    const token = authHeader.replace("Bearer ", "");
    const {
      data: { user },
      error: userError,
    } = await supabase.auth.getUser(token);

    if (userError || !user) {
      return new Response(
        JSON.stringify({ error: "Invalid auth token" }),
        { status: 401, headers: { ...corsHeaders, "Content-Type": "application/json" } }
      );
    }

    const businessId = user.user_metadata?.business_id;

    // 6. Validate business_id is non-null
    if (!businessId) {
      return new Response(
        JSON.stringify({ error: "missing business_id in user metadata" }),
        { status: 400, headers: { ...corsHeaders, "Content-Type": "application/json" } }
      );
    }

    // 7. Get target FCM tokens (excluding caller)
    const targetRoles = getTargetRoles(event_type as EventType);
    const { data: tokens, error: tokensError } = await supabase.rpc(
      "get_fcm_tokens_for_business",
      {
        p_business_id: businessId,
        p_roles: targetRoles,
        p_exclude_user: user.id,
        p_event_type: event_type,
      }
    );

    if (tokensError) {
      console.error("Error fetching tokens:", tokensError);
      return new Response(
        JSON.stringify({ error: "Failed to fetch tokens" }),
        { status: 500, headers: { ...corsHeaders, "Content-Type": "application/json" } }
      );
    }

    if (!tokens || tokens.length === 0) {
      return new Response(
        JSON.stringify({ sent: 0, failed: 0 }),
        { status: 200, headers: { ...corsHeaders, "Content-Type": "application/json" } }
      );
    }

    // 8. Load FCM service account
    const fcmServiceAccountRaw = Deno.env.get("FCM_SERVICE_ACCOUNT");
    if (!fcmServiceAccountRaw) {
      return new Response(
        JSON.stringify({ error: "FCM not configured" }),
        { status: 503, headers: { ...corsHeaders, "Content-Type": "application/json" } }
      );
    }

    let serviceAccount: {
      client_email: string;
      private_key: string;
      project_id: string;
    };
    try {
      serviceAccount = JSON.parse(fcmServiceAccountRaw);
    } catch {
      return new Response(
        JSON.stringify({ error: "FCM service account malformed" }),
        { status: 503, headers: { ...corsHeaders, "Content-Type": "application/json" } }
      );
    }

    // 9. Get FCM access token (cached)
    const accessToken = await getAccessToken(serviceAccount);

    // 10. Build notification content
    const { title, body } = buildNotification(
      event_type as EventType,
      data || {}
    );

    // 11. Send to all target devices
    let sent = 0;
    let failed = 0;
    const staleTokenIds: string[] = [];

    const results = await Promise.allSettled(
      tokens.map(
        async (t: { user_id: string; device_token: string }) => {
          const result = await sendFcmMessage(
            accessToken,
            serviceAccount.project_id,
            t.device_token,
            title,
            body,
            { event_type, ...(data || {}) }
          );

          if (result.success) {
            sent++;
          } else {
            failed++;
            if (result.unregistered) {
              staleTokenIds.push(t.device_token);
            }
          }
        }
      )
    );

    // 12. Clean up stale tokens
    for (const staleToken of staleTokenIds) {
      await supabase
        .from("fcm_tokens")
        .delete()
        .eq("device_token", staleToken);
    }

    return new Response(
      JSON.stringify({ sent, failed, stale_cleaned: staleTokenIds.length }),
      { status: 200, headers: { ...corsHeaders, "Content-Type": "application/json" } }
    );
  } catch (error) {
    console.error("send-notification error:", error);
    return new Response(
      JSON.stringify({ error: "Internal server error" }),
      { status: 500, headers: { ...corsHeaders, "Content-Type": "application/json" } }
    );
  }
});
