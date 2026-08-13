import 'package:drift/drift.dart';
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:katering_grecia_app/core/database/app_database.dart';
import 'package:katering_grecia_app/features/sync/data/sync_diagnostics_repository.dart';

void main() {
  late AppDatabase db;
  late SyncDiagnosticsRepository repo;

  setUp(() {
    db = AppDatabase(NativeDatabase.memory());
    repo = SyncDiagnosticsRepository(db: db);
  });

  tearDown(() async {
    await db.close();
  });

  group('SyncDiagnosticsRepository Unit Tests', () {
    test('Reads pending sync queue operations and lastCursor from SQLite', () async {
      final now = DateTime.now().toUtc();

      // 1. Insertar metadatos de cursor
      await db.into(db.syncMetadataTable).insert(
            SyncMetadataTableCompanion.insert(
              key: 'last_cursor',
              value: '12345',
              updatedAt: now,
            ),
          );

      // 2. Insertar elementos en la cola
      await db.into(db.syncQueueTable).insert(
            SyncQueueTableCompanion.insert(
              operationId: 'op-1',
              entityType: 'orders',
              entityId: 'ord-1',
              operation: 'CREATE',
              payload: '{}',
              clientTimestamp: now,
              status: const Value('PENDING'),
              createdAt: now,
            ),
          );

      await db.into(db.syncQueueTable).insert(
            SyncQueueTableCompanion.insert(
              operationId: 'op-2',
              entityType: 'expenses',
              entityId: 'exp-1',
              operation: 'UPDATE',
              payload: '{}',
              clientTimestamp: now,
              status: const Value('PENDING'),
              createdAt: now,
            ),
          );

      await db.into(db.syncQueueTable).insert(
            SyncQueueTableCompanion.insert(
              operationId: 'op-3',
              entityType: 'expenses',
              entityId: 'exp-2',
              operation: 'DELETE',
              payload: '{}',
              clientTimestamp: now,
              status: const Value('CONFLICT'),
              lastError: const Value('VERSION_CONFLICT'),
              createdAt: now,
            ),
          );

      final summary = await repo.watchDiagnosticsSummary().first;

      expect(summary.pendingCreateCount, equals(1));
      expect(summary.pendingUpdateCount, equals(1));
      expect(summary.pendingDeleteCount, equals(0));
      expect(summary.totalPendingCount, equals(2));
      expect(summary.lastCursor, equals('12345'));
      expect(summary.conflicts.length, equals(1));
      expect(summary.conflicts.first.lastError, equals('VERSION_CONFLICT'));
    });
  });
}
