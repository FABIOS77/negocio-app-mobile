import 'dart:io';
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:path/path.dart' as p;

import 'package:katering_grecia_app/core/database/app_database.dart';
import 'package:katering_grecia_app/core/sync/sync_engine.dart';
import 'package:katering_grecia_app/core/sync/sync_queue_manager.dart';
import 'package:katering_grecia_app/features/expenses/data/expenses_repository.dart';
import 'package:katering_grecia_app/features/financial_metrics/data/financial_metrics_repository.dart';

class MockSyncEngine extends Mock implements SyncEngine {}

void main() {
  late File dbFile;
  late MockSyncEngine mockSyncEngine;

  setUp(() {
    final tempDir = Directory.systemTemp.createTempSync('katering_exp_test_');
    dbFile = File(p.join(tempDir.path, 'test_exp_db.sqlite'));
    mockSyncEngine = MockSyncEngine();

    when(() => mockSyncEngine.syncAll()).thenAnswer((_) async => SyncResult(
          pushedCount: 0,
          pulledCount: 0,
          conflictCount: 0,
          errorCount: 0,
        ));
  });

  tearDown(() {
    if (dbFile.existsSync()) {
      dbFile.deleteSync();
    }
  });

  group('App Restart Expenses Persistence Test', () {
    test('Offline created expense persists across DB restarts and updates metrics', () async {
      // 1. Instancia 1 de DB
      var db1 = AppDatabase(NativeDatabase(dbFile));
      var queueManager1 = SyncQueueManager(db1);
      var expRepo1 = ExpensesRepository(db: db1, queueManager: queueManager1, syncEngine: mockSyncEngine);

      await db1.into(db1.expenseCategoriesTable).insert(
            ExpenseCategoriesTableCompanion.insert(
              id: 'cat-test',
              name: 'Insumos Test',
              createdAt: DateTime.now().toUtc(),
              updatedAt: DateTime.now().toUtc(),
            ),
          );

      final exp = await expRepo1.createExpense(
        description: 'Gasto Persistente',
        amount: 250.0,
        categoryId: 'cat-test',
        paymentMethod: 'CASH',
      );

      expect(exp.amount, equals(250.0));

      // 2. Simular Cierre de App
      await db1.close();

      // 3. Simular Reinicio de App
      var db2 = AppDatabase(NativeDatabase(dbFile));
      var queueManager2 = SyncQueueManager(db2);
      var expRepo2 = ExpensesRepository(db: db2, queueManager: queueManager2, syncEngine: mockSyncEngine);
      var metricsRepo2 = FinancialMetricsRepository(db: db2);

      final restored = await expRepo2.getExpenseById(exp.id);
      expect(restored, isNotNull);
      expect(restored!.description, equals('Gasto Persistente'));
      expect(restored.amount, equals(250.0));

      final pendingOps = await queueManager2.getPendingOperations();
      expect(pendingOps.isNotEmpty, isTrue);

      final metrics = await metricsRepo2.watchMetrics().first;
      expect(metrics.totalExpenses, equals(250.0));

      await db2.close();
    });
  });
}
