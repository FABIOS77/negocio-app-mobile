import 'dart:async';
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

import 'package:katering_grecia_app/core/database/app_database.dart';
import 'package:katering_grecia_app/core/sync/sync_engine.dart';
import 'package:katering_grecia_app/core/sync/sync_queue_manager.dart';
import 'package:katering_grecia_app/features/expenses/data/expenses_repository.dart';
import 'package:katering_grecia_app/features/financial_metrics/data/financial_metrics_repository.dart';
import 'package:katering_grecia_app/features/financial_metrics/domain/financial_metrics_model.dart';

class MockSyncEngine extends Mock implements SyncEngine {}

void main() {
  late AppDatabase db;
  late SyncQueueManager queueManager;
  late MockSyncEngine mockSyncEngine;
  late ExpensesRepository expensesRepo;
  late FinancialMetricsRepository metricsRepo;

  setUp(() async {
    db = AppDatabase(NativeDatabase.memory());
    queueManager = SyncQueueManager(db);
    mockSyncEngine = MockSyncEngine();

    expensesRepo = ExpensesRepository(db: db, queueManager: queueManager, syncEngine: mockSyncEngine);
    metricsRepo = FinancialMetricsRepository(db: db);

    when(() => mockSyncEngine.syncAll()).thenAnswer((_) async => SyncResult(
          pushedCount: 0,
          pulledCount: 0,
          conflictCount: 0,
          errorCount: 0,
        ));

    await db.into(db.expenseCategoriesTable).insert(
          ExpenseCategoriesTableCompanion.insert(
            id: 'cat-1',
            name: 'Servicios Generales',
            createdAt: DateTime.now().toUtc(),
            updatedAt: DateTime.now().toUtc(),
          ),
        );
  });

  tearDown(() async {
    await db.close();
  });

  group('Financial Metrics Reactivity Regression Tests (Expense Mutations)', () {
    test('Sequential: Initial(0) -> Create(100) -> Update(150) -> Delete(0) -> Create(50)', () async {
      final emissions = <FinancialMetricsModel>[];
      final completers = <Completer<FinancialMetricsModel>>[
        Completer<FinancialMetricsModel>(),
      ];

      final sub = metricsRepo.watchMetrics(period: FinancialPeriod.today).listen((m) {
        emissions.add(m);
        if (!completers.last.isCompleted) {
          completers.last.complete(m);
        }
      });

      // 1. Estado inicial: gastos = 0
      var current = await completers.last.future;
      expect(current.totalExpenses, equals(0.0));
      expect(current.expenseCount, equals(0));

      // 2. Crear gasto: Bs 100.0
      completers.add(Completer<FinancialMetricsModel>());
      final exp = await expensesRepo.createExpense(
        description: 'Compra Carne',
        amount: 100.0,
        categoryId: 'cat-1',
        paymentMethod: 'CASH',
      );

      current = await completers.last.future;
      expect(current.totalExpenses, equals(100.0));
      expect(current.expenseCount, equals(1));
      expect(current.cashExpenses, equals(100.0));

      // 3. Editar gasto: Bs 100.0 -> Bs 150.0 (QR)
      completers.add(Completer<FinancialMetricsModel>());
      await expensesRepo.updateExpense(
        id: exp.id,
        description: 'Compra Carne y Verdura',
        amount: 150.0,
        categoryId: 'cat-1',
        paymentMethod: 'QR',
      );

      current = await completers.last.future;
      expect(current.totalExpenses, equals(150.0));
      expect(current.expenseCount, equals(1));
      expect(current.cashExpenses, equals(0.0));
      expect(current.qrExpenses, equals(150.0));

      // 4. Eliminar / Soft-Delete gasto: gastos = 0
      completers.add(Completer<FinancialMetricsModel>());
      await expensesRepo.deleteExpense(exp.id);

      current = await completers.last.future;
      expect(current.totalExpenses, equals(0.0));
      expect(current.expenseCount, equals(0));
      expect(current.cashExpenses, equals(0.0));
      expect(current.qrExpenses, equals(0.0));

      // 5. Crear otro gasto: Bs 50.0
      completers.add(Completer<FinancialMetricsModel>());
      await expensesRepo.createExpense(
        description: 'Compra Pan',
        amount: 50.0,
        categoryId: 'cat-1',
        paymentMethod: 'CASH',
      );

      current = await completers.last.future;
      expect(current.totalExpenses, equals(50.0));
      expect(current.expenseCount, equals(1));
      expect(current.cashExpenses, equals(50.0));

      await sub.cancel();
    });

    test('Period isolation: mutating yesterday expense does not affect today metrics', () async {
      // Crear gasto con fecha de ayer
      final yesterdayExp = await expensesRepo.createExpense(
        description: 'Gasto Ayer',
        amount: 80.0,
        categoryId: 'cat-1',
        paymentMethod: 'CASH',
        expenseDate: '2020-01-01', // fecha pasada
      );

      // Métricas de hoy permanecen en 0
      final todayMetrics = await metricsRepo.watchMetrics(period: FinancialPeriod.today).first;
      expect(todayMetrics.totalExpenses, equals(0.0));

      // Métricas con período personalizado (2020-01-01) sí reflejan el gasto
      final customMetrics = await metricsRepo.watchMetrics(
        period: FinancialPeriod.custom,
        customStartStr: '2020-01-01',
        customEndStr: '2020-01-01',
      ).first;
      expect(customMetrics.totalExpenses, equals(80.0));

      // Eliminar el gasto de ayer
      await expensesRepo.deleteExpense(yesterdayExp.id);

      final customAfterDelete = await metricsRepo.watchMetrics(
        period: FinancialPeriod.custom,
        customStartStr: '2020-01-01',
        customEndStr: '2020-01-01',
      ).first;
      expect(customAfterDelete.totalExpenses, equals(0.0));
    });
  });
}
