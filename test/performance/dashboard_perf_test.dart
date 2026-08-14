import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:katering_grecia_app/core/database/app_database.dart';
import 'package:katering_grecia_app/core/utils/timezone_utils.dart';
import 'package:katering_grecia_app/features/dashboard/data/dashboard_repository.dart';

void main() {
  late AppDatabase db;
  late DashboardRepository dashboardRepo;

  setUp(() {
    db = AppDatabase(NativeDatabase.memory());
    dashboardRepo = DashboardRepository(db: db);
  });

  tearDown(() async {
    await db.close();
  });

  group('Dashboard Performance Tests (5,000 Orders + 10,000 OrderItems + 2,000 Expenses)', () {
    test('Handles Dashboard metrics and Top 5 dishes SQL aggregation sub-100ms', () async {
      final now = DateTime.now().toUtc();
      final todayStr = TimezoneUtils.getTodayBusinessDate();

      // 1. Inserción masiva de 5,000 pedidos
      await db.batch((batch) {
        for (int i = 1; i <= 5000; i++) {
          batch.insert(
            db.ordersTable,
            OrdersTableCompanion.insert(
              id: 'order-dash-perf-$i',
              customerName: 'Cliente Perf #$i',
              total: 50.0,
              paymentMethod: i % 2 == 0 ? 'CASH' : 'QR',
              status: i % 10 == 0 ? 'CANCELLED' : 'PENDING',
              orderedAt: now,
              createdBy: 'perf-user',
              createdAt: now,
              updatedAt: now,
            ),
          );
        }
      });

      // 2. Inserción masiva de 10,000 order items
      await db.batch((batch) {
        for (int i = 1; i <= 5000; i++) {
          batch.insert(
            db.orderItemsTable,
            OrderItemsTableCompanion.insert(
              id: 'item-dash-1-$i',
              orderId: 'order-dash-perf-$i',
              dishId: 'dish-1',
              dishNameSnapshot: 'Majadito',
              quantity: 2,
              unitPrice: 15.0,
              subtotal: 30.0,
            ),
          );
          batch.insert(
            db.orderItemsTable,
            OrderItemsTableCompanion.insert(
              id: 'item-dash-2-$i',
              orderId: 'order-dash-perf-$i',
              dishId: 'dish-2',
              dishNameSnapshot: 'Silpancho',
              quantity: 1,
              unitPrice: 20.0,
              subtotal: 20.0,
            ),
          );
        }
      });

      // 3. Inserción masiva de 2,000 gastos
      await db.batch((batch) {
        for (int i = 1; i <= 2000; i++) {
          batch.insert(
            db.expensesTable,
            ExpensesTableCompanion.insert(
              id: 'exp-dash-perf-$i',
              description: 'Insumo #$i',
              amount: 10.0,
              categoryId: 'cat-1',
              paymentMethod: 'CASH',
              expenseDate: todayStr,
              createdBy: 'perf-user',
              createdAt: now,
              updatedAt: now,
            ),
          );
        }
      });

      // 4. Medir tiempo de consulta SQL agregada del Dashboard
      final stopwatch = Stopwatch()..start();
      final metrics = await dashboardRepo.watchDashboardMetrics().first;
      stopwatch.stop();

      expect(metrics.totalOrders, equals(4500));
      expect(metrics.totalSales, equals(225000.0));
      expect(metrics.totalExpenses, equals(20000.0));
      expect(metrics.netResult, equals(205000.0));
      expect(metrics.topDishes.length, equals(2));
      expect(metrics.topDishes.first.dishName, equals('Majadito'));
      expect(metrics.topDishes.first.totalQuantity, equals(9000)); // 4500 * 2

      expect(stopwatch.elapsedMilliseconds, lessThan(100));
    });
  });
}
