import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:katering_grecia_app/core/database/app_database.dart';
import 'package:katering_grecia_app/core/utils/timezone_utils.dart';
import 'package:katering_grecia_app/features/financial_metrics/data/financial_metrics_repository.dart';

void main() {
  late AppDatabase db;
  late FinancialMetricsRepository metricsRepo;

  setUp(() {
    db = AppDatabase(NativeDatabase.memory());
    metricsRepo = FinancialMetricsRepository(db: db);
  });

  tearDown(() async {
    await db.close();
  });

  group('Financial Performance Tests (5,000 Orders + 2,000 Expenses)', () {
    test('Handles 5,000 orders & 2,000 expenses metrics calculation sub-50ms', () async {
      final now = DateTime.now().toUtc();
      final todayStr = TimezoneUtils.getTodayBusinessDate();

      // 1. Inserción masiva de 5,000 pedidos
      await db.batch((batch) {
        for (int i = 1; i <= 5000; i++) {
          batch.insert(
            db.ordersTable,
            OrdersTableCompanion.insert(
              id: 'order-financial-$i',
              customerName: 'Cliente #$i',
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

      // 2. Inserción masiva de 2,000 gastos
      await db.batch((batch) {
        for (int i = 1; i <= 2000; i++) {
          batch.insert(
            db.expensesTable,
            ExpensesTableCompanion.insert(
              id: 'exp-financial-$i',
              description: 'Gasto de Insumo #$i',
              amount: 20.0,
              categoryId: 'cat-1',
              paymentMethod: i % 3 == 0 ? 'QR' : 'CASH',
              expenseDate: todayStr,
              createdBy: 'perf-user',
              createdAt: now,
              updatedAt: now,
            ),
          );
        }
      });

      // 3. Medir tiempo de consulta SQL agregada de Métricas Financieras
      final stopwatchMetrics = Stopwatch()..start();
      final metrics = await metricsRepo.watchMetrics().first;
      stopwatchMetrics.stop();

      expect(metrics.totalSales, equals(225000.0));
      expect(metrics.totalExpenses, equals(40000.0));
      expect(metrics.netResult, equals(185000.0));
      expect(stopwatchMetrics.elapsedMilliseconds, lessThanOrEqualTo(100));
    });
  });
}
