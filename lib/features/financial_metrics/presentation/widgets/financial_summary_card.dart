import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../core/utils/currency_formatter.dart';
import '../../application/financial_metrics_notifier.dart';
import '../../domain/financial_metrics_model.dart';

class FinancialSummaryCard extends ConsumerWidget {
  const FinancialSummaryCard({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final metricsAsync = ref.watch(financialMetricsStreamProvider);
    final selectedPeriod = ref.watch(selectedFinancialPeriodProvider);

    return Card(
      elevation: 3,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Row(
                  children: [
                    Icon(Icons.account_balance_wallet, color: Colors.deepOrange, size: 28),
                    SizedBox(width: 8),
                    Text('Resumen Financiero', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                  ],
                ),
                SegmentedButton<FinancialPeriod>(
                  segments: const [
                    ButtonSegment(value: FinancialPeriod.today, label: Text('Hoy')),
                    ButtonSegment(value: FinancialPeriod.week, label: Text('Semana')),
                    ButtonSegment(value: FinancialPeriod.month, label: Text('Mes')),
                  ],
                  selected: {selectedPeriod},
                  onSelectionChanged: (val) {
                    ref.read(selectedFinancialPeriodProvider.notifier).state = val.first;
                  },
                ),
              ],
            ),
            const SizedBox(height: 16),
            metricsAsync.when(
              data: (m) {
                final isPositive = m.netResult >= 0;
                return Column(
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceAround,
                      children: [
                        _buildMetricCol('Ventas (${m.orderCount})', CurrencyFormatter.formatBOB(m.totalSales), Colors.green),
                        _buildMetricCol('Gastos (${m.expenseCount})', '-${CurrencyFormatter.formatBOB(m.totalExpenses)}', Colors.red),
                        _buildMetricCol('Resultado Neto', CurrencyFormatter.formatBOB(m.netResult), isPositive ? Colors.blue.shade700 : Colors.red.shade700),
                      ],
                    ),
                    const Divider(height: 24),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceAround,
                      children: [
                        Text('Efectivo: ${CurrencyFormatter.formatBOB(m.cashSales)}', style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600)),
                        Text('QR: ${CurrencyFormatter.formatBOB(m.qrSales)}', style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600)),
                        Text('Otro: ${CurrencyFormatter.formatBOB(m.otherSales)}', style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600)),
                      ],
                    ),
                  ],
                );
              },
              loading: () => const Center(child: CircularProgressIndicator()),
              error: (err, _) => Text('Error al cargar métricas: $err'),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildMetricCol(String label, String value, Color color) {
    return Column(
      children: [
        Text(label, style: const TextStyle(fontSize: 12, color: Colors.grey)),
        const SizedBox(height: 4),
        Text(value, style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: color)),
      ],
    );
  }
}
