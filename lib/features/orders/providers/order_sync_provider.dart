import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:uuid/uuid.dart';

import '../../../core/database/app_database.dart';
import '../../../core/sync/sync_queue.dart';
import 'order_provider.dart';

/// Lightweight reachability probe (DNS lookup with a short timeout).
/// Offline is a working state, not an error — this only drives the banner
/// and the auto-replay of queued orders.
Future<bool> hasNetwork() async {
  try {
    final result = await InternetAddress.lookup('supabase.com')
        .timeout(const Duration(seconds: 3));
    return result.isNotEmpty && result.first.rawAddress.isNotEmpty;
  } catch (_) {
    return false;
  }
}

/// Offline-first order queue backed by the existing Drift sync queue
/// ([SyncQueueManager] over the shared [AppDatabase]).
///
/// Orders are created through the `create_order_atomic` RPC, so replay goes
/// back through [OrderRepository.create] rather than the generic table-level
/// sync service. Persistence, retry counting (skip after 3) and cleanup all
/// reuse the existing queue table.
final offlineOrderQueueProvider = Provider<OfflineOrderQueue>((ref) {
  return OfflineOrderQueue(SyncQueueManager(AppDatabase.instance), ref);
});

/// Number of orders currently waiting in the local sync queue.
final pendingOrderSyncCountProvider = FutureProvider<int>((ref) async {
  return ref.watch(offlineOrderQueueProvider).pendingCount();
});

class OfflineOrderQueue {
  OfflineOrderQueue(this._manager, this._ref);

  final SyncQueueManager _manager;
  final Ref _ref;

  static const _table = 'orders';

  /// Persist an order locally for later sync ("يُحفظ محلياً ويُزامن تلقائياً").
  Future<String> enqueue({
    required String storeId,
    required String storeName,
    required double subtotal,
    required double taxPercentage,
    required double taxAmount,
    required double discount,
    required String discountStatus,
    required double total,
    required List<Map<String, dynamic>> lineItems,
  }) async {
    final recordId = const Uuid().v4();
    await _manager.enqueue(
      targetTable: _table,
      operation: 'insert',
      recordId: recordId,
      payload: jsonEncode({
        'store_id': storeId,
        'store_name': storeName,
        'subtotal': subtotal,
        'tax_percentage': taxPercentage,
        'tax_amount': taxAmount,
        'discount': discount,
        'discount_status': discountStatus,
        'total': total,
        'line_items': lineItems,
        'queued_at': DateTime.now().toUtc().toIso8601String(),
      }),
    );
    return recordId;
  }

  /// Pending (unsynced, retryable) queued orders.
  Future<int> pendingCount() async {
    final pending = await _manager.getPending();
    return pending.where((e) => e.targetTable == _table).length;
  }

  /// Replay queued orders through the atomic order RPC.
  ///
  /// Returns the number successfully synced. Failed items get their retry
  /// count incremented by the queue manager and are skipped after 3 tries.
  Future<int> processPending() async {
    final repo = _ref.read(orderRepositoryProvider);
    if (repo == null) return 0;

    final pending = await _manager.getPending();
    var synced = 0;
    for (final item in pending) {
      if (item.targetTable != _table) continue;
      try {
        final data = jsonDecode(item.payload) as Map<String, dynamic>;
        await repo.create(
          storeId: data['store_id'] as String,
          subtotal: (data['subtotal'] as num).toDouble(),
          taxPercentage: (data['tax_percentage'] as num).toDouble(),
          taxAmount: (data['tax_amount'] as num).toDouble(),
          discount: (data['discount'] as num).toDouble(),
          discountStatus: data['discount_status'] as String,
          total: (data['total'] as num).toDouble(),
          lineItems: List<Map<String, dynamic>>.from(
            (data['line_items'] as List)
                .map((e) => Map<String, dynamic>.from(e as Map)),
          ),
        );
        await _manager.markSynced(item.id);
        synced++;
      } catch (e) {
        await _manager.markFailed(item.id, e.toString());
      }
    }
    await _manager.cleanupSynced();
    return synced;
  }
}
