import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../core/sync/sync_engine.dart';
import '../../financial_metrics/domain/financial_metrics_model.dart';
import '../../orders/presentation/new_order_screen.dart';
import '../../reports/presentation/widgets/export_excel_button_widget.dart';

import '../application/dashboard_notifier.dart';
import 'widgets/executive_summary_cards_widget.dart';
import 'widgets/payment_breakdown_widget.dart';
import 'widgets/quick_actions_widget.dart';
import 'widgets/sync_status_banner_widget.dart';
import 'widgets/top_dishes_list_widget.dart';

class DashboardScreen extends ConsumerWidget {
  const DashboardScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final metricsAsync = ref.watch(dashboardMetricsStreamProvider);
    final selectedPeriod = ref.watch(dashboardPeriodProvider);
    final syncEngine = ref.read(syncEngineProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Katering Grecia', style: TextStyle(fontWeight: FontWeight.bold)),
        actions: [
          Padding(
            padding: const EdgeInsets.only(right: 12.0),
            child: metricsAsync.when(
              skipLoadingOnReload: true,
              skipLoadingOnRefresh: true,
              data: (m) => SyncStatusBannerWidget(
                pendingCount: m.pendingSyncCount,
                onSyncTap: () => syncEngine.syncAll(),
              ),
              loading: () => const SizedBox.shrink(),
              error: (_, __) => const SizedBox.shrink(),
            ),
          ),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: () async {
          await syncEngine.syncAll();
        },
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(16.0),
          physics: const AlwaysScrollableScrollPhysics(),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Wrap(
                alignment: WrapAlignment.spaceBetween,
                crossAxisAlignment: WrapCrossAlignment.center,
                runSpacing: 10.0,
                spacing: 12.0,
                children: [
                  const Text('Resumen Ejecutivo', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                  SingleChildScrollView(
                    scrollDirection: Axis.horizontal,
                    child: SegmentedButton<FinancialPeriod>(
                      segments: const [
                        ButtonSegment(value: FinancialPeriod.today, label: Text('Hoy')),
                        ButtonSegment(value: FinancialPeriod.week, label: Text('Semana')),
                        ButtonSegment(value: FinancialPeriod.month, label: Text('Mes')),
                      ],
                      selected: {selectedPeriod},
                      onSelectionChanged: (val) {
                        ref.read(dashboardPeriodProvider.notifier).state = val.first;
                      },
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              metricsAsync.when(
                skipLoadingOnReload: true,
                skipLoadingOnRefresh: true,
                data: (metrics) {
                  return Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      if (metricsAsync.isRefreshing || metricsAsync.isReloading)
                        const Padding(
                          padding: EdgeInsets.only(bottom: 8.0),
                          child: LinearProgressIndicator(minHeight: 2),
                        ),
                      ExecutiveSummaryCardsWidget(metrics: metrics),
                      const SizedBox(height: 16),
                      PaymentBreakdownWidget(metrics: metrics),
                      const SizedBox(height: 16),
                      TopDishesListWidget(topDishes: metrics.topDishes),
                    ],
                  );
                },
                loading: () => const SizedBox(
                  height: 200,
                  child: Center(child: CircularProgressIndicator()),
                ),
                error: (err, _) => Card(
                  child: Padding(
                    padding: const EdgeInsets.all(16.0),
                    child: Text('Error al cargar datos del Dashboard: $err'),
                  ),
                ),
              ),
              const SizedBox(height: 20),
              const Center(child: ExportExcelButtonWidget()),
              const SizedBox(height: 20),
              QuickActionsWidget(
                onNewOrder: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(builder: (ctx) => const NewOrderScreen()),
                  );
                },
                onDailyMenu: () {
                  context.go('/daily-menu');
                },
                onDishes: () {
                  context.go('/dishes');
                },
                onNewExpense: () {
                  context.go('/expenses');
                },
                onProduction: () {
                  context.go('/orders');
                },
              ),
            ],
          ),
        ),
      ),
    );
  }
}
