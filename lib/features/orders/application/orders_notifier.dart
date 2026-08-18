import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/sync/sync_engine.dart';
import '../data/orders_repository.dart';
import '../domain/order_model.dart';
import '../domain/order_summary_model.dart';

final ordersRepositoryProvider = Provider<OrdersRepository>((ref) {
  final db = ref.watch(databaseProvider);
  final queueManager = ref.watch(syncQueueManagerProvider);
  final syncEngine = ref.watch(syncEngineProvider);
  return OrdersRepository(db: db, queueManager: queueManager, syncEngine: syncEngine);
});

final todayOrdersStreamProvider = StreamProvider<List<OrderSummaryModel>>((ref) {
  final repository = ref.watch(ordersRepositoryProvider);
  return repository.watchTodayOrders();
});

final orderHistoryStatusFilterProvider = StateProvider<String?>((ref) => null);
final orderHistorySearchQueryProvider = StateProvider<String>((ref) => '');
final orderHistoryDateFilterProvider = StateProvider<String?>((ref) => null);
final orderHistoryDateFromProvider = StateProvider<String?>((ref) => null);
final orderHistoryDateToProvider = StateProvider<String?>((ref) => null);
final orderHistoryLimitProvider = StateProvider<int>((ref) => 50);
final orderHistoryOffsetProvider = StateProvider<int>((ref) => 0);

final historyOrdersStreamProvider = StreamProvider<List<OrderSummaryModel>>((ref) {
  final repository = ref.watch(ordersRepositoryProvider);
  final status = ref.watch(orderHistoryStatusFilterProvider);
  final searchQuery = ref.watch(orderHistorySearchQueryProvider);
  final date = ref.watch(orderHistoryDateFilterProvider);
  final dateFrom = ref.watch(orderHistoryDateFromProvider);
  final dateTo = ref.watch(orderHistoryDateToProvider);
  final limit = ref.watch(orderHistoryLimitProvider);
  final offset = ref.watch(orderHistoryOffsetProvider);

  return repository.watchOrders(
    status: status,
    searchQuery: searchQuery,
    date: date,
    dateFrom: dateFrom,
    dateTo: dateTo,
    limit: limit,
    offset: offset,
  );
});

final orderDetailFutureProvider = FutureProvider.autoDispose.family<OrderModel?, String>((ref, id) {
  return ref.watch(ordersRepositoryProvider).getOrderById(id);
});
