import 'package:drift/drift.dart' hide Column;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:uuid/uuid.dart';
import '../../../core/database/app_database.dart';
import '../../../core/sync/sync_engine.dart';

final ordersStreamProvider = StreamProvider<List<OrdersTableData>>((ref) {
  final db = ref.watch(databaseProvider);
  return (db.select(db.ordersTable)
        ..orderBy([(t) => OrderingTerm(expression: t.createdAt, mode: OrderingMode.desc)]))
      .watch();
});

class OrdersScreen extends ConsumerWidget {
  const OrdersScreen({super.key});

  void _showNewOrderDialog(BuildContext context, WidgetRef ref) {
    final customerController = TextEditingController();
    String paymentMethod = 'CASH';
    final uuid = const Uuid();

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) {
        return StatefulBuilder(
          builder: (context, setState) {
            return Padding(
              padding: EdgeInsets.only(
                top: 20,
                left: 20,
                right: 20,
                bottom: MediaQuery.of(context).viewInsets.bottom + 20,
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text(
                        'Crear Pedido Offline',
                        style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
                      ),
                      IconButton(
                        icon: const Icon(Icons.close),
                        onPressed: () => Navigator.pop(ctx),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  TextField(
                    controller: customerController,
                    decoration: const InputDecoration(
                      labelText: 'Nombre del Cliente / Mesa',
                      border: OutlineInputBorder(),
                      prefixIcon: Icon(Icons.person),
                    ),
                  ),
                  const SizedBox(height: 16),
                  const Text('Método de Pago:', style: TextStyle(fontWeight: FontWeight.bold)),
                  const SizedBox(height: 8),
                  SegmentedButton<String>(
                    segments: const [
                      ButtonSegment(value: 'CASH', label: Text('Efectivo'), icon: Icon(Icons.money)),
                      ButtonSegment(value: 'QR', label: Text('QR'), icon: Icon(Icons.qr_code)),
                      ButtonSegment(value: 'OTHER', label: Text('Otro'), icon: Icon(Icons.more_horiz)),
                    ],
                    selected: {paymentMethod},
                    onSelectionChanged: (val) {
                      setState(() {
                        paymentMethod = val.first;
                      });
                    },
                  ),
                  const SizedBox(height: 24),
                  SizedBox(
                    width: double.infinity,
                    height: 50,
                    child: ElevatedButton.icon(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.green,
                        foregroundColor: Colors.white,
                      ),
                      icon: const Icon(Icons.check_circle),
                      label: const Text('GUARDAR PEDIDO LOCALMENTE', style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold)),
                      onPressed: () async {
                        final name = customerController.text.trim();
                        if (name.isEmpty) return;

                        final orderId = uuid.v4();
                        final db = ref.read(databaseProvider);
                        final queue = ref.read(syncQueueManagerProvider);
                        final now = DateTime.now().toUtc();

                        // 1. Guardar en SQLite
                        await db.into(db.ordersTable).insert(
                              OrdersTableCompanion.insert(
                                id: orderId,
                                customerName: name,
                                total: 0.0,
                                paymentMethod: paymentMethod,
                                status: 'PENDING',
                                orderedAt: now,
                                createdBy: 'local-user',
                                syncStatus: const Value('PENDING'),
                                createdAt: now,
                                updatedAt: now,
                              ),
                            );

                        // 2. Encolar mutación offline PULL/PUSH
                        await queue.enqueueOperation(
                          entityType: 'order',
                          entityId: orderId,
                          operation: 'CREATE',
                          payload: {
                            'id': orderId,
                            'customer_name': name,
                            'payment_method': paymentMethod,
                            'ordered_at': now.toIso8601String(),
                            'items': [],
                          },
                        );

                        if (ctx.mounted) Navigator.pop(ctx);

                        // 3. Intentar sync de fondo en silencio
                        ref.read(syncEngineProvider).syncAll();
                      },
                    ),
                  ),
                ],
              ),
            );
          },
        );
      },
    );
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final ordersAsync = ref.watch(ordersStreamProvider);

    return Scaffold(
      floatingActionButton: FloatingActionButton.extended(
        backgroundColor: Colors.green,
        icon: const Icon(Icons.add, color: Colors.white),
        label: const Text('NUEVO PEDIDO', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
        onPressed: () => _showNewOrderDialog(context, ref),
      ),
      body: ordersAsync.when(
        data: (orders) {
          if (orders.isEmpty) {
            return const Center(
              child: Text(
                'No hay pedidos registrados aún.\n¡Toca + NUEVO PEDIDO para crear uno offline!',
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 16, color: Colors.grey),
              ),
            );
          }
          return ListView.builder(
            padding: const EdgeInsets.all(12),
            itemCount: orders.length,
            itemBuilder: (context, index) {
              final order = orders[index];
              final isSynced = order.syncStatus == 'SYNCED';

              return Card(
                elevation: 2,
                margin: const EdgeInsets.only(bottom: 12),
                child: ListTile(
                  leading: CircleAvatar(
                    backgroundColor: isSynced ? Colors.green.shade100 : Colors.orange.shade100,
                    child: Icon(
                      isSynced ? Icons.cloud_done : Icons.cloud_upload,
                      color: isSynced ? Colors.green : Colors.orange,
                    ),
                  ),
                  title: Text(
                    order.customerName,
                    style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                  ),
                  subtitle: Text(
                    '${order.paymentMethod} • Estado: ${order.status}\n${order.syncStatus}',
                    style: const TextStyle(fontSize: 12),
                  ),
                  trailing: Text(
                    'Bs ${order.total.toStringAsFixed(2)}',
                    style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.deepOrange),
                  ),
                ),
              );
            },
          );
        },
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (err, stack) => Center(child: Text('Error: $err')),
      ),
    );
  }
}
