enum FinancialPeriod { today, week, month, custom }

class FinancialMetricsModel {
  final FinancialPeriod period;
  final double totalSales;
  final double totalExpenses;
  final double netResult; // totalSales - totalExpenses
  final double cashSales;
  final double qrSales;
  final double otherSales;
  final int orderCount;
  final int expenseCount;

  FinancialMetricsModel({
    required this.period,
    required this.totalSales,
    required this.totalExpenses,
    required this.netResult,
    required this.cashSales,
    required this.qrSales,
    required this.otherSales,
    required this.orderCount,
    required this.expenseCount,
  });

  factory FinancialMetricsModel.empty(FinancialPeriod period) {
    return FinancialMetricsModel(
      period: period,
      totalSales: 0.0,
      totalExpenses: 0.0,
      netResult: 0.0,
      cashSales: 0.0,
      qrSales: 0.0,
      otherSales: 0.0,
      orderCount: 0,
      expenseCount: 0,
    );
  }
}
