import 'package:drift/drift.dart';
import '../database/app_database.dart';

/// Manages the local sync queue for offline-first operations.
///
/// All write operations are first stored locally, then synced
/// to Supabase when connectivity is available.
class SyncQueueManager {
  final AppDatabase _db;

  SyncQueueManager(this._db);

  /// Enqueue a write operation for later sync.
  Future<void> enqueue({
    required String targetTable,
    required String operation,
    required String recordId,
    required String payload,
  }) async {
    await _db.into(_db.syncQueue).insert(
          SyncQueueCompanion.insert(
            targetTable: targetTable,
            operation: operation,
            recordId: recordId,
            payload: payload,
          ),
        );
  }

  /// Get all pending (unsynced) items ordered by creation time.
  Future<List<SyncQueueData>> getPending() async {
    return (_db.select(_db.syncQueue)
          ..where((t) => t.synced.equals(false))
          ..where((t) => t.retryCount.isSmallerThanValue(3))
          ..orderBy([(t) => OrderingTerm.asc(t.createdAt)]))
        .get();
  }

  /// Mark an item as successfully synced.
  Future<void> markSynced(int id) async {
    await (_db.update(_db.syncQueue)..where((t) => t.id.equals(id))).write(
      const SyncQueueCompanion(synced: Value(true)),
    );
  }

  /// Mark an item as failed with error message and increment retry count.
  Future<void> markFailed(int id, String errorMessage) async {
    final item = await (_db.select(_db.syncQueue)
          ..where((t) => t.id.equals(id)))
        .getSingle();

    await (_db.update(_db.syncQueue)..where((t) => t.id.equals(id))).write(
      SyncQueueCompanion(
        retryCount: Value(item.retryCount + 1),
        errorMessage: Value(errorMessage),
      ),
    );
  }

  /// Delete all synced items to keep the queue lean.
  Future<int> cleanupSynced() async {
    return (_db.delete(_db.syncQueue)
          ..where((t) => t.synced.equals(true)))
        .go();
  }

  /// Get count of pending items.
  Future<int> pendingCount() async {
    final count = _db.syncQueue.id.count();
    final query = _db.selectOnly(_db.syncQueue)
      ..addColumns([count])
      ..where(_db.syncQueue.synced.equals(false));
    final result = await query.getSingle();
    return result.read(count) ?? 0;
  }
}
