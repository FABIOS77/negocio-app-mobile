import 'package:flutter/material.dart';
import '../../dishes/domain/dish_model.dart';

class CreateMenuDialog extends StatefulWidget {
  final String initialDate;
  final List<DishModel> availableDishes;
  final List<String>? initialSelectedDishIds;
  final Function(String menuDate, List<String> dishIds) onSave;
  final VoidCallback? onRandomDraw;

  const CreateMenuDialog({
    super.key,
    required this.initialDate,
    required this.availableDishes,
    this.initialSelectedDishIds,
    required this.onSave,
    this.onRandomDraw,
  });

  @override
  State<CreateMenuDialog> createState() => _CreateMenuDialogState();
}

class _CreateMenuDialogState extends State<CreateMenuDialog> {
  late TextEditingController _dateController;
  late TextEditingController _searchController;
  final Set<String> _selectedDishIds = {};
  String _searchQuery = '';

  @override
  void initState() {
    super.initState();
    _dateController = TextEditingController(text: widget.initialDate);
    _searchController = TextEditingController();
    if (widget.initialSelectedDishIds != null) {
      _selectedDishIds.addAll(widget.initialSelectedDishIds!);
    }
  }

  @override
  void dispose() {
    _dateController.dispose();
    _searchController.dispose();
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
    final filteredDishes = activeDishes.where((dish) {
      if (_searchQuery.isEmpty) return true;
      return dish.name.toLowerCase().contains(_searchQuery);
    }).toList();

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
              const SizedBox(height: 12),
              TextField(
                controller: _searchController,
                decoration: InputDecoration(
                  labelText: 'Buscar plato...',
                  hintText: 'Ej. Sopa, Pique...',
                  prefixIcon: const Icon(Icons.search),
                  suffixIcon: _searchQuery.isNotEmpty
                      ? IconButton(
                          icon: const Icon(Icons.clear),
                          onPressed: () {
                            setState(() {
                              _searchController.clear();
                              _searchQuery = '';
                            });
                          },
                        )
                      : null,
                  border: const OutlineInputBorder(),
                  contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                ),
                onChanged: (val) {
                  setState(() {
                    _searchQuery = val.trim().toLowerCase();
                  });
                },
              ),
              const SizedBox(height: 12),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text('Seleccionar Platos:', style: TextStyle(fontWeight: FontWeight.bold)),
                  Text(
                    '${_selectedDishIds.length} seleccionados',
                    style: const TextStyle(fontSize: 12, color: Colors.deepOrange, fontWeight: FontWeight.bold),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              if (activeDishes.isEmpty)
                const Text('No hay platos activos guardados en SQLite.', style: TextStyle(color: Colors.grey))
              else if (filteredDishes.isEmpty)
                const Padding(
                  padding: EdgeInsets.symmetric(vertical: 16.0),
                  child: Center(
                    child: Text('No se encontraron platos con esa búsqueda', style: TextStyle(color: Colors.grey)),
                  ),
                )
              else
                ...filteredDishes.map((dish) {
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
