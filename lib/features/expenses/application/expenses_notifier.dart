import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/sync/sync_engine.dart';
import '../data/expenses_repository.dart';
import '../domain/expense_category_model.dart';
import '../domain/expense_model.dart';

final expensesRepositoryProvider = Provider<ExpensesRepository>((ref) {
  final db = ref.watch(databaseProvider);
  final queueManager = ref.watch(syncQueueManagerProvider);
  final syncEngine = ref.watch(syncEngineProvider);
  return ExpensesRepository(db: db, queueManager: queueManager, syncEngine: syncEngine);
});

final expenseCategoriesStreamProvider = StreamProvider<List<ExpenseCategoryModel>>((ref) {
  final repository = ref.watch(expensesRepositoryProvider);
  return repository.watchCategories();
});

final expensesFilterCategoryProvider = StateProvider<String?>((ref) => null);
final expensesFilterPaymentProvider = StateProvider<String?>((ref) => null);
final expensesFilterDateProvider = StateProvider<String?>((ref) => null);

final expensesStreamProvider = StreamProvider<List<ExpenseModel>>((ref) {
  final repository = ref.watch(expensesRepositoryProvider);
  final categoryId = ref.watch(expensesFilterCategoryProvider);
  final paymentMethod = ref.watch(expensesFilterPaymentProvider);
  final date = ref.watch(expensesFilterDateProvider);

  return repository.watchExpenses(
    categoryId: categoryId,
    paymentMethod: paymentMethod,
    date: date,
    limit: 50,
  );
});
