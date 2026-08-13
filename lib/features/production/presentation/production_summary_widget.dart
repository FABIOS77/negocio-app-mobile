import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../application/production_notifier.dart';

class ProductionSummaryWidget extends ConsumerWidget {
  const ProductionSummaryWidget({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final productionAsync = ref.watch(todayProductionStreamProvider);

    return Card(
      elevation: 3,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: const [
                Icon(Icons.soup_kitchen, color: Colors.deepOrange, size: 28),
                SizedBox(width: 8),
                Text(
                  'Resumen de Producción de Hoy',
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                ),
              ],
            ),
            const SizedBox(height: 12),
            productionAsync.when(
              data: (items) {
                if (items.isEmpty) {
                  return const Text(
                    'No hay platos pedidos aún para la producción de hoy.',
                    style: TextStyle(color: Colors.grey),
                  );
                }
                return ListView.separated(
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  itemCount: items.length,
                  separatorBuilder: (ctx, idx) => const Divider(height: 1),
                  itemBuilder: (ctx, idx) {
                    final item = items[idx];
                    return Padding(
                      padding: const EdgeInsets.symmetric(vertical: 8.0),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(
                            item.dishName,
                            style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
                          ),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                            decoration: BoxDecoration(
                              color: Colors.deepOrange.shade100,
                              borderRadius: BorderRadius.circular(16),
                            ),
                            child: Text(
                              '${item.totalQuantity} porciones',
                              style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.deepOrange),
                            ),
                          ),
                        ],
                      ),
                    );
                  },
                );
              },
              loading: () => const Center(child: CircularProgressIndicator()),
              error: (err, _) => Text('Error al cargar producción: $err'),
            ),
          ],
        ),
      ),
    );
  }
}
