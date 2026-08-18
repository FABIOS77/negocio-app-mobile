import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/utils/currency_formatter.dart';
import '../../daily_menu/application/daily_menu_notifier.dart';
import '../../dishes/domain/dish_model.dart';
import '../application/orders_notifier.dart';
import '../domain/order_model.dart';

class NewOrderScreen extends ConsumerStatefulWidget {
  final OrderModel? orderToEdit;

  const NewOrderScreen({super.key, this.orderToEdit});

  @override
  ConsumerState<NewOrderScreen> createState() => _NewOrderScreenState();
}

class _NewOrderScreenState extends ConsumerState<NewOrderScreen> {
  late TextEditingController _customerController;
  late TextEditingController _locationController;
  late String _paymentMethod;
  final Map<String, int> _itemQuantities = {};
  bool _isSubmitting = false;

  @override
  void initState() {
    super.initState();
    final edit = widget.orderToEdit;
    _customerController = TextEditingController(text: edit?.customerName ?? '');
    _locationController = TextEditingController(text: edit?.locationText ?? '');
    _paymentMethod = edit?.paymentMethod ?? 'CASH';

    if (edit != null) {
      for (final item in edit.items) {
        _itemQuantities[item.dishId] = item.quantity;
      }
    }
  }

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

  void _showQuantityDialog(BuildContext context, String dishId, String dishName, int currentQty) {
    final qtyController = TextEditingController(text: currentQty > 0 ? '$currentQty' : '');
    final formKey = GlobalKey<FormState>();

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Row(
          children: [
            const Icon(Icons.edit_note, color: Colors.deepOrange),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                dishName,
                style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ],
        ),
        content: Form(
          key: formKey,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text('Ingrese la cantidad de platos:', style: TextStyle(fontSize: 13, color: Colors.grey)),
              const SizedBox(height: 12),
              TextFormField(
                key: const Key('quantity_dialog_input'),
                controller: qtyController,
                autofocus: true,
                keyboardType: TextInputType.number,
                decoration: const InputDecoration(
                  labelText: 'Cantidad *',
                  hintText: 'Ej. 100',
                  border: OutlineInputBorder(),
                  prefixIcon: Icon(Icons.numbers),
                ),
                validator: (val) {
                  if (val == null || val.trim().isEmpty) {
                    return 'Ingrese una cantidad';
                  }
                  final parsed = int.tryParse(val.trim());
                  if (parsed == null || parsed < 0) {
                    return 'Ingrese un número entero válido (≥ 0)';
                  }
                  return null;
                },
                onFieldSubmitted: (val) {
                  if (formKey.currentState?.validate() ?? false) {
                    final qty = int.parse(val.trim());
                    setState(() {
                      _itemQuantities[dishId] = qty;
                    });
                    Navigator.pop(ctx);
                  }
                },
              ),
              const SizedBox(height: 12),
              Wrap(
                spacing: 8,
                runSpacing: 4,
                children: [10, 25, 50, 100, 150].map((preset) {
                  return ActionChip(
                    label: Text('+$preset', style: const TextStyle(fontSize: 12)),
                    onPressed: () {
                      final current = int.tryParse(qtyController.text.trim()) ?? 0;
                      qtyController.text = '${current + preset}';
                    },
                  );
                }).toList(),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancelar'),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.deepOrange,
              foregroundColor: Colors.white,
            ),
            onPressed: () {
              if (formKey.currentState?.validate() ?? false) {
                final qty = int.parse(qtyController.text.trim());
                setState(() {
                  _itemQuantities[dishId] = qty;
                });
                Navigator.pop(ctx);
              }
            },
            child: const Text('ACEPTAR', style: TextStyle(fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );
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
      final locationText = _locationController.text.trim().isEmpty ? null : _locationController.text.trim();

      if (widget.orderToEdit != null) {
        await repository.updateOrder(
          id: widget.orderToEdit!.id,
          customerName: customer,
          locationText: locationText,
          paymentMethod: _paymentMethod,
          itemsInput: selectedItems,
        );

        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('¡Pedido actualizado localmente!'), backgroundColor: Colors.green),
          );
          Navigator.pop(context);
        }
      } else {
        await repository.createOrder(
          customerName: customer,
          locationText: locationText,
          paymentMethod: _paymentMethod,
          itemsInput: selectedItems,
        );

        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('¡Pedido registrado localmente!'), backgroundColor: Colors.green),
          );
          Navigator.pop(context);
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error al guardar pedido: $e'), backgroundColor: Colors.redAccent),
        );
      }
    } finally {
      if (mounted) setState(() => _isSubmitting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final todayMenuAsync = ref.watch(todayMenuStreamProvider);
    final isEditing = widget.orderToEdit != null;

    return Scaffold(
      appBar: AppBar(
        title: Text(isEditing ? 'Editar Pedido de Cocina' : 'Nuevo Pedido de Cocina', style: const TextStyle(fontWeight: FontWeight.bold)),
      ),
      body: todayMenuAsync.when(
        skipLoadingOnReload: true,
        skipLoadingOnRefresh: true,
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
                                          key: Key('btn_remove_${dish.id}'),
                                          icon: const Icon(Icons.remove_circle_outline, size: 30, color: Colors.red),
                                          onPressed: currentQty > 0
                                              ? () {
                                                  setState(() {
                                                    _itemQuantities[dish.id] = currentQty - 1;
                                                  });
                                                }
                                              : null,
                                        ),
                                        InkWell(
                                          key: Key('qty_badge_${dish.id}'),
                                          onTap: () => _showQuantityDialog(context, dish.id, dish.name, currentQty),
                                          borderRadius: BorderRadius.circular(8),
                                          child: Container(
                                            constraints: const BoxConstraints(minWidth: 44, minHeight: 36),
                                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                            decoration: BoxDecoration(
                                              color: currentQty > 0 ? Colors.deepOrange.shade50 : Colors.grey.shade100,
                                              border: Border.all(
                                                color: currentQty > 0 ? Colors.deepOrange.shade300 : Colors.grey.shade300,
                                                width: 1.5,
                                              ),
                                              borderRadius: BorderRadius.circular(8),
                                            ),
                                            alignment: Alignment.center,
                                            child: Text(
                                              '$currentQty',
                                              style: TextStyle(
                                                fontSize: 18,
                                                fontWeight: FontWeight.bold,
                                                color: currentQty > 0 ? Colors.deepOrange.shade900 : Colors.black87,
                                              ),
                                            ),
                                          ),
                                        ),
                                        IconButton(
                                          key: Key('btn_add_${dish.id}'),
                                          icon: const Icon(Icons.add_circle_outline, size: 30, color: Colors.green),
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
                          backgroundColor: isEditing ? Colors.blue : Colors.green,
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
                        ),
                        icon: Icon(isEditing ? Icons.save : Icons.check),
                        label: _isSubmitting
                            ? const CircularProgressIndicator(color: Colors.white)
                            : Text(isEditing ? 'ACTUALIZAR PEDIDO' : 'GUARDAR PEDIDO', style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
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
