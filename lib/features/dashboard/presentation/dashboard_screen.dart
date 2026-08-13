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
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text('Resumen Ejecutivo', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                  SegmentedButton<FinancialPeriod>(
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
                ],
              ),
              const SizedBox(height: 16),
              metricsAsync.when(
                data: (metrics) {
                  return Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
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
