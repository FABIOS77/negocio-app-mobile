import 'package:flutter/material.dart';

class QuickActionsWidget extends StatelessWidget {
  final VoidCallback onNewOrder;
  final VoidCallback onDailyMenu;
  final VoidCallback onNewExpense;
  final VoidCallback onProduction;
  final VoidCallback onDishes;

  const QuickActionsWidget({
    super.key,
    required this.onNewOrder,
    required this.onDailyMenu,
    required this.onNewExpense,
    required this.onProduction,
    required this.onDishes,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text('Accesos Rápidos Cocina', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
        const SizedBox(height: 10),
        Row(
          children: [
            Expanded(
              child: _buildActionButton(
                label: 'Nuevo Pedido',
                icon: Icons.add_shopping_cart,
                color: Colors.green,
                onTap: onNewOrder,
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: _buildActionButton(
                label: 'Menú del Día',
                icon: Icons.restaurant_menu,
                color: Colors.deepOrange,
                onTap: onDailyMenu,
              ),
            ),
          ],
        ),
        const SizedBox(height: 8),
        Row(
          children: [
            Expanded(
              child: _buildActionButton(
                label: 'Catálogo Platos',
                icon: Icons.fastfood,
                color: Colors.teal,
                onTap: onDishes,
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: _buildActionButton(
                label: 'Registrar Gasto',
                icon: Icons.money_off,
                color: Colors.red,
                onTap: onNewExpense,
              ),
            ),
          ],
        ),
        const SizedBox(height: 8),
        Row(
          children: [
            Expanded(
              child: _buildActionButton(
                label: 'Ver Producción',
                icon: Icons.soup_kitchen,
                color: Colors.purple,
                onTap: onProduction,
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildActionButton({
    required String label,
    required IconData icon,
    required Color color,
    required VoidCallback onTap,
  }) {
    return ElevatedButton.icon(
      style: ElevatedButton.styleFrom(
        backgroundColor: color,
        foregroundColor: Colors.white,
        padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 8),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
      ),
      icon: Icon(icon, size: 20),
      label: Text(label, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
      onPressed: onTap,
    );
  }
}
