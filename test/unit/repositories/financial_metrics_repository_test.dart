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

  group('FinancialMetricsRepository Aggregation Tests', () {
    test('Calculates sales, expenses and netResult correctly in SQLite', () async {
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

      // Gasto 1: Bs 40.0
      await expensesRepo.createExpense(
        description: 'Gas Garrafa',
        amount: 40.0,
        categoryId: 'cat-1',
        paymentMethod: 'CASH',
      );

      final metrics = await metricsRepo.watchMetrics(period: FinancialPeriod.today).first;

      expect(metrics.totalSales, equals(150.0));
      expect(metrics.cashSales, equals(100.0));
      expect(metrics.qrSales, equals(50.0));
      expect(metrics.totalExpenses, equals(40.0));
      expect(metrics.netResult, equals(110.0)); // 150 - 40
      expect(metrics.orderCount, equals(2));
      expect(metrics.expenseCount, equals(1));
    });
  });
}
