import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/sync/sync_engine.dart';
import '../data/orders_repository.dart';
import '../domain/order_model.dart';

final ordersRepositoryProvider = Provider<OrdersRepository>((ref) {
  final db = ref.watch(databaseProvider);
  final queueManager = ref.watch(syncQueueManagerProvider);
  final syncEngine = ref.watch(syncEngineProvider);
  return OrdersRepository(db: db, queueManager: queueManager, syncEngine: syncEngine);
});

final todayOrdersStreamProvider = StreamProvider<List<OrderModel>>((ref) {
  final repository = ref.watch(ordersRepositoryProvider);
  return repository.watchTodayOrders();
});

final orderHistoryStatusFilterProvider = StateProvider<String?>((ref) => null);
final orderHistoryDateFilterProvider = StateProvider<String?>((ref) => null);

final historyOrdersStreamProvider = StreamProvider<List<OrderModel>>((ref) {
  final repository = ref.watch(ordersRepositoryProvider);
  final status = ref.watch(orderHistoryStatusFilterProvider);
  final date = ref.watch(orderHistoryDateFilterProvider);

  return repository.watchOrders(
    status: status,
    date: date,
    limit: 50,
  );
});
