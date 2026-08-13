import 'package:flutter/material.dart';
import '../../../../core/utils/currency_formatter.dart';
import '../../domain/dashboard_metrics_model.dart';

class PaymentBreakdownWidget extends StatelessWidget {
  final DashboardMetricsModel metrics;

  const PaymentBreakdownWidget({super.key, required this.metrics});

  @override
  Widget build(BuildContext context) {
    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Desglose de Métodos de Pago',
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 12),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceAround,
              children: [
                _buildMethodItem(
                  label: 'Efectivo',
                  amount: metrics.cashSales,
                  icon: Icons.money,
                  color: Colors.green,
                ),
                _buildMethodItem(
                  label: 'QR',
                  amount: metrics.qrSales,
                  icon: Icons.qr_code,
                  color: Colors.purple,
                ),
                _buildMethodItem(
                  label: 'Otro',
                  amount: metrics.otherSales,
                  icon: Icons.more_horiz,
                  color: Colors.orange,
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildMethodItem({
    required String label,
    required double amount,
    required IconData icon,
    required Color color,
  }) {
    return Column(
      children: [
        Icon(icon, color: color, size: 28),
        const SizedBox(height: 4),
        Text(label, style: const TextStyle(fontSize: 12, color: Colors.grey)),
        const SizedBox(height: 2),
        Text(
          CurrencyFormatter.formatBOB(amount),
          style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14, color: color),
        ),
      ],
    );
  }
}
