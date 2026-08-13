import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

import 'package:katering_grecia_app/core/database/app_database.dart';
import 'package:katering_grecia_app/core/sync/sync_engine.dart';
import 'package:katering_grecia_app/core/sync/sync_queue_manager.dart';
import 'package:katering_grecia_app/features/expenses/data/expenses_repository.dart';

class MockSyncEngine extends Mock implements SyncEngine {}

void main() {
  late AppDatabase db;
  late SyncQueueManager queueManager;
  late MockSyncEngine mockSyncEngine;
  late ExpensesRepository repository;

  setUp(() async {
    db = AppDatabase(NativeDatabase.memory());
    queueManager = SyncQueueManager(db);
    mockSyncEngine = MockSyncEngine();

    repository = ExpensesRepository(
      db: db,
      queueManager: queueManager,
      syncEngine: mockSyncEngine,
    );

    when(() => mockSyncEngine.syncAll()).thenAnswer((_) async => SyncResult(
          pushedCount: 0,
          pulledCount: 0,
          conflictCount: 0,
          errorCount: 0,
        ));

    // Precargar categoría de prueba
    await db.into(db.expenseCategoriesTable).insert(
          ExpenseCategoriesTableCompanion.insert(
            id: 'cat-insumos-1',
            name: 'Insumos',
            createdAt: DateTime.now().toUtc(),
            updatedAt: DateTime.now().toUtc(),
          ),
        );
  });

  tearDown(() async {
    await db.close();
  });

  group('ExpensesRepository Unit Tests', () {
    test('Create, Read, Filter and Soft Delete Expense offline', () async {
      // 1. Crear Gasto
      final exp = await repository.createExpense(
        description: 'Verduras del Mercado',
        amount: 150.0,
        categoryId: 'cat-insumos-1',
        paymentMethod: 'CASH',
      );

      expect(exp.description, equals('Verduras del Mercado'));
      expect(exp.amount, equals(150.0));

      // 2. Filtrar por categoría
      final list = await repository.watchExpenses(categoryId: 'cat-insumos-1').first;
      expect(list.length, equals(1));
      expect(list.first.categoryName, equals('Insumos'));

      // 3. Soft Delete (deletedAt != null)
      await repository.deleteExpense(exp.id);

      final activeList = await repository.watchExpenses().first;
      expect(activeList.isEmpty, isTrue);
    });
  });
}
