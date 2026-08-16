import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

import 'package:katering_grecia_app/core/database/app_database.dart';
import 'package:katering_grecia_app/core/sync/sync_engine.dart';
import 'package:katering_grecia_app/core/sync/sync_queue_manager.dart';
import 'package:katering_grecia_app/features/dishes/data/dishes_repository.dart';
import 'package:katering_grecia_app/features/expenses/data/expenses_repository.dart';
import 'package:katering_grecia_app/features/financial_metrics/data/financial_metrics_repository.dart';
import 'package:katering_grecia_app/features/financial_metrics/domain/financial_metrics_model.dart';
import 'package:katering_grecia_app/features/orders/data/orders_repository.dart';

class MockSyncEngine extends Mock implements SyncEngine {}

void main() {
  late AppDatabase db;
  late SyncQueueManager queueManager;
  late MockSyncEngine mockSyncEngine;
  late DishesRepository dishesRepo;
  late OrdersRepository ordersRepo;
  late ExpensesRepository expensesRepo;
  late FinancialMetricsRepository metricsRepo;

  setUp(() async {
    db = AppDatabase(NativeDatabase.memory());
    queueManager = SyncQueueManager(db);
    mockSyncEngine = MockSyncEngine();

    dishesRepo = DishesRepository(db: db, queueManager: queueManager, syncEngine: mockSyncEngine);
    ordersRepo = OrdersRepository(db: db, queueManager: queueManager, syncEngine: mockSyncEngine);
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
            name: 'Servicios',
            createdAt: DateTime.now().toUtc(),
            updatedAt: DateTime.now().toUtc(),
          ),
        );
  });

  tearDown(() async {
    await db.close();
  });

  group('FinancialMetricsRepository Aggregation & Payment Breakdown Tests', () {
    test('Calculates sales, expenses, payment breakdowns and netResult correctly in SQLite', () async {
      final dish = await dishesRepo.createDish(name: 'Plato Especial', price: 50.0);

      // Pedido 1: Bs 100.0 (CASH)
      await ordersRepo.createOrder(
        customerName: 'Cliente 1',
        paymentMethod: 'CASH',
        itemsInput: [(dishId: dish.id, quantity: 2)],
      );

      // Pedido 2: Bs 50.0 (QR)
      await ordersRepo.createOrder(
        customerName: 'Cliente 2',
        paymentMethod: 'QR',
        itemsInput: [(dishId: dish.id, quantity: 1)],
      );

      // Gasto 1: Bs 40.0 (CASH)
      await expensesRepo.createExpense(
        description: 'Gas Garrafa',
        amount: 40.0,
        categoryId: 'cat-1',
        paymentMethod: 'CASH',
      );

      // Gasto 2: Bs 60.0 (QR)
      await expensesRepo.createExpense(
        description: 'Insumos Mercado QR',
        amount: 60.0,
        categoryId: 'cat-1',
        paymentMethod: 'QR',
      );

      // Gasto 3: Bs 25.0 (OTHER)
      await expensesRepo.createExpense(
        description: 'Flete Transporte',
        amount: 25.0,
        categoryId: 'cat-1',
        paymentMethod: 'OTHER',
      );

      final metrics = await metricsRepo.watchMetrics(period: FinancialPeriod.today).first;

      // Ventas
      expect(metrics.totalSales, equals(150.0));
      expect(metrics.cashSales, equals(100.0));
      expect(metrics.qrSales, equals(50.0));
      expect(metrics.otherSales, equals(0.0));
      expect(metrics.orderCount, equals(2));

      // Gastos
      expect(metrics.totalExpenses, equals(125.0)); // 40 + 60 + 25
      expect(metrics.cashExpenses, equals(40.0));
      expect(metrics.qrExpenses, equals(60.0));
      expect(metrics.otherExpenses, equals(25.0));
      expect(metrics.expenseCount, equals(3));

      // Resultado Neto
      expect(metrics.netResult, equals(25.0)); // 150 - 125
    });
  });
}
