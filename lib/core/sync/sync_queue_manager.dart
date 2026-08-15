import 'dart:convert';
import 'package:drift/drift.dart';
import 'package:uuid/uuid.dart';
import '../database/app_database.dart';

class SyncQueueManager {
  final AppDatabase _db;
  final Uuid _uuid;

  SyncQueueManager(this._db, {Uuid? uuid}) : _uuid = uuid ?? const Uuid();

  /// Registra una operación local pendiente en la cola de sincronización.
  Future<String> enqueueOperation({
    required String entityType,
    required String entityId,
    required String operation, // CREATE, UPDATE, DELETE
    required Map<String, dynamic> payload,
    int? baseVersion,
  }) async {
    final operationId = _uuid.v4();
    final now = DateTime.now().toUtc();

    await _db.into(_db.syncQueueTable).insert(
          SyncQueueTableCompanion.insert(
            operationId: operationId,
            entityType: entityType,
            entityId: entityId,
            operation: operation,
            payload: jsonEncode(payload),
            clientTimestamp: now,
            baseVersion: Value(baseVersion),
            status: const Value('PENDING'),
            retryCount: const Value(0),
            createdAt: now,
          ),
        );

    return operationId;
  }

  static int _entityPriority(String entityType) {
    switch (entityType.toLowerCase()) {
      case 'expense_category':
        return 1;
      case 'dish':
        return 2;
      case 'daily_menu':
        return 3;
      case 'expense':
        return 4;
      case 'order':
        return 5;
      default:
        return 10;
    }
  }

  /// Obtiene operaciones pendientes para enviar al servidor ordenadas por prioridad de dependencias y fecha.
  Future<List<SyncQueueTableData>> getPendingOperations({int limit = 100}) async {
    final ops = await (_db.select(_db.syncQueueTable)
          ..where((t) => t.status.equals('PENDING'))
          ..orderBy([(t) => OrderingTerm(expression: t.createdAt, mode: OrderingMode.asc)])
          ..limit(limit))
        .get();

    final sortedOps = List<SyncQueueTableData>.from(ops);
    sortedOps.sort((a, b) {
      final prioA = _entityPriority(a.entityType);
      final prioB = _entityPriority(b.entityType);
      if (prioA != prioB) {
        return prioA.compareTo(prioB);
      }
      return a.createdAt.compareTo(b.createdAt);
    });

    return sortedOps;
  }

  /// Actualiza el estado de una operación en la cola.
  Future<void> markOperationStatus(
    String operationId,
    String status, {
    String? error,
  }) async {
    final existing = await (_db.select(_db.syncQueueTable)..where((t) => t.operationId.equals(operationId))).getSingleOrNull();
    final nextRetry = status == 'FAILED' ? ((existing?.retryCount ?? 0) + 1) : (existing?.retryCount ?? 0);

    await (_db.update(_db.syncQueueTable)..where((t) => t.operationId.equals(operationId))).write(
      SyncQueueTableCompanion(
        status: Value(status),
        lastError: Value(error),
        retryCount: Value(nextRetry),
      ),
    );
  }

  /// Elimina operaciones sincronizadas exitosamente.
  Future<void> removeSyncedOperations() async {
    await (_db.delete(_db.syncQueueTable)..where((t) => t.status.equals('SYNCED'))).go();
  }
}
