import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/utils/currency_formatter.dart';
import '../../../core/utils/timezone_utils.dart';
import '../../dishes/application/dishes_notifier.dart';
import '../application/daily_menu_notifier.dart';
import 'create_menu_dialog.dart';

class DailyMenuScreen extends ConsumerWidget {
  const DailyMenuScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final todayMenuAsync = ref.watch(todayMenuStreamProvider);
    final dishesAsync = ref.watch(dishesStreamProvider);
    final repository = ref.read(dailyMenuRepositoryProvider);
    final todayDate = TimezoneUtils.getTodayBusinessDate();

    return Scaffold(
      appBar: AppBar(
        title: const Text('Menú del Día', style: TextStyle(fontWeight: FontWeight.bold)),
      ),
      floatingActionButton: FloatingActionButton.extended(
        backgroundColor: Colors.deepOrange,
        icon: const Icon(Icons.add, color: Colors.white),
        label: const Text('CONFIGURAR MENÚ', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
        onPressed: () {
          final dishes = dishesAsync.asData?.value ?? [];
          showDialog(
            context: context,
            builder: (ctx) => CreateMenuDialog(
              initialDate: todayDate,
              availableDishes: dishes,
              onRandomDraw: () async {
                final drawn = repository.drawRandomDishes(dishes);
                if (drawn.isNotEmpty) {
                  await repository.createDailyMenu(
                    menuDate: todayDate,
                    dishIds: drawn.map((d) => d.id).toList(),
                  );
                }
              },
              onSave: (menuDate, dishIds) async {
                final existing = todayMenuAsync.asData?.value;
                if (existing != null) {
                  await repository.updateDailyMenu(
                    id: existing.id,
                    menuDate: menuDate,
                    dishIds: dishIds,
                    currentVersion: existing.version,
                  );
                } else {
                  await repository.createDailyMenu(
                    menuDate: menuDate,
                    dishIds: dishIds,
                  );
                }
              },
            ),
          );
        },
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Card(
              color: Colors.deepOrange.shade50,
              elevation: 0,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              child: Padding(
                padding: const EdgeInsets.all(16.0),
                child: Row(
                  children: [
                    const Icon(Icons.calendar_today, color: Colors.deepOrange, size: 36),
                    const SizedBox(width: 12),
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text('Fecha de Negocio (America/La_Paz):', style: TextStyle(fontSize: 12, color: Colors.grey)),
                        Text(todayDate, style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: Colors.deepOrange)),
                      ],
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 16),
            const Text('Platos Disponibles Hoy:', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
            const SizedBox(height: 12),
            Expanded(
              child: todayMenuAsync.when(
                data: (menu) {
                  if (menu == null || menu.dishes.isEmpty) {
                    return const Center(
                      child: Text(
                        'No hay un menú configurado para hoy.\n¡Toca + CONFIGURAR MENÚ para crear uno offline!',
                        textAlign: TextAlign.center,
                        style: TextStyle(color: Colors.grey),
                      ),
                    );
                  }
                  return ListView.builder(
                    itemCount: menu.dishes.length,
                    itemBuilder: (context, index) {
                      final dish = menu.dishes[index];
                      return Card(
                        elevation: 2,
                        margin: const EdgeInsets.only(bottom: 10),
                        child: ListTile(
                          leading: const CircleAvatar(
                            backgroundColor: Colors.deepOrange,
                            child: Icon(Icons.restaurant, color: Colors.white),
                          ),
                          title: Text(dish.name, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                          subtitle: Text(dish.description ?? 'Plato del día', maxLines: 1, overflow: TextOverflow.ellipsis),
                          trailing: Text(
                            CurrencyFormatter.formatBOB(dish.price),
                            style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.deepOrange),
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
