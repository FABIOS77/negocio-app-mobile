import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/utils/currency_formatter.dart';
import '../application/dishes_notifier.dart';
import '../data/dishes_repository.dart';
import 'dish_detail_dialog.dart';
import 'widgets/dish_image_avatar.dart';

class DishesScreen extends ConsumerStatefulWidget {
  const DishesScreen({super.key});

  @override
  ConsumerState<DishesScreen> createState() => _DishesScreenState();
}

class _DishesScreenState extends ConsumerState<DishesScreen> {
  late TextEditingController _searchController;

  @override
  void initState() {
    super.initState();
    final initialQuery = ref.read(dishesQueryProvider);
    _searchController = TextEditingController(text: initialQuery);
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
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
              controller: _searchController,
              decoration: InputDecoration(
                hintText: 'Buscar plato por nombre...',
                prefixIcon: const Icon(Icons.search),
                suffixIcon: searchQuery.isNotEmpty
                    ? IconButton(
                        icon: const Icon(Icons.clear),
                        onPressed: () {
                          _searchController.clear();
                          ref.read(dishesQueryProvider.notifier).state = '';
                        },
                      )
                    : null,
                border: const OutlineInputBorder(),
              ),
              onChanged: (val) {
                ref.read(dishesQueryProvider.notifier).state = val.trim();
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
                                    active: dish.active,
                                  );
                                },
                              ),
                            );
                          },
                          leading: DishImageAvatar(
                            dish: dish,
                            size: 50,
                          ),
                          title: Text(
                            dish.name,
                            style: TextStyle(
                              fontWeight: FontWeight.bold,
                              decoration: dish.active ? null : TextDecoration.lineThrough,
                              color: dish.active ? null : Colors.grey,
                            ),
                          ),
                          subtitle: Text(
                            '${CurrencyFormatter.formatBOB(dish.price)}${dish.description != null ? ' • ${dish.description}' : ''}\nSync: ${isSynced ? 'Sincronizado' : 'Pendiente'}',
                            style: const TextStyle(fontSize: 12),
                          ),
                          isThreeLine: true,
                          trailing: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Switch.adaptive(
                                value: dish.active,
                                activeThumbColor: Colors.green,
                                onChanged: (val) async {
                                  await repository.updateDish(
                                    id: dish.id,
                                    name: dish.name,
                                    description: dish.description,
                                    price: dish.price,
                                    imageUrl: dish.imageUrl,
                                    active: val,
                                  );
                                },
                              ),
                              IconButton(
                                icon: const Icon(Icons.delete_outline, color: Colors.redAccent),
                                onPressed: () => _confirmDelete(context, repository, dish.id, dish.name),
                              ),
                            ],
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

  void _confirmDelete(BuildContext context, DishesRepository repo, String id, String name) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Eliminar Plato'),
        content: Text('¿Estás seguro de eliminar el plato "$name"? Esta acción se sincronizará con el servidor.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancelar')),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red, foregroundColor: Colors.white),
            onPressed: () async {
              Navigator.pop(ctx);
              await repo.deleteDish(id);
            },
            child: const Text('ELIMINAR'),
          ),
        ],
      ),
    );
  }
}
