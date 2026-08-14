import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/utils/currency_formatter.dart';
import '../../daily_menu/application/daily_menu_notifier.dart';
import '../../dishes/domain/dish_model.dart';
import '../application/orders_notifier.dart';

class NewOrderScreen extends ConsumerStatefulWidget {
  const NewOrderScreen({super.key});

  @override
  ConsumerState<NewOrderScreen> createState() => _NewOrderScreenState();
}

class _NewOrderScreenState extends ConsumerState<NewOrderScreen> {
  final _customerController = TextEditingController();
  final _locationController = TextEditingController();
  String _paymentMethod = 'CASH';
  final Map<String, int> _itemQuantities = {};
  bool _isSubmitting = false;

  @override
  void dispose() {
    _customerController.dispose();
    _locationController.dispose();
    super.dispose();
  }

  double _calculateTotal(List<DishModel> dishes) {
    double total = 0.0;
    _itemQuantities.forEach((dishId, qty) {
      if (qty > 0) {
        final dish = dishes.where((d) => d.id == dishId).firstOrNull;
        if (dish != null) {
          total += (dish.price * qty);
        }
      }
    });
    return total;
  }

  void _submit() async {
    final customer = _customerController.text.trim();
    if (customer.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Ingrese el nombre del cliente o mesa')),
      );
      return;
    }

    final selectedItems = <({String dishId, int quantity})>[];
    _itemQuantities.forEach((dishId, qty) {
      if (qty > 0) {
        selectedItems.add((dishId: dishId, quantity: qty));
      }
    });

    if (selectedItems.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Seleccione al menos un plato')),
      );
      return;
    }

    setState(() => _isSubmitting = true);

    try {
      final repository = ref.read(ordersRepositoryProvider);
      await repository.createOrder(
        customerName: customer,
        locationText: _locationController.text.trim().isEmpty ? null : _locationController.text.trim(),
        paymentMethod: _paymentMethod,
        itemsInput: selectedItems,
      );

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('¡Pedido registrado localmente!'), backgroundColor: Colors.green),
        );
        Navigator.pop(context);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error al crear pedido: $e'), backgroundColor: Colors.redAccent),
        );
      }
    } finally {
      if (mounted) setState(() => _isSubmitting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final todayMenuAsync = ref.watch(todayMenuStreamProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Nuevo Pedido de Cocina', style: TextStyle(fontWeight: FontWeight.bold)),
      ),
      body: todayMenuAsync.when(
        data: (menu) {
          final availableDishes = menu?.dishes ?? [];
          final total = _calculateTotal(availableDishes);

          return Padding(
            padding: const EdgeInsets.all(16.0),
            child: Column(
              children: [
                Expanded(
                  child: SingleChildScrollView(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        TextField(
                          controller: _customerController,
                          decoration: const InputDecoration(
                            labelText: 'Nombre del Cliente / Mesa *',
                            border: OutlineInputBorder(),
                            prefixIcon: Icon(Icons.person),
                          ),
                        ),
                        const SizedBox(height: 12),
                        TextField(
                          controller: _locationController,
                          decoration: const InputDecoration(
                            labelText: 'Ubicación / Notas (Opcional)',
                            border: OutlineInputBorder(),
                            prefixIcon: Icon(Icons.location_on_outlined),
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
                          selected: {_paymentMethod},
                          onSelectionChanged: (val) {
                            setState(() {
                              _paymentMethod = val.first;
                            });
                          },
                        ),
                        const SizedBox(height: 20),
                        const Text('Platos del Menú de Hoy:', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                        const SizedBox(height: 8),
                        if (availableDishes.isEmpty)
                          const Padding(
                            padding: EdgeInsets.symmetric(vertical: 24.0),
                            child: Center(
                              child: Text(
                                'No hay platos configurados en el menú de hoy.\nConfigura el menú del día primero.',
                                textAlign: TextAlign.center,
                                style: TextStyle(color: Colors.grey),
                              ),
                            ),
                          )
                        else
                          ...availableDishes.map((dish) {
                            final currentQty = _itemQuantities[dish.id] ?? 0;
                            return Card(
                              margin: const EdgeInsets.only(bottom: 8),
                              child: Padding(
                                padding: const EdgeInsets.symmetric(horizontal: 12.0, vertical: 8.0),
                                child: Row(
                                  children: [
                                    Expanded(
                                      child: Column(
                                        crossAxisAlignment: CrossAxisAlignment.start,
                                        children: [
                                          Text(dish.name, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                                          Text(CurrencyFormatter.formatBOB(dish.price), style: const TextStyle(color: Colors.deepOrange, fontWeight: FontWeight.bold)),
                                        ],
                                      ),
                                    ),
                                    Row(
                                      children: [
                                        IconButton(
                                          icon: const Icon(Icons.remove_circle_outline, size: 32, color: Colors.red),
                                          onPressed: currentQty > 0
                                              ? () {
                                                  setState(() {
                                                    _itemQuantities[dish.id] = currentQty - 1;
                                                  });
                                                }
                                              : null,
                                        ),
                                        Text('$currentQty', style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
                                        IconButton(
                                          icon: const Icon(Icons.add_circle_outline, size: 32, color: Colors.green),
                                          onPressed: () {
                                            setState(() {
                                              _itemQuantities[dish.id] = currentQty + 1;
                                            });
                                          },
                                        ),
                                      ],
                                    ),
                                  ],
                                ),
                              ),
                            );
                          }),
                      ],
                    ),
                  ),
                ),
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    boxShadow: [
                      BoxShadow(color: Colors.black.withValues(alpha: 0.1), blurRadius: 10, offset: const Offset(0, -4)),
                    ],
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text('Total Calculado:', style: TextStyle(color: Colors.grey, fontSize: 12)),
                          Text(
                            CurrencyFormatter.formatBOB(total),
                            style: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold, color: Colors.deepOrange),
                          ),
                        ],
                      ),
                      ElevatedButton.icon(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.green,
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
                        ),
                        icon: const Icon(Icons.check),
                        label: _isSubmitting
                            ? const CircularProgressIndicator(color: Colors.white)
                            : const Text('GUARDAR PEDIDO', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                        onPressed: _isSubmitting ? null : _submit,
                      ),
                    ],
                  ),
                ),
              ],
            ),
          );
        },
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (err, _) => Center(child: Text('Error: $err')),
      ),
    );
  }
}
