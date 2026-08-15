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

    // Precargar 2 categorías
    await db.into(db.expenseCategoriesTable).insert(
          ExpenseCategoriesTableCompanion.insert(
            id: 'cat-1',
            name: 'Insumos',
            createdAt: DateTime.now().toUtc(),
            updatedAt: DateTime.now().toUtc(),
          ),
        );
    await db.into(db.expenseCategoriesTable).insert(
          ExpenseCategoriesTableCompanion.insert(
            id: 'cat-2',
            name: 'Servicios',
            createdAt: DateTime.now().toUtc(),
            updatedAt: DateTime.now().toUtc(),
          ),
        );

    // Precargar gastos con diferentes fechas, categorías y métodos de pago
    await repository.createExpense(
      description: 'Carne de res',
      amount: 100.0,
      categoryId: 'cat-1',
      paymentMethod: 'CASH',
      expenseDate: '2026-08-10',
    );
    await repository.createExpense(
      description: 'Pago de Luz',
      amount: 200.0,
      categoryId: 'cat-2',
      paymentMethod: 'QR',
      expenseDate: '2026-08-12',
    );
    await repository.createExpense(
      description: 'Verduras',
      amount: 50.0,
      categoryId: 'cat-1',
      paymentMethod: 'QR',
      expenseDate: '2026-08-14',
    );
    await repository.createExpense(
      description: 'Gas Garrafa',
      amount: 45.0,
      categoryId: 'cat-2',
      paymentMethod: 'OTHER',
      expenseDate: '2026-08-14',
    );
  });

  tearDown(() async {
    await db.close();
  });

  group('Expenses Drift Filter Tests', () {
    test('Filter by exact date', () async {
      final list = await repository.watchExpenses(date: '2026-08-14').first;
      expect(list.length, equals(2));
      expect(list.map((e) => e.description), containsAll(['Verduras', 'Gas Garrafa']));
    });

    test('Filter by date range (dateFrom and dateTo)', () async {
      final list = await repository.watchExpenses(dateFrom: '2026-08-11', dateTo: '2026-08-13').first;
      expect(list.length, equals(1));
      expect(list.first.description, equals('Pago de Luz'));
    });

    test('Filter by categoryId', () async {
      final list = await repository.watchExpenses(categoryId: 'cat-1').first;
      expect(list.length, equals(2));
      expect(list.every((e) => e.categoryId == 'cat-1'), isTrue);
    });

    test('Filter by paymentMethod', () async {
      final qrExpenses = await repository.watchExpenses(paymentMethod: 'QR').first;
      expect(qrExpenses.length, equals(2));
      expect(qrExpenses.map((e) => e.description), containsAll(['Pago de Luz', 'Verduras']));

      final otherExpenses = await repository.watchExpenses(paymentMethod: 'OTHER').first;
      expect(otherExpenses.length, equals(1));
      expect(otherExpenses.first.description, equals('Gas Garrafa'));
    });

    test('Combined filter (date + category + paymentMethod)', () async {
      final list = await repository.watchExpenses(
        date: '2026-08-14',
        categoryId: 'cat-1',
        paymentMethod: 'QR',
      ).first;

      expect(list.length, equals(1));
      expect(list.first.description, equals('Verduras'));
    });
  });
}
