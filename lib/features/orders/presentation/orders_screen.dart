import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/utils/currency_formatter.dart';
import '../../common/presentation/widgets/confirm_dialog.dart';
import '../../common/presentation/widgets/empty_state_widget.dart';
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
    final repository = ref.read(ordersRepositoryProvider);

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
                      padding: EdgeInsets.all(16.0),
                      child: EmptyStateWidget(
                        icon: Icons.receipt_long,
                        title: 'Aún no hay pedidos registrados para hoy',
                        subtitle: '¡Toca el botón + NUEVO PEDIDO para registrar uno en cocina offline!',
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
                    final isPending = order.status == 'PENDING';

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
                        trailing: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Text(
                              CurrencyFormatter.formatBOB(order.total),
                              style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.deepOrange),
                            ),
                            if (isPending) ...[
                              PopupMenuButton<String>(
                                onSelected: (val) async {
                                  if (val == 'edit') {
                                    Navigator.push(
                                      context,
                                      MaterialPageRoute(builder: (ctx) => NewOrderScreen(orderToEdit: order)),
                                    );
                                  } else if (val == 'delete') {
                                    final confirmed = await ConfirmDialog.show(
                                      context,
                                      title: 'Eliminar Pedido',
                                      content: '¿Está seguro de eliminar el pedido de ${order.customerName}?',
                                      confirmLabel: 'SÍ, ELIMINAR',
                                      confirmColor: Colors.red,
                                    );
                                    if (confirmed) {
                                      await repository.deleteOrder(order.id);
                                      if (context.mounted) {
                                        ScaffoldMessenger.of(context).showSnackBar(
                                          const SnackBar(content: Text('Pedido eliminado localmente'), backgroundColor: Colors.redAccent),
                                        );
                                      }
                                    }
                                  }
                                },
                                itemBuilder: (ctx) => const [
                                  PopupMenuItem(value: 'edit', child: Row(children: [Icon(Icons.edit, color: Colors.blue), SizedBox(width: 8), Text('Editar')])),
                                  PopupMenuItem(value: 'delete', child: Row(children: [Icon(Icons.delete_outline, color: Colors.red), SizedBox(width: 8), Text('Eliminar')])),
                                ],
                              ),
                            ],
                          ],
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
