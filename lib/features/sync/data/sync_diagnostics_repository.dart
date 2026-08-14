import 'package:drift/drift.dart';
import '../../../core/database/app_database.dart';
import '../../../core/utils/timezone_utils.dart';

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

  /// Rescata operaciones fallidas (FAILED) en SyncQueueTable restableciendo su estado a PENDING y retryCount = 0
  Future<int> retryFailedOperations() async {
    return await (_db.update(_db.syncQueueTable)
          ..where((t) => t.status.equals('FAILED')))
        .write(const SyncQueueTableCompanion(
          status: Value('PENDING'),
          retryCount: Value(0),
          lastError: Value(null),
        ));
  }

  /// Depuración y limpieza de datos de prueba locales en SQLite (Transacción Atómica DEV)
  Future<void> purgeTestData() async {
    final todayStr = TimezoneUtils.getTodayBusinessDate();

    await _db.transaction(() async {
      // a) Menú Diario: Identificar duplicados de hoy y conservar únicamente el más reciente
      final todayMenus = await (_db.select(_db.dailyMenusTable)
            ..where((t) => t.menuDate.equals(todayStr))
            ..orderBy([(t) => OrderingTerm(expression: t.createdAt, mode: OrderingMode.desc)]))
          .get();

      if (todayMenus.length > 1) {
        final duplicateMenuIds = todayMenus.skip(1).map((m) => m.id).toList();

        await (_db.delete(_db.dailyMenuDishesTable)
              ..where((t) => t.dailyMenuId.isIn(duplicateMenuIds)))
            .go();

        await (_db.delete(_db.dailyMenusTable)
              ..where((t) => t.id.isIn(duplicateMenuIds)))
            .go();
      }

      // b) Pedidos: Eliminar pedidos de prueba generados durante tests
      final testOrders = await (_db.select(_db.ordersTable)
            ..where((t) => t.createdBy.equals('perf-user') | t.customerName.like('Cliente%')))
          .get();

      if (testOrders.isNotEmpty) {
        final testOrderIds = testOrders.map((o) => o.id).toList();
        await (_db.delete(_db.orderItemsTable)
              ..where((t) => t.orderId.isIn(testOrderIds)))
            .go();
        await (_db.delete(_db.ordersTable)
              ..where((t) => t.id.isIn(testOrderIds)))
            .go();
      }

      // c) Cola de Sincronización: Limpiar operaciones huérfanas de prueba o FAILED
      await (_db.delete(_db.syncQueueTable)
            ..where((t) => t.status.equals('FAILED') | t.entityId.like('%perf%') | t.entityId.like('%test%') | t.entityId.like('menu-dup%')))
          .go();
    });
  }
}
