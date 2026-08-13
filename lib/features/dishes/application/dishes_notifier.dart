import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/sync/sync_engine.dart';
import '../data/dishes_repository.dart';
import '../domain/dish_model.dart';

final dishesRepositoryProvider = Provider<DishesRepository>((ref) {
  final db = ref.watch(databaseProvider);
  final queueManager = ref.watch(syncQueueManagerProvider);
  final syncEngine = ref.watch(syncEngineProvider);
  return DishesRepository(db: db, queueManager: queueManager, syncEngine: syncEngine);
});

final dishesQueryProvider = StateProvider<String>((ref) => '');
final activeDishesOnlyProvider = StateProvider<bool>((ref) => true);

final dishesStreamProvider = StreamProvider<List<DishModel>>((ref) {
  final repository = ref.watch(dishesRepositoryProvider);
  final searchQuery = ref.watch(dishesQueryProvider);
  final activeOnly = ref.watch(activeDishesOnlyProvider);

  return repository.watchDishes(
    activeOnly: activeOnly,
    searchQuery: searchQuery,
    limit: 50,
  );
});
