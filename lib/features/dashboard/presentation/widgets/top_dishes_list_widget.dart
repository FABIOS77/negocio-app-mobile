import 'package:flutter/material.dart';
import '../../../../core/utils/currency_formatter.dart';
import '../../domain/top_dish_model.dart';

class TopDishesListWidget extends StatelessWidget {
  final List<TopDishModel> topDishes;

  const TopDishesListWidget({super.key, required this.topDishes});

  @override
  Widget build(BuildContext context) {
    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: const [
                Icon(Icons.star, color: Colors.amber, size: 24),
                SizedBox(width: 8),
                Text(
                  'Top 5 Platos Más Vendidos',
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                ),
              ],
            ),
            const SizedBox(height: 12),
            if (topDishes.isEmpty)
              const Padding(
                padding: EdgeInsets.symmetric(vertical: 12.0),
                child: Center(
                  child: Text(
                    'No hay registros de ventas de platos para el período seleccionado.',
                    style: TextStyle(color: Colors.grey, fontSize: 13),
                  ),
                ),
              )
            else
              ListView.separated(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                itemCount: topDishes.length,
                separatorBuilder: (ctx, idx) => const Divider(height: 1),
                itemBuilder: (ctx, idx) {
                  final item = topDishes[idx];
                  return Padding(
                    padding: const EdgeInsets.symmetric(vertical: 8.0),
                    child: Row(
                      children: [
                        CircleAvatar(
                          radius: 14,
                          backgroundColor: Colors.deepOrange.shade100,
                          child: Text(
                            '#${idx + 1}',
                            style: const TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.bold,
                              color: Colors.deepOrange,
                            ),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Text(
                            item.dishName,
                            style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 15),
                          ),
                        ),
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.end,
                          children: [
                            Text(
                              '${item.totalQuantity} porciones',
                              style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
                            ),
                            Text(
                              CurrencyFormatter.formatBOB(item.totalRevenue),
                              style: const TextStyle(fontSize: 12, color: Colors.deepOrange, fontWeight: FontWeight.bold),
                            ),
                          ],
                        ),
                      ],
                    ),
                  );
                },
              ),
          ],
        ),
      ),
    );
  }
}
