import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/utils/currency_formatter.dart';
import '../application/dishes_notifier.dart';
import 'dish_detail_dialog.dart';

class DishesScreen extends ConsumerWidget {
  const DishesScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final dishesAsync = ref.watch(dishesStreamProvider);
    final searchQuery = ref.watch(dishesQueryProvider);
    final activeOnly = ref.watch(activeDishesOnlyProvider);
    final repository = ref.read(dishesRepositoryProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Catálogo de Platos', style: TextStyle(fontWeight: FontWeight.bold)),
      ),
      floatingActionButton: FloatingActionButton.extended(
        key: const Key('addDishFab'),
        backgroundColor: Colors.deepOrange,
        icon: const Icon(Icons.add, color: Colors.white),
        label: const Text('NUEVO PLATO', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
        onPressed: () {
          showDialog(
            context: context,
            builder: (ctx) => DishDetailDialog(
              onSave: (name, desc, price, img) async {
                await repository.createDish(
                  name: name,
                  description: desc,
                  price: price,
                  imageUrl: img,
                );
              },
            ),
          );
        },
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          children: [
            TextField(
              decoration: const InputDecoration(
                hintText: 'Buscar plato por nombre...',
                prefixIcon: Icon(Icons.search),
                border: OutlineInputBorder(),
              ),
              onChanged: (val) {
                ref.read(dishesQueryProvider.notifier).state = val;
              },
            ),
            const SizedBox(height: 12),
            SwitchListTile(
              title: const Text('Solo Platos Activos'),
              value: activeOnly,
              onChanged: (val) {
                ref.read(activeDishesOnlyProvider.notifier).state = val;
              },
            ),
            const SizedBox(height: 12),
            Expanded(
              child: dishesAsync.when(
                skipLoadingOnReload: true,
                skipLoadingOnRefresh: true,
                data: (dishes) {
                  if (dishes.isEmpty) {
                    return Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          const Icon(Icons.restaurant, size: 64, color: Colors.grey),
                          const SizedBox(height: 12),
                          Text(
                            searchQuery.isNotEmpty
                                ? 'No se encontraron platos que coincidan con "$searchQuery"'
                                : 'No hay platos en el catálogo local.',
                            style: const TextStyle(color: Colors.grey),
                          ),
                        ],
                      ),
                    );
                  }
                  return ListView.builder(
                    itemCount: dishes.length,
                    itemBuilder: (context, index) {
                      final dish = dishes[index];
                      final isSynced = dish.syncStatus == 'SYNCED';

                      return Card(
                        elevation: 2,
                        margin: const EdgeInsets.only(bottom: 10),
                        child: ListTile(
                          onTap: () {
                            showDialog(
                              context: context,
                              builder: (ctx) => DishDetailDialog(
                                dish: dish,
                                onSave: (name, desc, price, img) async {
                                  await repository.updateDish(
                                    id: dish.id,
                                    name: name,
                                    description: desc,
                                    price: price,
                                    imageUrl: img,
                                  );
                                },
                              ),
                            );
                          },
                          leading: CircleAvatar(
                            backgroundColor: dish.active ? Colors.deepOrange.shade100 : Colors.grey.shade300,
                            child: Icon(
                              dish.active ? Icons.restaurant : Icons.block,
                              color: dish.active ? Colors.deepOrange : Colors.grey,
                            ),
                          ),
                          title: Row(
                            children: [
                              Expanded(
                                child: Text(
                                  dish.name,
                                  style: TextStyle(
                                    fontWeight: FontWeight.bold,
                                    decoration: dish.active ? null : TextDecoration.lineThrough,
                                  ),
                                ),
                              ),
                              Icon(
                                isSynced ? Icons.cloud_done : Icons.cloud_upload,
                                size: 16,
                                color: isSynced ? Colors.green : Colors.orange,
                              ),
                            ],
                          ),
                          subtitle: Text(dish.description ?? 'Sin descripción'),
                          trailing: Text(
                            CurrencyFormatter.formatBOB(dish.price),
                            style: const TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                              color: Colors.deepOrange,
                            ),
                          ),
                        ),
                      );
                    },
                  );
                },
                loading: () => const Center(child: CircularProgressIndicator()),
                error: (err, _) => Center(child: Text('Error: $err')),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
