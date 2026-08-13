import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

import 'package:katering_grecia_app/core/database/app_database.dart';
import 'package:katering_grecia_app/core/sync/sync_engine.dart';
import 'package:katering_grecia_app/core/sync/sync_queue_manager.dart';
import 'package:katering_grecia_app/features/dashboard/data/dashboard_repository.dart';
import 'package:katering_grecia_app/features/dishes/data/dishes_repository.dart';
import 'package:katering_grecia_app/features/expenses/data/expenses_repository.dart';
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
  late DashboardRepository dashboardRepo;

  setUp(() async {
    db = AppDatabase(NativeDatabase.memory());
    queueManager = SyncQueueManager(db);
    mockSyncEngine = MockSyncEngine();

    dishesRepo = DishesRepository(db: db, queueManager: queueManager, syncEngine: mockSyncEngine);
    ordersRepo = OrdersRepository(db: db, queueManager: queueManager, syncEngine: mockSyncEngine);
    expensesRepo = ExpensesRepository(db: db, queueManager: queueManager, syncEngine: mockSyncEngine);
    dashboardRepo = DashboardRepository(db: db);

    when(() => mockSyncEngine.syncAll()).thenAnswer((_) async => SyncResult(
          pushedCount: 0,
          pulledCount: 0,
          conflictCount: 0,
          errorCount: 0,
        ));

    await db.into(db.expenseCategoriesTable).insert(
          ExpenseCategoriesTableCompanion.insert(
            id: 'cat-1',
            name: 'Insumos',
            createdAt: DateTime.now().toUtc(),
            updatedAt: DateTime.now().toUtc(),
          ),
        );
  });

  tearDown(() async {
    await db.close();
  });

  group('DashboardRepository Unit Tests', () {
    test('Calculates aggregated sales, expenses, net result and Top 5 dishes in SQLite', () async {
      final dish1 = await dishesRepo.createDish(name: 'Majadito de Pato', price: 25.0);
      final dish2 = await dishesRepo.createDish(name: 'Sopa de Maní', price: 15.0);

      // Pedido 1: 3 Majaditos (Bs 75.0 CASH)
      await ordersRepo.createOrder(
        customerName: 'Mesa 1',
        paymentMethod: 'CASH',
        itemsInput: [(dishId: dish1.id, quantity: 3)],
      );

      // Pedido 2: 1 Majadito, 2 Sopas (Bs 55.0 QR)
      await ordersRepo.createOrder(
        customerName: 'Mesa 2',
        paymentMethod: 'QR',
        itemsInput: [
          (dishId: dish1.id, quantity: 1),
          (dishId: dish2.id, quantity: 2),
        ],
      );

      // Gasto: Bs 30.0
      await expensesRepo.createExpense(
        description: 'Plátanos y arroz',
        amount: 30.0,
        categoryId: 'cat-1',
        paymentMethod: 'CASH',
      );

      final metrics = await dashboardRepo.watchDashboardMetrics(period: FinancialPeriod.today).first;

      expect(metrics.totalOrders, equals(2));
      expect(metrics.totalSales, equals(130.0)); // 75 + 55
      expect(metrics.totalExpenses, equals(30.0));
      expect(metrics.netResult, equals(100.0)); // 130 - 30
      expect(metrics.cashSales, equals(75.0));
      expect(metrics.qrSales, equals(55.0));

      // Verificar Top Platos
      expect(metrics.topDishes.length, equals(2));
      // Majadito de Pato debe ser #1 con 4 porciones (3 + 1)
      expect(metrics.topDishes.first.dishName, equals('Majadito de Pato'));
      expect(metrics.topDishes.first.totalQuantity, equals(4));
      expect(metrics.topDishes.first.totalRevenue, equals(100.0));

      // Sopa de Maní debe ser #2 con 2 porciones
      expect(metrics.topDishes.last.dishName, equals('Sopa de Maní'));
      expect(metrics.topDishes.last.totalQuantity, equals(2));
    });
  });
}
