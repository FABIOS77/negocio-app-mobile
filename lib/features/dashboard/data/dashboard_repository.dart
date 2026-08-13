import 'package:drift/drift.dart';
import '../../../core/database/app_database.dart';
import '../../../core/utils/timezone_utils.dart';
import '../../financial_metrics/domain/financial_metrics_model.dart';
import '../domain/dashboard_metrics_model.dart';
import '../domain/top_dish_model.dart';

class DashboardRepository {
  final AppDatabase _db;

  DashboardRepository({required AppDatabase db}) : _db = db;

  /// Observa reactivamente todas las métricas del Dashboard mediante consultas SQL súper optimizadas
  Stream<DashboardMetricsModel> watchDashboardMetrics({
    FinancialPeriod period = FinancialPeriod.today,
    DateTime? customStart,
    DateTime? customEnd,
  }) {
    final todayStr = TimezoneUtils.getTodayBusinessDate();
    final todayUtcStart = DateTime.parse('${todayStr}T00:00:00.000Z').add(const Duration(hours: 4));

    DateTime startDate;
    DateTime endDate;
    String startDateStr;
    String endDateStr;

    switch (period) {
      case FinancialPeriod.today:
        startDate = todayUtcStart;
        endDate = todayUtcStart.add(const Duration(days: 1));
        startDateStr = todayStr;
        endDateStr = todayStr;
        break;
      case FinancialPeriod.week:
        startDate = todayUtcStart.subtract(Duration(days: todayUtcStart.weekday - 1));
        endDate = startDate.add(const Duration(days: 7));
        startDateStr = TimezoneUtils.toBusinessDateString(startDate);
        endDateStr = todayStr;
        break;
      case FinancialPeriod.month:
        startDate = DateTime.utc(todayUtcStart.year, todayUtcStart.month, 1).add(const Duration(hours: 4));
        endDate = DateTime.utc(todayUtcStart.year, todayUtcStart.month + 1, 1).add(const Duration(hours: 4));
        startDateStr = TimezoneUtils.toBusinessDateString(startDate);
        endDateStr = todayStr;
        break;
      case FinancialPeriod.custom:
        startDate = customStart ?? todayUtcStart;
        endDate = customEnd ?? todayUtcStart.add(const Duration(days: 1));
        startDateStr = TimezoneUtils.toBusinessDateString(startDate);
        endDateStr = TimezoneUtils.toBusinessDateString(endDate);
        break;
    }

    final mainStream = _db.customSelect(
      '''
      SELECT 
        COALESCE(SUM(total), 0.0) as total_sales,
        COUNT(*) as total_orders,
        COALESCE(SUM(CASE WHEN payment_method = 'CASH' THEN total ELSE 0.0 END), 0.0) as cash_sales,
        COALESCE(SUM(CASE WHEN payment_method = 'QR' THEN total ELSE 0.0 END), 0.0) as qr_sales,
        COALESCE(SUM(CASE WHEN payment_method = 'OTHER' THEN total ELSE 0.0 END), 0.0) as other_sales
      FROM orders_table
      WHERE ordered_at >= ? AND ordered_at < ? AND status != 'CANCELLED'
      ''',
      variables: [
        Variable.withDateTime(startDate),
        Variable.withDateTime(endDate),
      ],
      readsFrom: {_db.ordersTable, _db.expensesTable, _db.syncQueueTable, _db.orderItemsTable},
    ).watchSingle();

    return mainStream.asyncMap((orderRow) async {
      final futures = await Future.wait([
        _db.customSelect(
          '''
          SELECT COALESCE(SUM(amount), 0.0) as total_expenses
          FROM expenses_table
          WHERE expense_date >= ? AND expense_date <= ? AND deleted_at IS NULL
          ''',
          variables: [
            Variable.withString(startDateStr),
            Variable.withString(endDateStr),
          ],
        ).getSingle(),
        _db.customSelect(
          '''
          SELECT COUNT(*) as pending_sync_count FROM sync_queue_table WHERE status = 'PENDING'
          ''',
        ).getSingle(),
        _db.customSelect(
          '''
          SELECT oi.dish_id, oi.dish_name_snapshot, SUM(oi.quantity) as total_qty, SUM(oi.subtotal) as total_revenue
          FROM order_items_table oi
          INNER JOIN orders_table o ON o.id = oi.order_id
          WHERE o.ordered_at >= ? AND o.ordered_at < ? AND o.status != 'CANCELLED'
          GROUP BY oi.dish_id, oi.dish_name_snapshot
          ORDER BY total_qty DESC
          LIMIT 5
          ''',
          variables: [
            Variable.withDateTime(startDate),
            Variable.withDateTime(endDate),
          ],
        ).get(),
      ]);

      final expenseRow = futures[0] as QueryRow;
      final syncRow = futures[1] as QueryRow;
      final topDishesRows = futures[2] as List<QueryRow>;

      final topDishes = topDishesRows.map((r) {
        return TopDishModel(
          dishId: r.read<String>('dish_id'),
          dishName: r.read<String>('dish_name_snapshot'),
          totalQuantity: r.read<int>('total_qty'),
          totalRevenue: r.read<double>('total_revenue'),
        );
      }).toList();

      final totalSales = orderRow.read<double>('total_sales');
      final totalExpenses = expenseRow.read<double>('total_expenses');
      final netResult = totalSales - totalExpenses;

      return DashboardMetricsModel(
        period: period,
        totalOrders: orderRow.read<int>('total_orders'),
        totalSales: totalSales,
        totalExpenses: totalExpenses,
        netResult: netResult,
        cashSales: orderRow.read<double>('cash_sales'),
        qrSales: orderRow.read<double>('qr_sales'),
        otherSales: orderRow.read<double>('other_sales'),
        topDishes: topDishes,
        pendingSyncCount: syncRow.read<int>('pending_sync_count'),
      );
    });
  }
}
