import 'package:flutter/material.dart';
import '../../../../core/utils/currency_formatter.dart';
import '../../domain/dashboard_metrics_model.dart';

class ExecutiveSummaryCardsWidget extends StatelessWidget {
  final DashboardMetricsModel metrics;

  const ExecutiveSummaryCardsWidget({super.key, required this.metrics});

  @override
  Widget build(BuildContext context) {
    final isPositiveNet = metrics.netResult >= 0;

    return Column(
      children: [
        Row(
          children: [
            Expanded(
              child: _buildSummaryCard(
                title: 'Pedidos del Período',
                value: '${metrics.totalOrders} pedidos',
                icon: Icons.receipt_long,
                iconColor: Colors.blue,
                bgColor: Colors.blue.shade50,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: _buildSummaryCard(
                title: 'Ventas Totales',
                value: CurrencyFormatter.formatBOB(metrics.totalSales),
                icon: Icons.attach_money,
                iconColor: Colors.green,
                bgColor: Colors.green.shade50,
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        Row(
          children: [
            Expanded(
              child: _buildSummaryCard(
                title: 'Gastos Totales',
                value: '-${CurrencyFormatter.formatBOB(metrics.totalExpenses)}',
                icon: Icons.money_off,
                iconColor: Colors.red,
                bgColor: Colors.red.shade50,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: _buildSummaryCard(
                title: 'Resultado Neto',
                value: CurrencyFormatter.formatBOB(metrics.netResult),
                icon: isPositiveNet ? Icons.trending_up : Icons.trending_down,
                iconColor: isPositiveNet ? Colors.teal : Colors.deepOrange,
                bgColor: isPositiveNet ? Colors.teal.shade50 : Colors.deepOrange.shade50,
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildSummaryCard({
    required String title,
    required String value,
    required IconData icon,
    required Color iconColor,
    required Color bgColor,
  }) {
    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(title, style: const TextStyle(fontSize: 12, color: Colors.grey, fontWeight: FontWeight.w600)),
                CircleAvatar(
                  radius: 16,
                  backgroundColor: bgColor,
                  child: Icon(icon, color: iconColor, size: 18),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Text(
              value,
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: iconColor,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
