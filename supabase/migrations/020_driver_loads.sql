-- ============================================================
-- Migration 020: Driver Stock Loading & Shifts
-- Creates driver_loads + driver_load_items tables, RPCs, RLS
-- ============================================================

-- ── PREREQUISITE: Extend stock_movements CHECK constraint ────
ALTER TABLE stock_movements DROP CONSTRAINT stock_movements_movement_type_check;
ALTER TABLE stock_movements ADD CONSTRAINT stock_movements_movement_type_check
  CHECK (movement_type IN ('order_out', 'purchase_in', 'cancellation_restore', 'adjustment', 'load_out', 'load_return'));


-- ============================================================
-- 1. Tables
-- ============================================================

-- driver_loads: One active load per driver at a time
CREATE TABLE driver_loads (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  business_id UUID NOT NULL,
  driver_id UUID NOT NULL REFERENCES users(id),
  loaded_by UUID NOT NULL DEFAULT auth.uid() REFERENCES users(id),
  status TEXT NOT NULL DEFAULT 'active' CHECK (status IN ('active', 'closed')),
  opened_at TIMESTAMPTZ NOT NULL DEFAULT now(),
  closed_at TIMESTAMPTZ,
  notes TEXT,
  created_at TIMESTAMPTZ NOT NULL DEFAULT now(),
  updated_at TIMESTAMPTZ NOT NULL DEFAULT now()
);

-- driver_load_items: Products loaded onto the driver
CREATE TABLE driver_load_items (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  load_id UUID NOT NULL REFERENCES driver_loads(id) ON DELETE CASCADE,
  product_id UUID NOT NULL REFERENCES products(id),
  quantity_loaded INTEGER NOT NULL CHECK (quantity_loaded > 0),
  quantity_sold INTEGER NOT NULL DEFAULT 0 CHECK (quantity_sold >= 0),
  quantity_returned INTEGER NOT NULL DEFAULT 0 CHECK (quantity_returned >= 0),
  created_at TIMESTAMPTZ NOT NULL DEFAULT now(),
  UNIQUE(load_id, product_id)
);


-- ============================================================
-- 2. Indexes
-- ============================================================

-- Enforce one active load per driver at database level
CREATE UNIQUE INDEX idx_driver_loads_one_active
  ON driver_loads (driver_id) WHERE status = 'active';

CREATE INDEX idx_driver_loads_business ON driver_loads(business_id);
CREATE INDEX idx_driver_loads_driver_status ON driver_loads(driver_id, status);
CREATE INDEX idx_driver_load_items_load ON driver_load_items(load_id);


-- ============================================================
-- 3. Triggers
-- ============================================================

-- Reuse existing set_updated_at() from migration 018
CREATE TRIGGER set_driver_loads_updated_at
  BEFORE UPDATE ON driver_loads
  FOR EACH ROW EXECUTE FUNCTION set_updated_at();


-- ============================================================
-- 4. RLS Policies — driver_loads
-- ============================================================

ALTER TABLE driver_loads ENABLE ROW LEVEL SECURITY;

-- Owner/admin: see all loads for their business
CREATE POLICY driver_loads_owner_admin_select ON driver_loads
  FOR SELECT
  USING (
    get_user_role() IN ('owner', 'admin')
    AND business_id = get_user_business_id()
  );

-- Driver: see only own loads
CREATE POLICY driver_loads_driver_select ON driver_loads
  FOR SELECT
  USING (
    get_user_role() = 'driver'
    AND driver_id = auth.uid()
  );

-- No direct INSERT/UPDATE/DELETE — all mutations through SECURITY DEFINER RPCs


-- ============================================================
-- 5. RLS Policies — driver_load_items (explicit per-table)
-- ============================================================

ALTER TABLE driver_load_items ENABLE ROW LEVEL SECURITY;

-- Owner/admin: see items for loads in their business
CREATE POLICY driver_load_items_owner_admin_select ON driver_load_items
  FOR SELECT USING (EXISTS (
    SELECT 1 FROM driver_loads dl
    WHERE dl.id = driver_load_items.load_id
    AND dl.business_id = get_user_business_id()
    AND get_user_role() IN ('owner', 'admin')
  ));

-- Driver: see items for own loads only
CREATE POLICY driver_load_items_driver_select ON driver_load_items
  FOR SELECT USING (EXISTS (
    SELECT 1 FROM driver_loads dl
    WHERE dl.id = driver_load_items.load_id
    AND dl.driver_id = auth.uid()
    AND get_user_role() = 'driver'
  ));

-- No direct INSERT/UPDATE/DELETE — managed by RPCs


-- ============================================================
-- 6. RPC: create_driver_load
-- ============================================================

CREATE OR REPLACE FUNCTION create_driver_load(
  p_business_id UUID,
  p_driver_id UUID,
  p_items JSONB,
  p_notes TEXT DEFAULT NULL
)
RETURNS UUID AS $$
DECLARE
  v_load_id UUID;
  v_item RECORD;
  v_product_id UUID;
  v_quantity INTEGER;
  v_stock INTEGER;
BEGIN
  -- ── Auth check ─────────────────────────────────────────────
  IF get_user_role() NOT IN ('owner', 'admin') THEN
    RAISE EXCEPTION 'unauthorized: only owner/admin can create loads';
  END IF;

  IF p_business_id != get_user_business_id() THEN
    RAISE EXCEPTION 'unauthorized: business_id mismatch';
  END IF;

  -- ── Driver validation ──────────────────────────────────────
  IF NOT EXISTS (
    SELECT 1 FROM users
    WHERE id = p_driver_id AND role = 'driver' AND business_id = p_business_id
  ) THEN
    RAISE EXCEPTION 'invalid_driver: driver not found in business';
  END IF;

  -- ── Empty items guard ──────────────────────────────────────
  IF p_items IS NULL OR jsonb_array_length(p_items) = 0 THEN
    RAISE EXCEPTION 'invalid_items: at least one product required';
  END IF;

  -- ── One active load per driver guard ───────────────────────
  IF EXISTS (
    SELECT 1 FROM driver_loads
    WHERE driver_id = p_driver_id AND status = 'active'
  ) THEN
    RAISE EXCEPTION 'driver_has_active_load';
  END IF;

  -- ── Validate all items + lock product rows ─────────────────
  FOR v_item IN SELECT * FROM jsonb_array_elements(p_items)
  LOOP
    v_product_id := (v_item.value->>'product_id')::UUID;
    v_quantity := (v_item.value->>'quantity')::INTEGER;

    SELECT stock_on_hand INTO v_stock
    FROM products
    WHERE id = v_product_id AND business_id = p_business_id
    FOR UPDATE;

    IF NOT FOUND THEN
      RAISE EXCEPTION 'invalid_product: product % not found', v_product_id;
    END IF;

    IF v_stock < v_quantity THEN
      RAISE EXCEPTION 'insufficient_stock: product % has % but requested %',
        v_product_id, v_stock, v_quantity;
    END IF;
  END LOOP;

  -- ── Step 1: Create driver_loads record ─────────────────────
  INSERT INTO driver_loads (business_id, driver_id, notes)
  VALUES (p_business_id, p_driver_id, p_notes)
  RETURNING id INTO v_load_id;

  -- ── Step 2: Insert items + deduct stock + log movements ────
  FOR v_item IN SELECT * FROM jsonb_array_elements(p_items)
  LOOP
    v_product_id := (v_item.value->>'product_id')::UUID;
    v_quantity := (v_item.value->>'quantity')::INTEGER;

    -- Insert load item
    INSERT INTO driver_load_items (load_id, product_id, quantity_loaded)
    VALUES (v_load_id, v_product_id, v_quantity);

    -- Deduct from warehouse stock
    UPDATE products
    SET stock_on_hand = stock_on_hand - v_quantity
    WHERE id = v_product_id;

    -- Log stock movement
    INSERT INTO stock_movements (
      business_id, product_id, movement_type,
      quantity, reference_id, created_by
    ) VALUES (
      p_business_id,
      v_product_id,
      'load_out',
      -v_quantity,
      v_load_id,
      auth.uid()
    );
  END LOOP;

  RETURN v_load_id;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;


-- ============================================================
-- 7. RPC: get_driver_loads
-- ============================================================

CREATE OR REPLACE FUNCTION get_driver_loads(p_business_id UUID)
RETURNS TABLE (
  id UUID,
  driver_id UUID,
  driver_name TEXT,
  loaded_by UUID,
  loaded_by_name TEXT,
  status TEXT,
  opened_at TIMESTAMPTZ,
  closed_at TIMESTAMPTZ,
  notes TEXT,
  item_count BIGINT,
  total_quantity BIGINT
) AS $$
BEGIN
  -- Auth check
  IF get_user_role() IS NULL THEN
    RAISE EXCEPTION 'unauthorized: not authenticated';
  END IF;

  IF p_business_id != get_user_business_id() THEN
    RAISE EXCEPTION 'unauthorized: business_id mismatch';
  END IF;

  RETURN QUERY
  SELECT
    dl.id,
    dl.driver_id,
    du.name::TEXT AS driver_name,
    dl.loaded_by,
    lu.name::TEXT AS loaded_by_name,
    dl.status,
    dl.opened_at,
    dl.closed_at,
    dl.notes,
    COALESCE(COUNT(dli.id), 0) AS item_count,
    COALESCE(SUM(dli.quantity_loaded), 0) AS total_quantity
  FROM driver_loads dl
  JOIN users du ON du.id = dl.driver_id
  JOIN users lu ON lu.id = dl.loaded_by
  LEFT JOIN driver_load_items dli ON dli.load_id = dl.id
  WHERE dl.business_id = p_business_id
    AND (
      get_user_role() IN ('owner', 'admin')
      OR (get_user_role() = 'driver' AND dl.driver_id = auth.uid())
    )
  GROUP BY dl.id, dl.driver_id, du.name, dl.loaded_by, lu.name,
           dl.status, dl.opened_at, dl.closed_at, dl.notes
  ORDER BY dl.opened_at DESC;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;


-- ============================================================
-- 8. Grants
-- ============================================================

REVOKE EXECUTE ON FUNCTION create_driver_load(UUID, UUID, JSONB, TEXT) FROM PUBLIC;
GRANT EXECUTE ON FUNCTION create_driver_load(UUID, UUID, JSONB, TEXT) TO authenticated;

REVOKE EXECUTE ON FUNCTION get_driver_loads(UUID) FROM PUBLIC;
GRANT EXECUTE ON FUNCTION get_driver_loads(UUID) TO authenticated;
