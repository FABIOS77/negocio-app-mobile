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
  late final TextEditingController _dateController;
  final Set<String> _selectedDishIds = {};

  @override
  void initState() {
    super.initState();
    _dateController = TextEditingController(text: widget.initialDate);
    if (widget.initialSelectedDishIds != null) {
      _selectedDishIds.addAll(widget.initialSelectedDishIds!);
    }
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
              _DishSelector(
                availableDishes: widget.availableDishes,
                selectedDishIds: _selectedDishIds,
              ),
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

class _DishSelector extends StatefulWidget {
  final List<DishModel> availableDishes;
  final Set<String> selectedDishIds;

  const _DishSelector({
    required this.availableDishes,
    required this.selectedDishIds,
  });

  @override
  State<_DishSelector> createState() => _DishSelectorState();
}

class _DishSelectorState extends State<_DishSelector> {
  late final TextEditingController _searchController;

  @override
  void initState() {
    super.initState();
    _searchController = TextEditingController();
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final activeDishes = widget.availableDishes.where((d) => d.active).toList();

    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // 1. Campo de Búsqueda con ValueListenableBuilder para reflejar suffixIcon sin rebuilds externos
        ValueListenableBuilder<TextEditingValue>(
          valueListenable: _searchController,
          builder: (context, value, _) {
            final hasText = value.text.isNotEmpty;
            return TextField(
              controller: _searchController,
              keyboardType: TextInputType.text,
              textCapitalization: TextCapitalization.none,
              autocorrect: false,
              enableSuggestions: false,
              decoration: InputDecoration(
                labelText: 'Buscar plato...',
                hintText: 'Ej. Sopa, Pique...',
                prefixIcon: const Icon(Icons.search),
                suffixIcon: hasText
                    ? IconButton(
                        icon: const Icon(Icons.clear),
                        onPressed: () {
                          _searchController.clear();
                        },
                      )
                    : null,
                border: const OutlineInputBorder(),
                contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
              ),
            );
          },
        ),
        const SizedBox(height: 12),

        // 2. Cabecera y Contador de Seleccionados Global
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            const Text('Seleccionar Platos:', style: TextStyle(fontWeight: FontWeight.bold)),
            Text(
              '${widget.selectedDishIds.length} seleccionados',
              style: const TextStyle(fontSize: 12, color: Colors.deepOrange, fontWeight: FontWeight.bold),
            ),
          ],
        ),
        const SizedBox(height: 8),

        // 3. Lista de Platos Filtrados reactiva a _searchController
        if (activeDishes.isEmpty)
          const Text('No hay platos activos guardados en SQLite.', style: TextStyle(color: Colors.grey))
        else
          ValueListenableBuilder<TextEditingValue>(
            valueListenable: _searchController,
            builder: (context, textValue, _) {
              final query = textValue.text.trim().toLowerCase();
              final filteredDishes = activeDishes.where((dish) {
                if (query.isEmpty) return true;
                return dish.name.toLowerCase().contains(query);
              }).toList();

              if (filteredDishes.isEmpty) {
                return const Padding(
                  padding: EdgeInsets.symmetric(vertical: 16.0),
                  child: Center(
                    child: Text('No se encontraron platos con esa búsqueda', style: TextStyle(color: Colors.grey)),
                  ),
                );
              }

              return ListView.builder(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                itemCount: filteredDishes.length,
                itemBuilder: (context, index) {
                  final dish = filteredDishes[index];
                  final isSelected = widget.selectedDishIds.contains(dish.id);

                  return CheckboxListTile(
                    title: Text(dish.name, style: const TextStyle(fontWeight: FontWeight.bold)),
                    subtitle: Text('Bs ${dish.price.toStringAsFixed(2)}'),
                    value: isSelected,
                    onChanged: (val) {
                      setState(() {
                        if (val ?? false) {
                          widget.selectedDishIds.add(dish.id);
                        } else {
                          widget.selectedDishIds.remove(dish.id);
                        }
                      });
                    },
                  );
                },
              );
            },
          ),
      ],
    );
  }
}
