import 'dart:convert';

import 'package:supabase_flutter/supabase_flutter.dart';

import '../database/app_database.dart';
import 'sync_queue.dart';

/// Processes the sync queue by pushing pending operations to Supabase.
///
/// Conflict resolution: server timestamp wins.
/// Error handling: increment retry_count, skip after 3 retries.
class SyncService {
  final SyncQueueManager _queueManager;
  final SupabaseClient _supabase;

  SyncService({
    required SyncQueueManager queueManager,
    required SupabaseClient supabase,
  })  : _queueManager = queueManager,
        _supabase = supabase;

  /// Process all pending items in the sync queue.
  ///
  /// Items are processed in order (FIFO by created_at).
  /// Failed items have their retry_count incremented.
  /// Items with retry_count >= 3 are skipped.
  Future<SyncResult> processQueue() async {
    final pending = await _queueManager.getPending();
    int synced = 0;
    int failed = 0;

    for (final item in pending) {
      try {
        await _syncItem(item);
        await _queueManager.markSynced(item.id);
        synced++;
      } catch (e) {
        await _queueManager.markFailed(item.id, e.toString());
        failed++;
      }
    }

    // Clean up synced items to keep the queue lean
    await _queueManager.cleanupSynced();

    return SyncResult(synced: synced, failed: failed, total: pending.length);
  }

  Future<void> _syncItem(SyncQueueData item) async {
    final data = jsonDecode(item.payload) as Map<String, dynamic>;

    switch (item.operation) {
      case 'insert':
        await _supabase.from(item.targetTable).insert(data);
      case 'update':
        await _supabase
            .from(item.targetTable)
            .update(data)
            .eq('id', item.recordId);
      case 'delete':
        await _supabase.from(item.targetTable).delete().eq('id', item.recordId);
      default:
        throw UnsupportedError('Unknown sync operation: ${item.operation}');
    }
  }
}

class SyncResult {
  final int synced;
  final int failed;
  final int total;

  const SyncResult({
    required this.synced,
    required this.failed,
    required this.total,
  });

  bool get hasFailures => failed > 0;
  bool get allSynced => synced == total;
}
