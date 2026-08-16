import 'dart:async';
import 'package:drift/drift.dart';
import '../../../core/database/app_database.dart';
import '../../../core/utils/timezone_utils.dart';
import '../domain/financial_metrics_model.dart';

class FinancialMetricsRepository {
  final AppDatabase _db;

  FinancialMetricsRepository({required AppDatabase db}) : _db = db;

  /// Helper para combinar reactivamente dos Streams emitiendo tan pronto cualquiera cambie
  Stream<T3> _combineLatest2<T1, T2, T3>(
    Stream<T1> stream1,
    Stream<T2> stream2,
    T3 Function(T1 a, T2 b) combiner,
  ) {
    late StreamController<T3> controller;
    StreamSubscription<T1>? sub1;
    StreamSubscription<T2>? sub2;
    T1? val1;
    T2? val2;
    bool hasVal1 = false;
    bool hasVal2 = false;

    void emitIfReady() {
      if (hasVal1 && hasVal2 && !controller.isClosed) {
        controller.add(combiner(val1 as T1, val2 as T2));
      }
    }

    controller = StreamController<T3>.broadcast(
      onListen: () {
        sub1 ??= stream1.listen(
          (data) {
            val1 = data;
            hasVal1 = true;
            emitIfReady();
          },
          onError: (err) {
            if (!controller.isClosed) controller.addError(err);
          },
        );
        sub2 ??= stream2.listen(
          (data) {
            val2 = data;
            hasVal2 = true;
            emitIfReady();
          },
          onError: (err) {
            if (!controller.isClosed) controller.addError(err);
          },
        );
      },
      onCancel: () async {
        if (!controller.hasListener) {
          await sub1?.cancel();
          await sub2?.cancel();
          sub1 = null;
          sub2 = null;
        }
      },
    );

    return controller.stream;
  }

  /// Observa reactivamente las métricas financieras agregadas en SQLite
  Stream<FinancialMetricsModel> watchMetrics({
    FinancialPeriod period = FinancialPeriod.today,
    String? customStartStr,
    String? customEndStr,
  }) {
    final todayStr = TimezoneUtils.getTodayBusinessDate();
    final todayUtcStart = DateTime.parse('${todayStr}T00:00:00.000Z').add(const Duration(hours: 4));
    final nowLaPaz = TimezoneUtils.getNowLaPaz();

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

      case FinancialPeriod.yesterday:
        final yesterdayStr = TimezoneUtils.getYesterdayBusinessDate();
        startDate = todayUtcStart.subtract(const Duration(days: 1));
        endDate = todayUtcStart;
        startDateStr = yesterdayStr;
        endDateStr = yesterdayStr;
        break;

      case FinancialPeriod.week:
        final weekRange = TimezoneUtils.getThisWeekBusinessDateRange();
        startDate = todayUtcStart.subtract(Duration(days: todayUtcStart.weekday - 1));
        endDate = startDate.add(const Duration(days: 7));
        startDateStr = weekRange.from;
        endDateStr = weekRange.to;
        break;

      case FinancialPeriod.month:
        final monthRange = TimezoneUtils.getThisMonthBusinessDateRange();
        startDate = DateTime.utc(nowLaPaz.year, nowLaPaz.month, 1).add(const Duration(hours: 4));
        endDate = DateTime.utc(nowLaPaz.year, nowLaPaz.month + 1, 1).add(const Duration(hours: 4));
        startDateStr = monthRange.from;
        endDateStr = monthRange.to;
        break;

      case FinancialPeriod.previousMonth:
        final prevRange = TimezoneUtils.getPreviousMonthBusinessDateRange();
        startDate = DateTime.utc(nowLaPaz.year, nowLaPaz.month - 1, 1).add(const Duration(hours: 4));
        endDate = DateTime.utc(nowLaPaz.year, nowLaPaz.month, 1).add(const Duration(hours: 4));
        startDateStr = prevRange.from;
        endDateStr = prevRange.to;
        break;

      case FinancialPeriod.custom:
        startDateStr = customStartStr ?? todayStr;
        endDateStr = customEndStr ?? todayStr;
        startDate = DateTime.parse('${startDateStr}T00:00:00.000Z').add(const Duration(hours: 4));
        endDate = DateTime.parse('${endDateStr}T00:00:00.000Z').add(const Duration(hours: 4 + 24));
        break;
    }

    final ordersStream = _db.customSelect(
      '''
      SELECT 
        COALESCE(SUM(total), 0.0) as total_sales,
        COUNT(*) as order_count,
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
      readsFrom: {_db.ordersTable},
    ).watchSingle();

    final expensesStream = _db.customSelect(
      '''
      SELECT 
        COALESCE(SUM(amount), 0.0) as total_expenses,
        COUNT(*) as expense_count,
        COALESCE(SUM(CASE WHEN payment_method = 'CASH' THEN amount ELSE 0.0 END), 0.0) as cash_expenses,
        COALESCE(SUM(CASE WHEN payment_method = 'QR' THEN amount ELSE 0.0 END), 0.0) as qr_expenses,
        COALESCE(SUM(CASE WHEN payment_method = 'OTHER' THEN amount ELSE 0.0 END), 0.0) as other_expenses
      FROM expenses_table
      WHERE expense_date >= ? AND expense_date <= ? AND deleted_at IS NULL
      ''',
      variables: [
        Variable.withString(startDateStr),
        Variable.withString(endDateStr),
      ],
      readsFrom: {_db.expensesTable},
    ).watchSingle();

    return _combineLatest2(ordersStream, expensesStream, (orderRow, expenseRow) {
      final totalSales = orderRow.read<double>('total_sales');
      final totalExpenses = expenseRow.read<double>('total_expenses');
      final netResult = totalSales - totalExpenses;

      return FinancialMetricsModel(
        period: period,
        totalSales: totalSales,
        totalExpenses: totalExpenses,
        netResult: netResult,
        cashSales: orderRow.read<double>('cash_sales'),
        qrSales: orderRow.read<double>('qr_sales'),
        otherSales: orderRow.read<double>('other_sales'),
        orderCount: orderRow.read<int>('order_count'),
        cashExpenses: expenseRow.read<double>('cash_expenses'),
        qrExpenses: expenseRow.read<double>('qr_expenses'),
        otherExpenses: expenseRow.read<double>('other_expenses'),
        expenseCount: expenseRow.read<int>('expense_count'),
      );
    });
  }
}
