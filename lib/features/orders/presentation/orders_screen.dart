import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/utils/currency_formatter.dart';
import '../../production/presentation/production_summary_widget.dart';
import '../application/orders_notifier.dart';
import 'new_order_screen.dart';
import 'order_detail_dialog.dart';
import 'order_history_screen.dart';

class OrdersScreen extends ConsumerWidget {
  const OrdersScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final todayOrdersAsync = ref.watch(todayOrdersStreamProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Gestión de Pedidos Hoy', style: TextStyle(fontWeight: FontWeight.bold)),
        actions: [
          IconButton(
            icon: const Icon(Icons.history),
            tooltip: 'Historial de Pedidos',
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(builder: (ctx) => const OrderHistoryScreen()),
              );
            },
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        backgroundColor: Colors.green,
        icon: const Icon(Icons.add, color: Colors.white),
        label: const Text('NUEVO PEDIDO', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
        onPressed: () {
          Navigator.push(
            context,
            MaterialPageRoute(builder: (ctx) => const NewOrderScreen()),
          );
        },
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const ProductionSummaryWidget(),
            const SizedBox(height: 20),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text('Pedidos de Hoy', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                TextButton(
                  onPressed: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(builder: (ctx) => const OrderHistoryScreen()),
                    );
                  },
                  child: const Text('Ver Historial'),
                ),
              ],
            ),
            const SizedBox(height: 8),
            todayOrdersAsync.when(
              data: (orders) {
                if (orders.isEmpty) {
                  return const Card(
                    child: Padding(
                      padding: EdgeInsets.all(24.0),
                      child: Center(
                        child: Text(
                          'No hay pedidos registrados para el día de hoy.\n¡Toca + NUEVO PEDIDO para registrar uno en cocina!',
                          textAlign: TextAlign.center,
                          style: TextStyle(color: Colors.grey),
                        ),
                      ),
                    ),
                  );
                }
                return ListView.builder(
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  itemCount: orders.length,
                  itemBuilder: (context, index) {
                    final order = orders[index];
                    final isSynced = order.syncStatus == 'SYNCED';

                    return Card(
                      elevation: 2,
                      margin: const EdgeInsets.only(bottom: 10),
                      child: ListTile(
                        onTap: () {
                          showDialog(
                            context: context,
                            builder: (ctx) => OrderDetailDialog(order: order),
                          );
                        },
                        leading: CircleAvatar(
                          backgroundColor: isSynced ? Colors.green.shade100 : Colors.orange.shade100,
                          child: Icon(
                            isSynced ? Icons.cloud_done : Icons.cloud_upload,
                            color: isSynced ? Colors.green : Colors.orange,
                          ),
                        ),
                        title: Text(
                          order.orderNumber != null ? 'Pedido #${order.orderNumber} • ${order.customerName}' : order.customerName,
                          style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                        ),
                        subtitle: Text(
                          '${order.paymentMethod} • Estado: ${order.status}\nItems: ${order.items.length} platos',
                          style: const TextStyle(fontSize: 12),
                        ),
                        trailing: Text(
                          CurrencyFormatter.formatBOB(order.total),
                          style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.deepOrange),
                        ),
                      ),
                    );
                  },
                );
              },
              loading: () => const Center(child: CircularProgressIndicator()),
              error: (err, _) => Center(child: Text('Error: $err')),
            ),
          ],
        ),
      ),
    );
  }
}
