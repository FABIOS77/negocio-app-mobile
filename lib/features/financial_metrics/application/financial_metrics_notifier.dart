import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/sync/sync_engine.dart';
import '../data/financial_metrics_repository.dart';
import '../domain/financial_metrics_model.dart';

final financialMetricsRepositoryProvider = Provider<FinancialMetricsRepository>((ref) {
  final db = ref.watch(databaseProvider);
  return FinancialMetricsRepository(db: db);
});

final selectedFinancialPeriodProvider = StateProvider<FinancialPeriod>((ref) => FinancialPeriod.today);
final financialCustomStartProvider = StateProvider<String?>((ref) => null);
final financialCustomEndProvider = StateProvider<String?>((ref) => null);

final financialMetricsStreamProvider = StreamProvider<FinancialMetricsModel>((ref) {
  final repository = ref.watch(financialMetricsRepositoryProvider);
  final period = ref.watch(selectedFinancialPeriodProvider);
  final customStart = ref.watch(financialCustomStartProvider);
  final customEnd = ref.watch(financialCustomEndProvider);

  return repository.watchMetrics(
    period: period,
    customStartStr: customStart,
    customEndStr: customEnd,
  );
});
