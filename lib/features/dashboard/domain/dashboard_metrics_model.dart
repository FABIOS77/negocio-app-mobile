import '../../financial_metrics/domain/financial_metrics_model.dart';
import 'top_dish_model.dart';

class DashboardMetricsModel {
  final FinancialPeriod period;
  final int totalOrders;
  final double totalSales;
  final double totalExpenses;
  final double netResult;
  final double cashSales;
  final double qrSales;
  final double otherSales;
  final List<TopDishModel> topDishes;
  final int pendingSyncCount;

  DashboardMetricsModel({
    required this.period,
    required this.totalOrders,
    required this.totalSales,
    required this.totalExpenses,
    required this.netResult,
    required this.cashSales,
    required this.qrSales,
    required this.otherSales,
    required this.topDishes,
    this.pendingSyncCount = 0,
  });

  factory DashboardMetricsModel.empty(FinancialPeriod period) {
    return DashboardMetricsModel(
      period: period,
      totalOrders: 0,
      totalSales: 0.0,
      totalExpenses: 0.0,
      netResult: 0.0,
      cashSales: 0.0,
      qrSales: 0.0,
      otherSales: 0.0,
      topDishes: const [],
      pendingSyncCount: 0,
    );
  }
}
