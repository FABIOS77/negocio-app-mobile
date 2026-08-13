import '../../../core/database/app_database.dart';

class SyncDiagnosticsSummary {
  final int pendingCreateCount;
  final int pendingUpdateCount;
  final int pendingDeleteCount;
  final int totalPendingCount;
  final String lastCursor;
  final List<SyncQueueTableData> conflicts;

  SyncDiagnosticsSummary({
    required this.pendingCreateCount,
    required this.pendingUpdateCount,
    required this.pendingDeleteCount,
    required this.totalPendingCount,
    required this.lastCursor,
    required this.conflicts,
  });
}

class SyncDiagnosticsRepository {
  final AppDatabase _db;

  SyncDiagnosticsRepository({required AppDatabase db}) : _db = db;

  /// Observa reactivamente el resumen de diagnóstico de sincronización en SQLite
  Stream<SyncDiagnosticsSummary> watchDiagnosticsSummary() {
    final queueStream = _db.select(_db.syncQueueTable).watch();
    final metadataStream = _db.select(_db.syncMetadataTable).watch();

    return queueStream.asyncMap((queueItems) async {
      final metadataItems = await metadataStream.first;

      final pendingCreate = queueItems.where((i) => i.status == 'PENDING' && i.operation == 'CREATE').length;
      final pendingUpdate = queueItems.where((i) => i.status == 'PENDING' && i.operation == 'UPDATE').length;
      final pendingDelete = queueItems.where((i) => i.status == 'PENDING' && i.operation == 'DELETE').length;
      final totalPending = queueItems.where((i) => i.status == 'PENDING').length;

      final lastCursorRecord = metadataItems.where((m) => m.key == 'last_cursor');
      final lastCursor = lastCursorRecord.isNotEmpty ? lastCursorRecord.first.value : '0';
      final conflicts = queueItems.where((i) => i.status == 'CONFLICT').toList();

      return SyncDiagnosticsSummary(
        pendingCreateCount: pendingCreate,
        pendingUpdateCount: pendingUpdate,
        pendingDeleteCount: pendingDelete,
        totalPendingCount: totalPending,
        lastCursor: lastCursor,
        conflicts: conflicts,
      );
    });
  }
}
