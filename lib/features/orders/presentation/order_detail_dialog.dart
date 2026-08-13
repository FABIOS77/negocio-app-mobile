import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/utils/currency_formatter.dart';
import '../../common/presentation/widgets/confirm_dialog.dart';
import '../application/orders_notifier.dart';
import '../domain/order_model.dart';

class OrderDetailDialog extends ConsumerWidget {
  final OrderModel order;

  const OrderDetailDialog({super.key, required this.order});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final repository = ref.read(ordersRepositoryProvider);
    final isTerminal = order.status == 'DELIVERED' || order.status == 'CANCELLED';

    return AlertDialog(
      title: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Expanded(
            child: Text(
              order.orderNumber != null ? 'Pedido #${order.orderNumber}' : 'Pedido Offline',
              style: const TextStyle(fontWeight: FontWeight.bold),
              overflow: TextOverflow.ellipsis,
            ),
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
            decoration: BoxDecoration(
              color: order.status == 'DELIVERED'
                  ? Colors.green.shade100
                  : (order.status == 'CANCELLED' ? Colors.red.shade100 : Colors.orange.shade100),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Text(
              order.status,
              style: TextStyle(
                fontWeight: FontWeight.bold,
                fontSize: 12,
                color: order.status == 'DELIVERED'
                    ? Colors.green
                    : (order.status == 'CANCELLED' ? Colors.red : Colors.orange),
              ),
            ),
          ),
        ],
      ),
      content: SizedBox(
        width: double.maxFinite,
        child: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text('Cliente: ${order.customerName}', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
              if (order.locationText != null && order.locationText!.isNotEmpty)
                Text('Ubicación: ${order.locationText}'),
              Text('Pago: ${order.paymentMethod}'),
              const Divider(height: 20),
              const Text('Items del Pedido:', style: TextStyle(fontWeight: FontWeight.bold)),
              const SizedBox(height: 8),
              ...order.items.map((item) {
                return Padding(
                  padding: const EdgeInsets.symmetric(vertical: 4.0),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text('${item.quantity}x ${item.dishNameSnapshot}'),
                      Text(CurrencyFormatter.formatBOB(item.subtotal), style: const TextStyle(fontWeight: FontWeight.bold)),
                    ],
                  ),
                );
              }),
              const Divider(height: 20),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text('Total:', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                  Text(CurrencyFormatter.formatBOB(order.total), style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 20, color: Colors.deepOrange)),
                ],
              ),
            ],
          ),
        ),
      ),
      actions: [
        if (!isTerminal) ...[
          ElevatedButton.icon(
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.green,
              foregroundColor: Colors.white,
              minimumSize: const Size(110, 48), // Área táctil de 48dp
            ),
            icon: const Icon(Icons.check),
            label: const Text('ENTREGAR'),
            onPressed: () async {
              await repository.changeOrderStatus(order.id, 'DELIVERED');
              if (context.mounted) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Pedido marcado como ENTREGADO')),
                );
                Navigator.pop(context);
              }
            },
          ),
          ElevatedButton.icon(
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.red,
              foregroundColor: Colors.white,
              minimumSize: const Size(110, 48), // Área táctil de 48dp
            ),
            icon: const Icon(Icons.cancel),
            label: const Text('CANCELAR'),
            onPressed: () async {
              final confirmed = await ConfirmDialog.show(
                context,
                title: 'Cancelar Pedido',
                content: '¿Está seguro de cancelar el pedido de ${order.customerName} por ${CurrencyFormatter.formatBOB(order.total)}?',
                confirmLabel: 'SÍ, CANCELAR',
                confirmColor: Colors.red,
              );
              if (confirmed) {
                await repository.changeOrderStatus(order.id, 'CANCELLED');
                if (context.mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Pedido CANCELADO')),
                  );
                  Navigator.pop(context);
                }
              }
            },
          ),
        ],
        TextButton(
          style: TextButton.styleFrom(minimumSize: const Size(80, 48)),
          onPressed: () => Navigator.pop(context),
          child: const Text('Cerrar'),
        ),
      ],
    );
  }
}
