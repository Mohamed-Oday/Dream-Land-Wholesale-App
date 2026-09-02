import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'package:tawzii/features/auth/providers/auth_provider.dart';
import 'package:tawzii/features/receipts/models/receipt_config.dart';

/// The business phone and footer for the current user's business.
/// Resolves to [ReceiptConfig.empty] when signed out or when the read fails,
/// so a receipt can always be printed.
final receiptConfigProvider = FutureProvider<ReceiptConfig>((ref) async {
  final user = ref.watch(currentUserProvider);
  if (user == null) return ReceiptConfig.empty;
  try {
    final rows = await Supabase.instance.client
        .from('app_config')
        .select('key, value')
        .eq('business_id', user.businessId)
        .inFilter('key', [ReceiptConfig.phoneKey, ReceiptConfig.footerKey]);
    return ReceiptConfig.fromRows(List<Map<String, dynamic>>.from(rows));
  } catch (e) {
    debugPrint('receipt config read failed: $e');
    return ReceiptConfig.empty;
  }
});
