import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/network/dio_client.dart';
import '../../../core/sync/sync_engine.dart';
import '../data/expenses_repository.dart';
import '../domain/expense_category_model.dart';
import '../domain/expense_model.dart';

final expensesRepositoryProvider = Provider<ExpensesRepository>((ref) {
  final db = ref.watch(databaseProvider);
  final queueManager = ref.watch(syncQueueManagerProvider);
  final syncEngine = ref.watch(syncEngineProvider);
  final dio = ref.watch(dioProvider);
  final networkInfo = ref.watch(networkInfoProvider);

  final repository = ExpensesRepository(
    db: db,
    queueManager: queueManager,
    syncEngine: syncEngine,
    dio: dio,
    networkInfo: networkInfo,
  );

  // Hidratar categorías iniciales en background
  repository.fetchAndCacheCategories();

  return repository;
});

final expenseCategoriesStreamProvider = StreamProvider<List<ExpenseCategoryModel>>((ref) {
  final repository = ref.watch(expensesRepositoryProvider);
  return repository.watchCategories();
});

final allExpenseCategoriesStreamProvider = StreamProvider<List<ExpenseCategoryModel>>((ref) {
  final repository = ref.watch(expensesRepositoryProvider);
  return repository.watchAllCategories();
});

final expensesFilterCategoryProvider = StateProvider<String?>((ref) => null);
final expensesFilterPaymentProvider = StateProvider<String?>((ref) => null);
final expensesFilterDateProvider = StateProvider<String?>((ref) => null);
final expensesFilterDateFromProvider = StateProvider<String?>((ref) => null);
final expensesFilterDateToProvider = StateProvider<String?>((ref) => null);

final expensesStreamProvider = StreamProvider<List<ExpenseModel>>((ref) {
  final repository = ref.watch(expensesRepositoryProvider);
  final categoryId = ref.watch(expensesFilterCategoryProvider);
  final paymentMethod = ref.watch(expensesFilterPaymentProvider);
  final date = ref.watch(expensesFilterDateProvider);
  final dateFrom = ref.watch(expensesFilterDateFromProvider);
  final dateTo = ref.watch(expensesFilterDateToProvider);

  return repository.watchExpenses(
    categoryId: categoryId,
    paymentMethod: paymentMethod,
    date: date,
    dateFrom: dateFrom,
    dateTo: dateTo,
    limit: 100,
  );
});
