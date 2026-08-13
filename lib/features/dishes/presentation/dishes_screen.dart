import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../application/dishes_notifier.dart';
import 'dish_detail_dialog.dart';
import 'widgets/dish_search_bar.dart';
import 'widgets/dish_tile.dart';

class DishesScreen extends ConsumerWidget {
  const DishesScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final dishesAsync = ref.watch(dishesStreamProvider);
    final activeOnly = ref.watch(activeDishesOnlyProvider);
    final repository = ref.read(dishesRepositoryProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Catálogo de Platos', style: TextStyle(fontWeight: FontWeight.bold)),
      ),
      floatingActionButton: FloatingActionButton.extended(
        backgroundColor: Colors.deepOrange,
        icon: const Icon(Icons.add, color: Colors.white),
        label: const Text('NUEVO PLATO', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
        onPressed: () {
          showDialog(
            context: context,
            builder: (ctx) => DishDetailDialog(
              onSave: (name, description, price, imageUrl) async {
                await repository.createDish(
                  name: name,
                  description: description,
                  price: price,
                  imageUrl: imageUrl,
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
            DishSearchBar(
              onChanged: (val) {
                ref.read(dishesQueryProvider.notifier).state = val;
              },
              activeOnly: activeOnly,
              onActiveOnlyChanged: (val) {
                ref.read(activeDishesOnlyProvider.notifier).state = val ?? true;
              },
            ),
            const SizedBox(height: 12),
            Expanded(
              child: dishesAsync.when(
                data: (dishes) {
                  if (dishes.isEmpty) {
                    return const Center(
                      child: Text(
                        'No hay platos registrados.\n¡Toca + NUEVO PLATO para agregar uno offline!',
                        textAlign: TextAlign.center,
                        style: TextStyle(color: Colors.grey),
                      ),
                    );
                  }
                  return ListView.builder(
                    itemCount: dishes.length,
                    itemBuilder: (context, index) {
                      final dish = dishes[index];
                      return DishTile(
                        dish: dish,
                        onTap: () {
                          showDialog(
                            context: context,
                            builder: (ctx) => DishDetailDialog(
                              dish: dish,
                              onSave: (name, description, price, imageUrl) async {
                                await repository.updateDish(
                                  id: dish.id,
                                  name: name,
                                  description: description,
                                  price: price,
                                  imageUrl: imageUrl,
                                );
                              },
                            ),
                          );
                        },
                        onDelete: () async {
                          final confirm = await showDialog<bool>(
                            context: context,
                            builder: (ctx) => AlertDialog(
                              title: const Text('Inactivar Plato'),
                              content: Text('¿Desea inactivar el plato "${dish.name}"?'),
                              actions: [
                                TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancelar')),
                                ElevatedButton(
                                  style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
                                  onPressed: () => Navigator.pop(ctx, true),
                                  child: const Text('INACTIVAR'),
                                ),
                              ],
                            ),
                          );
                          if (confirm ?? false) {
                            await repository.deleteDish(dish.id);
                          }
                        },
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
