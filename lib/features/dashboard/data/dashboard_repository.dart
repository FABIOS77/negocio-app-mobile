import 'dart:async';
import 'package:drift/drift.dart';
import '../../../core/database/app_database.dart';
import '../../../core/utils/timezone_utils.dart';
import '../../financial_metrics/domain/financial_metrics_model.dart';
import '../domain/dashboard_metrics_model.dart';
import '../domain/top_dish_model.dart';

class DashboardRepository {
  final AppDatabase _db;

  DashboardRepository({required AppDatabase db}) : _db = db;

  /// Helper reactivo para combinar 3 streams emitiendo tan pronto cualquiera cambie
  Stream<T4> _combineLatest3<T1, T2, T3, T4>(
    Stream<T1> stream1,
    Stream<T2> stream2,
    Stream<T3> stream3,
    T4 Function(T1 a, T2 b, T3 c) combiner,
  ) {
    late StreamController<T4> controller;
    StreamSubscription<T1>? sub1;
    StreamSubscription<T2>? sub2;
    StreamSubscription<T3>? sub3;
    T1? val1;
    T2? val2;
    T3? val3;
    bool hasVal1 = false;
    bool hasVal2 = false;
    bool hasVal3 = false;

    void emitIfReady() {
      if (hasVal1 && hasVal2 && hasVal3 && !controller.isClosed) {
        controller.add(combiner(val1 as T1, val2 as T2, val3 as T3));
      }
    }

    controller = StreamController<T4>.broadcast(
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
        sub3 ??= stream3.listen(
          (data) {
            val3 = data;
            hasVal3 = true;
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
          await sub3?.cancel();
          sub1 = null;
          sub2 = null;
          sub3 = null;
        }
      },
    );

    return controller.stream;
  }

  /// Observa reactivamente todas las métricas del Dashboard mediante consultas SQL súper optimizadas
  Stream<DashboardMetricsModel> watchDashboardMetrics({
    FinancialPeriod period = FinancialPeriod.today,
    DateTime? customStart,
    DateTime? customEnd,
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
      readsFrom: {_db.ordersTable},
    ).watchSingle();

    final expensesStream = _db.customSelect(
      '''
      SELECT 
        COALESCE(SUM(amount), 0.0) as total_expenses,
        COUNT(*) as total_expenses_count
      FROM expenses_table
      WHERE expense_date >= ? AND expense_date <= ? AND deleted_at IS NULL
      ''',
      variables: [
        Variable.withString(startDateStr),
        Variable.withString(endDateStr),
      ],
      readsFrom: {_db.expensesTable},
    ).watchSingle();

    final topDishesStream = _db.customSelect(
      '''
      SELECT 
        oi.dish_id,
        oi.dish_name_snapshot as dish_name,
        SUM(oi.quantity) as total_quantity,
        SUM(oi.subtotal) as total_revenue
      FROM order_items_table oi
      INNER JOIN orders_table o ON o.id = oi.order_id
      WHERE o.ordered_at >= ? AND o.ordered_at < ? AND o.status != 'CANCELLED'
      GROUP BY oi.dish_id, oi.dish_name_snapshot
      ORDER BY total_quantity DESC
      LIMIT 5
      ''',
      variables: [
        Variable.withDateTime(startDate),
        Variable.withDateTime(endDate),
      ],
      readsFrom: {_db.orderItemsTable, _db.ordersTable},
    ).watch();

    return _combineLatest3(mainStream, expensesStream, topDishesStream, (mainRow, expenseRow, topDishRows) {
      final totalSales = mainRow.read<double>('total_sales');
      final totalExpenses = expenseRow.read<double>('total_expenses');
      final netResult = totalSales - totalExpenses;

      final topDishes = topDishRows.map((r) => TopDishModel(
            dishId: r.read<String>('dish_id'),
            dishName: r.read<String>('dish_name'),
            totalQuantity: r.read<int>('total_quantity'),
            totalRevenue: r.read<double>('total_revenue'),
          )).toList();

      return DashboardMetricsModel(
        period: period,
        totalSales: totalSales,
        totalExpenses: totalExpenses,
        netResult: netResult,
        totalOrders: mainRow.read<int>('total_orders'),
        cashSales: mainRow.read<double>('cash_sales'),
        qrSales: mainRow.read<double>('qr_sales'),
        otherSales: mainRow.read<double>('other_sales'),
        topDishes: topDishes,
      );
    });
  }
}
