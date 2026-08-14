import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/utils/currency_formatter.dart';
import '../application/orders_notifier.dart';
import 'order_detail_dialog.dart';

class OrderHistoryScreen extends ConsumerWidget {
  const OrderHistoryScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final historyAsync = ref.watch(historyOrdersStreamProvider);
    final statusFilter = ref.watch(orderHistoryStatusFilterProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Historial de Pedidos', style: TextStyle(fontWeight: FontWeight.bold)),
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          children: [
            Row(
              children: [
                const Text('Filtrar Estado: ', style: TextStyle(fontWeight: FontWeight.bold)),
                DropdownButton<String?>(
                  value: statusFilter,
                  items: const [
                    DropdownMenuItem(value: null, child: Text('Todos los Estados')),
                    DropdownMenuItem(value: 'PENDING', child: Text('Pendientes')),
                    DropdownMenuItem(value: 'DELIVERED', child: Text('Entregados')),
                    DropdownMenuItem(value: 'CANCELLED', child: Text('Cancelados')),
                  ],
                  onChanged: (val) {
                    ref.read(orderHistoryStatusFilterProvider.notifier).state = val;
                  },
                ),
              ],
            ),
            const SizedBox(height: 12),
            Expanded(
              child: historyAsync.when(
                skipLoadingOnReload: true,
                skipLoadingOnRefresh: true,
                data: (orders) {
                  if (orders.isEmpty) {
                    return const Center(
                      child: Text('No hay pedidos registrados para este filtro.', style: TextStyle(color: Colors.grey)),
                    );
                  }
                  return ListView.builder(
                    itemCount: orders.length,
                    itemBuilder: (context, index) {
                      final order = orders[index];
                      return Card(
                        child: ListTile(
                          onTap: () {
                            showDialog(
                              context: context,
                              builder: (ctx) => OrderDetailDialog(order: order),
                            );
                          },
                          leading: CircleAvatar(
                            backgroundColor: order.status == 'DELIVERED'
                                ? Colors.green.shade100
                                : (order.status == 'CANCELLED' ? Colors.red.shade100 : Colors.orange.shade100),
                            child: Icon(
                              order.status == 'DELIVERED'
                                  ? Icons.check
                                  : (order.status == 'CANCELLED' ? Icons.close : Icons.access_time),
                              color: order.status == 'DELIVERED'
                                  ? Colors.green
                                  : (order.status == 'CANCELLED' ? Colors.red : Colors.orange),
                            ),
                          ),
                          title: Text(
                            order.orderNumber != null ? 'Pedido #${order.orderNumber}' : order.customerName,
                            style: const TextStyle(fontWeight: FontWeight.bold),
                          ),
                          subtitle: Text('Cliente: ${order.customerName} • ${order.paymentMethod}\nSync: ${order.syncStatus}'),
                          trailing: Text(
                            CurrencyFormatter.formatBOB(order.total),
                            style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: Colors.deepOrange),
                          ),
                        ),
                      );
                    },
                  );
                },
                loading: () => const Center(child: CircularProgressIndicator()),
                error: (err, _) => Center(child: Text('Error: $err')),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
