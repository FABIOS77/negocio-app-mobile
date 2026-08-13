import 'package:drift/drift.dart';
import '../../../core/database/app_database.dart';
import '../../../core/utils/timezone_utils.dart';
import '../domain/financial_metrics_model.dart';

class FinancialMetricsRepository {
  final AppDatabase _db;

  FinancialMetricsRepository({required AppDatabase db}) : _db = db;

  /// Observa reactivamente las métricas financieras agregadas en SQLite para un período determinado (America/La_Paz)
  Stream<FinancialMetricsModel> watchMetrics({
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

    return _db.customSelect(
      '''
      SELECT 
        (SELECT COALESCE(SUM(total), 0.0) FROM orders_table WHERE ordered_at >= ? AND ordered_at < ? AND status != 'CANCELLED') as total_sales,
        (SELECT COUNT(*) FROM orders_table WHERE ordered_at >= ? AND ordered_at < ? AND status != 'CANCELLED') as order_count,
        (SELECT COALESCE(SUM(total), 0.0) FROM orders_table WHERE ordered_at >= ? AND ordered_at < ? AND status != 'CANCELLED' AND payment_method = 'CASH') as cash_sales,
        (SELECT COALESCE(SUM(total), 0.0) FROM orders_table WHERE ordered_at >= ? AND ordered_at < ? AND status != 'CANCELLED' AND payment_method = 'QR') as qr_sales,
        (SELECT COALESCE(SUM(total), 0.0) FROM orders_table WHERE ordered_at >= ? AND ordered_at < ? AND status != 'CANCELLED' AND payment_method = 'OTHER') as other_sales,
        (SELECT COALESCE(SUM(amount), 0.0) FROM expenses_table WHERE expense_date >= ? AND expense_date <= ? AND deleted_at IS NULL) as total_expenses,
        (SELECT COUNT(*) FROM expenses_table WHERE expense_date >= ? AND expense_date <= ? AND deleted_at IS NULL) as expense_count
      ''',
      variables: [
        Variable.withDateTime(startDate),
        Variable.withDateTime(endDate),
        Variable.withDateTime(startDate),
        Variable.withDateTime(endDate),
        Variable.withDateTime(startDate),
        Variable.withDateTime(endDate),
        Variable.withDateTime(startDate),
        Variable.withDateTime(endDate),
        Variable.withDateTime(startDate),
        Variable.withDateTime(endDate),
        Variable.withString(startDateStr),
        Variable.withString(endDateStr),
        Variable.withString(startDateStr),
        Variable.withString(endDateStr),
      ],
      readsFrom: {_db.ordersTable, _db.expensesTable},
    ).watchSingle().map((row) {
      final totalSales = row.read<double>('total_sales');
      final totalExpenses = row.read<double>('total_expenses');
      final netResult = totalSales - totalExpenses;

      return FinancialMetricsModel(
        period: period,
        totalSales: totalSales,
        totalExpenses: totalExpenses,
        netResult: netResult,
        cashSales: row.read<double>('cash_sales'),
        qrSales: row.read<double>('qr_sales'),
        otherSales: row.read<double>('other_sales'),
        orderCount: row.read<int>('order_count'),
        expenseCount: row.read<int>('expense_count'),
      );
    });
  }
}
