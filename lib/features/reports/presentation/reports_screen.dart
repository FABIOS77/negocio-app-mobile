import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/database/app_database.dart';
import '../../../core/sync/sync_engine.dart';
import '../../../core/utils/currency_formatter.dart';

class ReportsScreen extends ConsumerWidget {
  const ReportsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final db = ref.watch(databaseProvider);

    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('Resumen Financiero Local', style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
          const SizedBox(height: 12),
          StreamBuilder<List<OrdersTableData>>(
            stream: db.select(db.ordersTable).watch(),
            builder: (context, snapshotOrders) {
              final orders = snapshotOrders.data ?? [];
              final totalSales = orders
                  .where((o) => o.status != 'CANCELLED')
                  .fold<double>(0.0, (sum, o) => sum + o.total);

              return StreamBuilder<List<ExpensesTableData>>(
                stream: db.select(db.expensesTable).watch(),
                builder: (context, snapshotExpenses) {
                  final expenses = snapshotExpenses.data ?? [];
                  final totalExpenses = expenses.fold<double>(0.0, (sum, e) => sum + e.amount);
                  final netResult = totalSales - totalExpenses;

                  return Column(
                    children: [
                      Card(
                        elevation: 4,
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                        child: Padding(
                          padding: const EdgeInsets.all(20.0),
                          child: Column(
                            children: [
                              Text(
                                'Resultado Neto Total',
                                style: TextStyle(color: Colors.grey.shade700, fontSize: 14),
                              ),
                              const SizedBox(height: 8),
                              Text(
                                CurrencyFormatter.formatBOB(netResult),
                                style: TextStyle(
                                  fontSize: 32,
                                  fontWeight: FontWeight.bold,
                                  color: netResult >= 0 ? Colors.green.shade700 : Colors.red.shade700,
                                ),
                              ),
                              const Divider(height: 24),
                              Row(
                                mainAxisAlignment: MainAxisAlignment.spaceAround,
                                children: [
                                  Column(
                                    children: [
                                      const Text('Ventas Totales', style: TextStyle(color: Colors.grey, fontSize: 12)),
                                      const SizedBox(height: 4),
                                      Text(
                                        CurrencyFormatter.formatBOB(totalSales),
                                        style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: Colors.green),
                                      ),
                                    ],
                                  ),
                                  Column(
                                    children: [
                                      const Text('Gastos Totales', style: TextStyle(color: Colors.grey, fontSize: 12)),
                                      const SizedBox(height: 4),
                                      Text(
                                        CurrencyFormatter.formatBOB(totalExpenses),
                                        style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: Colors.red),
                                      ),
                                    ],
                                  ),
                                ],
                              ),
                            ],
                          ),
                        ),
                      ),
                      const SizedBox(height: 20),
                      Card(
                        child: ListTile(
                          leading: const Icon(Icons.table_chart, color: Colors.green),
                          title: const Text('Exportar Reporte Excel (.xlsx)', style: TextStyle(fontWeight: FontWeight.bold)),
                          subtitle: const Text('Generado directamente por el backend central'),
                          trailing: const Icon(Icons.download),
                          onTap: () {
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(content: Text('La exportación de Excel requiere sincronización activa con el backend.')),
                            );
                          },
                        ),
                      ),
                    ],
                  );
                },
              );
            },
          ),
        ],
      ),
    );
  }
}
