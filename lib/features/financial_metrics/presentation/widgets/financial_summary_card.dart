import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import '../../../../core/utils/currency_formatter.dart';
import '../../../../core/utils/timezone_utils.dart';
import '../../application/financial_metrics_notifier.dart';
import '../../domain/financial_metrics_model.dart';

class FinancialSummaryCard extends ConsumerWidget {
  const FinancialSummaryCard({super.key});

  Future<void> _pickCustomRange(BuildContext context, WidgetRef ref) async {
    final nowLaPaz = TimezoneUtils.getNowLaPaz();
    final currentStart = ref.read(financialCustomStartProvider);
    final currentEnd = ref.read(financialCustomEndProvider);

    DateTime initialStartDate = currentStart != null ? DateTime.parse(currentStart) : nowLaPaz;
    DateTime initialEndDate = currentEnd != null ? DateTime.parse(currentEnd) : nowLaPaz;

    if (initialStartDate.isAfter(initialEndDate)) {
      initialStartDate = initialEndDate;
    }

    final picked = await showDateRangePicker(
      context: context,
      initialDateRange: DateTimeRange(start: initialStartDate, end: initialEndDate),
      firstDate: DateTime(2020),
      lastDate: DateTime(2035),
      helpText: 'SELECCIONAR PERÍODO RESUMEN',
      cancelText: 'CANCELAR',
      confirmText: 'CONFIRMAR',
      builder: (context, child) {
        return Theme(
          data: Theme.of(context).copyWith(
            colorScheme: Theme.of(context).colorScheme.copyWith(
                  primary: Colors.deepOrange,
                  onPrimary: Colors.white,
                ),
          ),
          child: child!,
        );
      },
    );

    if (picked != null) {
      final fromStr = DateFormat('yyyy-MM-dd').format(picked.start);
      final toStr = DateFormat('yyyy-MM-dd').format(picked.end);

      ref.read(financialCustomStartProvider.notifier).state = fromStr;
      ref.read(financialCustomEndProvider.notifier).state = toStr;
      ref.read(selectedFinancialPeriodProvider.notifier).state = FinancialPeriod.custom;
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final metricsAsync = ref.watch(financialMetricsStreamProvider);
    final selectedPeriod = ref.watch(selectedFinancialPeriodProvider);
    final customStart = ref.watch(financialCustomStartProvider);
    final customEnd = ref.watch(financialCustomEndProvider);

    String periodLabel;
    switch (selectedPeriod) {
      case FinancialPeriod.today:
        periodLabel = 'Hoy (${TimezoneUtils.formatDisplayDate(TimezoneUtils.getTodayBusinessDate())})';
        break;
      case FinancialPeriod.yesterday:
        periodLabel = 'Ayer (${TimezoneUtils.formatDisplayDate(TimezoneUtils.getYesterdayBusinessDate())})';
        break;
      case FinancialPeriod.week:
        final w = TimezoneUtils.getThisWeekBusinessDateRange();
        periodLabel = '${TimezoneUtils.formatDisplayDate(w.from)} - ${TimezoneUtils.formatDisplayDate(w.to)}';
        break;
      case FinancialPeriod.month:
        final m = TimezoneUtils.getThisMonthBusinessDateRange();
        periodLabel = '${TimezoneUtils.formatDisplayDate(m.from)} - ${TimezoneUtils.formatDisplayDate(m.to)}';
        break;
      case FinancialPeriod.previousMonth:
        final pm = TimezoneUtils.getPreviousMonthBusinessDateRange();
        periodLabel = '${TimezoneUtils.formatDisplayDate(pm.from)} - ${TimezoneUtils.formatDisplayDate(pm.to)}';
        break;
      case FinancialPeriod.custom:
        if (customStart != null && customEnd != null) {
          periodLabel = '${TimezoneUtils.formatDisplayDate(customStart)} - ${TimezoneUtils.formatDisplayDate(customEnd)}';
        } else {
          periodLabel = 'Personalizado';
        }
        break;
    }

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
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.account_balance_wallet, color: Colors.deepOrange, size: 26),
                    SizedBox(width: 8),
                    Text('Resumen Financiero', style: TextStyle(fontSize: 17, fontWeight: FontWeight.bold)),
                  ],
                ),
                Text(
                  periodLabel,
                  style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: Colors.grey.shade700),
                ),
              ],
            ),
            const SizedBox(height: 10),
            SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Row(
                children: [
                  ChoiceChip(
                    label: const Text('Hoy'),
                    selected: selectedPeriod == FinancialPeriod.today,
                    onSelected: (selected) {
                      if (selected) ref.read(selectedFinancialPeriodProvider.notifier).state = FinancialPeriod.today;
                    },
                  ),
                  const SizedBox(width: 6),
                  ChoiceChip(
                    label: const Text('Ayer'),
                    selected: selectedPeriod == FinancialPeriod.yesterday,
                    onSelected: (selected) {
                      if (selected) ref.read(selectedFinancialPeriodProvider.notifier).state = FinancialPeriod.yesterday;
                    },
                  ),
                  const SizedBox(width: 6),
                  ChoiceChip(
                    label: const Text('Semana'),
                    selected: selectedPeriod == FinancialPeriod.week,
                    onSelected: (selected) {
                      if (selected) ref.read(selectedFinancialPeriodProvider.notifier).state = FinancialPeriod.week;
                    },
                  ),
                  const SizedBox(width: 6),
                  ChoiceChip(
                    label: const Text('Mes'),
                    selected: selectedPeriod == FinancialPeriod.month,
                    onSelected: (selected) {
                      if (selected) ref.read(selectedFinancialPeriodProvider.notifier).state = FinancialPeriod.month;
                    },
                  ),
                  const SizedBox(width: 6),
                  ChoiceChip(
                    label: const Text('Mes Ant.'),
                    selected: selectedPeriod == FinancialPeriod.previousMonth,
                    onSelected: (selected) {
                      if (selected) ref.read(selectedFinancialPeriodProvider.notifier).state = FinancialPeriod.previousMonth;
                    },
                  ),
                  const SizedBox(width: 6),
                  ChoiceChip(
                    avatar: const Icon(Icons.date_range, size: 14),
                    label: const Text('Rango'),
                    selected: selectedPeriod == FinancialPeriod.custom,
                    onSelected: (selected) {
                      _pickCustomRange(context, ref);
                    },
                  ),
                ],
              ),
            ),
            const SizedBox(height: 14),
            metricsAsync.when(
              skipLoadingOnReload: true,
              skipLoadingOnRefresh: true,
              data: (m) {
                final isPositive = m.netResult >= 0;
                return Column(
                  children: [
                    if (metricsAsync.isRefreshing || metricsAsync.isReloading)
                      const Padding(
                        padding: EdgeInsets.only(bottom: 8.0),
                        child: LinearProgressIndicator(minHeight: 2),
                      ),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceAround,
                      children: [
                        _buildMetricCol('Ventas (${m.orderCount})', CurrencyFormatter.formatBOB(m.totalSales), Colors.green.shade700),
                        _buildMetricCol('Gastos (${m.expenseCount})', '-${CurrencyFormatter.formatBOB(m.totalExpenses)}', Colors.red.shade700),
                        _buildMetricCol('Resultado Neto', CurrencyFormatter.formatBOB(m.netResult), isPositive ? Colors.blue.shade800 : Colors.red.shade800),
                      ],
                    ),
                    const Divider(height: 22),
                    // Desglose de Ventas por Método de Pago
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text('Ventas: ', style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Colors.green)),
                        Expanded(
                          child: Text(
                            'Efec: ${CurrencyFormatter.formatBOB(m.cashSales)} • QR: ${CurrencyFormatter.formatBOB(m.qrSales)} • Otro: ${CurrencyFormatter.formatBOB(m.otherSales)}',
                            style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w500),
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 4),
                    // Desglose de Gastos por Método de Pago
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text('Gastos: ', style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Colors.red)),
                        Expanded(
                          child: Text(
                            'Efec: ${CurrencyFormatter.formatBOB(m.cashExpenses)} • QR: ${CurrencyFormatter.formatBOB(m.qrExpenses)} • Otro: ${CurrencyFormatter.formatBOB(m.otherExpenses)}',
                            style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w500),
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ],
                    ),
                  ],
                );
              },
              loading: () => const SizedBox(
                height: 100,
                child: Center(child: CircularProgressIndicator()),
              ),
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
        Text(value, style: TextStyle(fontSize: 17, fontWeight: FontWeight.bold, color: color)),
      ],
    );
  }
}
