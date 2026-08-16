import 'dart:convert';
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

    await db.into(db.expenseCategoriesTable).insert(
          ExpenseCategoriesTableCompanion.insert(
            id: 'cat-mercado',
            name: 'Compras de Mercado',
            createdAt: DateTime.now().toUtc(),
            updatedAt: DateTime.now().toUtc(),
          ),
        );
  });

  tearDown(() async {
    await db.close();
  });

  group('Expense Breakdown Logic & Persistence Tests', () {
    test('1. Suma básica de desglose [30.0, 50.0, 40.0, 25.0] = 145.0', () {
      final items = [30.0, 50.0, 40.0, 25.0];
      final sum = items.fold(0.0, (acc, val) => acc + val);
      expect(sum, equals(145.0));
    });

    test('2. Editar importe en lista recalcula total inmediatamente', () {
      final items = [30.0, 50.0, 40.0];
      expect(items.fold(0.0, (acc, val) => acc + val), equals(120.0));

      items[2] = 100.0; // Editar 40 -> 100
      expect(items.fold(0.0, (acc, val) => acc + val), equals(180.0));
    });

    test('3. Eliminar importe en lista recalcula total inmediatamente', () {
      final items = [30.0, 50.0, 40.0];
      items.removeAt(1); // Eliminar 50.0
      expect(items.fold(0.0, (acc, val) => acc + val), equals(70.0));
    });

    test('4. Maneja lista de 20 importes con precisión decimal', () {
      final items = List.generate(20, (i) => (i + 1) * 2.5); // [2.5, 5.0, 7.5, ... 50.0]
      final sum = items.fold(0.0, (acc, val) => acc + val);
      expect(sum, equals(525.0));
    });

    test('5. Persistencia y Sync: Crear gasto con suma de desglose guarda UN SOLO Expense.amount en SQLite y SyncQueue', () async {
      // Simular desglose de importes: [10.0, 20.0, 30.0] -> Total: 60.0
      final breakdownItems = [10.0, 20.0, 30.0];
      final totalAmount = breakdownItems.fold(0.0, (acc, val) => acc + val);

      final createdExpense = await repository.createExpense(
        description: 'Compras Supermercado',
        amount: totalAmount,
        categoryId: 'cat-mercado',
        paymentMethod: 'CASH',
        expenseDate: '2026-08-16',
      );

      expect(createdExpense.amount, equals(60.0));

      // Verificar en SQLite
      final dbExpenses = await db.select(db.expensesTable).get();
      expect(dbExpenses.length, equals(1));
      expect(dbExpenses.first.amount, equals(60.0));

      // Verificar en SyncQueue: se encoló exactamente UNA operación con payload { amount: 60.0 }
      final pendingOps = await queueManager.getPendingOperations();
      expect(pendingOps.length, equals(1));
      expect(pendingOps.first.entityType, equals('expense'));

      final payloadMap = jsonDecode(pendingOps.first.payload) as Map<String, dynamic>;
      expect(payloadMap['amount'], equals(60.0));
      expect(payloadMap.containsKey('items'), isFalse);
      expect(payloadMap.containsKey('breakdown'), isFalse);
    });
  });
}
