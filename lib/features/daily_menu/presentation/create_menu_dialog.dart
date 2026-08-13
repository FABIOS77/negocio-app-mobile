import 'package:flutter/material.dart';
import '../../dishes/domain/dish_model.dart';

class CreateMenuDialog extends StatefulWidget {
  final String initialDate;
  final List<DishModel> availableDishes;
  final Function(String menuDate, List<String> dishIds) onSave;
  final VoidCallback? onRandomDraw;

  const CreateMenuDialog({
    super.key,
    required this.initialDate,
    required this.availableDishes,
    required this.onSave,
    this.onRandomDraw,
  });

  @override
  State<CreateMenuDialog> createState() => _CreateMenuDialogState();
}

class _CreateMenuDialogState extends State<CreateMenuDialog> {
  late TextEditingController _dateController;
  final Set<String> _selectedDishIds = {};

  @override
  void initState() {
    super.initState();
    _dateController = TextEditingController(text: widget.initialDate);
  }

  @override
  void dispose() {
    _dateController.dispose();
    super.dispose();
  }

  void _submit() {
    final date = _dateController.text.trim();
    if (date.isEmpty || _selectedDishIds.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Seleccione la fecha y al menos un plato')),
      );
      return;
    }
    widget.onSave(date, _selectedDishIds.toList());
    Navigator.pop(context);
  }

  @override
  Widget build(BuildContext context) {
    final activeDishes = widget.availableDishes.where((d) => d.active).toList();

    return AlertDialog(
      title: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          const Text('Menú Diario Offline'),
          if (widget.onRandomDraw != null)
            IconButton(
              icon: const Icon(Icons.shuffle, color: Colors.deepOrange),
              tooltip: 'Sorteo Aleatorio de Platos',
              onPressed: () {
                widget.onRandomDraw!();
                Navigator.pop(context);
              },
            ),
        ],
      ),
      content: SizedBox(
        width: double.maxFinite,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              TextField(
                controller: _dateController,
                decoration: const InputDecoration(
                  labelText: 'Fecha de Negocio (YYYY-MM-DD)',
                  border: OutlineInputBorder(),
                  prefixIcon: Icon(Icons.calendar_today),
                ),
              ),
              const SizedBox(height: 16),
              const Text('Seleccionar Platos para el Menú:', style: TextStyle(fontWeight: FontWeight.bold)),
              const SizedBox(height: 8),
              if (activeDishes.isEmpty)
                const Text('No hay platos activos guardados en SQLite.', style: TextStyle(color: Colors.grey))
              else
                ...activeDishes.map((dish) {
                  final isSelected = _selectedDishIds.contains(dish.id);
                  return CheckboxListTile(
                    title: Text(dish.name, style: const TextStyle(fontWeight: FontWeight.bold)),
                    subtitle: Text('Bs ${dish.price.toStringAsFixed(2)}'),
                    value: isSelected,
                    onChanged: (val) {
                      setState(() {
                        if (val ?? false) {
                          _selectedDishIds.add(dish.id);
                        } else {
                          _selectedDishIds.remove(dish.id);
                        }
                      });
                    },
                  );
                }),
            ],
          ),
        ),
      ),
      actions: [
        TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancelar')),
        ElevatedButton(
          style: ElevatedButton.styleFrom(backgroundColor: Colors.deepOrange, foregroundColor: Colors.white),
          onPressed: _submit,
          child: const Text('GUARDAR MENÚ'),
        ),
      ],
    );
  }
}
