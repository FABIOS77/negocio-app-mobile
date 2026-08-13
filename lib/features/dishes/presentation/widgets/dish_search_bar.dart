import 'package:flutter/material.dart';

class DishSearchBar extends StatelessWidget {
  final ValueChanged<String> onChanged;
  final bool activeOnly;
  final ValueChanged<bool?> onActiveOnlyChanged;

  const DishSearchBar({
    super.key,
    required this.onChanged,
    required this.activeOnly,
    required this.onActiveOnlyChanged,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        TextField(
          onChanged: onChanged,
          decoration: InputDecoration(
            hintText: 'Buscar plato por nombre...',
            prefixIcon: const Icon(Icons.search),
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
            contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          ),
        ),
        Row(
          children: [
            Checkbox(
              value: activeOnly,
              onChanged: onActiveOnlyChanged,
            ),
            const Text('Mostrar solo platos activos'),
          ],
        ),
      ],
    );
  }
}
