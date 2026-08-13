import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/sync/sync_engine.dart';
import '../../financial_metrics/domain/financial_metrics_model.dart';
import '../data/dashboard_repository.dart';
import '../domain/dashboard_metrics_model.dart';

final dashboardRepositoryProvider = Provider<DashboardRepository>((ref) {
  final db = ref.watch(databaseProvider);
  return DashboardRepository(db: db);
});

final dashboardPeriodProvider = StateProvider<FinancialPeriod>((ref) => FinancialPeriod.today);

final dashboardMetricsStreamProvider = StreamProvider<DashboardMetricsModel>((ref) {
  final repository = ref.watch(dashboardRepositoryProvider);
  final period = ref.watch(dashboardPeriodProvider);
  return repository.watchDashboardMetrics(period: period);
});
