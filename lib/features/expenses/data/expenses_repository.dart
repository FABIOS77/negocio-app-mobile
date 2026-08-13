import 'package:drift/drift.dart';
import 'package:uuid/uuid.dart';
import '../../../core/database/app_database.dart';
import '../../../core/sync/sync_engine.dart';
import '../../../core/sync/sync_queue_manager.dart';
import '../../../core/utils/timezone_utils.dart';
import '../domain/expense_category_model.dart';
import '../domain/expense_model.dart';

class ExpensesRepository {
  final AppDatabase _db;
  final SyncQueueManager _queueManager;
  final SyncEngine _syncEngine;
  final Uuid _uuid;

  ExpensesRepository({
    required AppDatabase db,
    required SyncQueueManager queueManager,
    required SyncEngine syncEngine,
    Uuid? uuid,
  })  : _db = db,
        _queueManager = queueManager,
        _syncEngine = syncEngine,
        _uuid = uuid ?? const Uuid();

  /// Observa las categorías de gastos activas
  Stream<List<ExpenseCategoryModel>> watchCategories() {
    final query = _db.select(_db.expenseCategoriesTable)..where((t) => t.active.equals(true));
    return query.watch().map((rows) {
      return rows.map((r) {
        return ExpenseCategoryModel(
          id: r.id,
          name: r.name,
          active: r.active,
          version: r.version,
          createdAt: r.createdAt,
          updatedAt: r.updatedAt,
        );
      }).toList();
    });
  }

  /// Observa la lista de gastos filtrada y paginada desde SQLite (excluyendo eliminados)
  Stream<List<ExpenseModel>> watchExpenses({
    String? date,
    String? categoryId,
    String? paymentMethod,
    int limit = 20,
    int offset = 0,
  }) {
    final query = _db.select(_db.expensesTable).join([
      leftOuterJoin(
        _db.expenseCategoriesTable,
        _db.expenseCategoriesTable.id.equalsExp(_db.expensesTable.categoryId),
      ),
    ])..where(_db.expensesTable.deletedAt.isNull());

    if (date != null && date.isNotEmpty) {
      query.where(_db.expensesTable.expenseDate.equals(date));
    }

    if (categoryId != null && categoryId.isNotEmpty) {
      query.where(_db.expensesTable.categoryId.equals(categoryId));
    }

    if (paymentMethod != null && paymentMethod.isNotEmpty) {
      query.where(_db.expensesTable.paymentMethod.equals(paymentMethod));
    }

    query.orderBy([
      OrderingTerm(expression: _db.expensesTable.expenseDate, mode: OrderingMode.desc),
      OrderingTerm(expression: _db.expensesTable.createdAt, mode: OrderingMode.desc),
    ]);

    query.limit(limit, offset: offset);

    return query.watch().map((rows) {
      return rows.map((r) {
        final exp = r.readTable(_db.expensesTable);
        final cat = r.readTableOrNull(_db.expenseCategoriesTable);
        return ExpenseModel(
          id: exp.id,
          description: exp.description,
          amount: exp.amount,
          categoryId: exp.categoryId,
          categoryName: cat?.name,
          paymentMethod: exp.paymentMethod,
          expenseDate: exp.expenseDate,
          createdBy: exp.createdBy,
          version: exp.version,
          syncStatus: exp.syncStatus,
          deletedAt: exp.deletedAt,
          createdAt: exp.createdAt,
          updatedAt: exp.updatedAt,
        );
      }).toList();
    });
  }

  /// Obtiene un gasto por ID desde SQLite
  Future<ExpenseModel?> getExpenseById(String id) async {
    final row = await (_db.select(_db.expensesTable)..where((t) => t.id.equals(id))).getSingleOrNull();
    if (row == null) return null;

    final cat = await (_db.select(_db.expenseCategoriesTable)..where((t) => t.id.equals(row.categoryId))).getSingleOrNull();

    return ExpenseModel(
      id: row.id,
      description: row.description,
      amount: row.amount,
      categoryId: row.categoryId,
      categoryName: cat?.name,
      paymentMethod: row.paymentMethod,
      expenseDate: row.expenseDate,
      createdBy: row.createdBy,
      version: row.version,
      syncStatus: row.syncStatus,
      deletedAt: row.deletedAt,
      createdAt: row.createdAt,
      updatedAt: row.updatedAt,
    );
  }

  /// Crear gasto offline en SQLite + SyncQueue
  Future<ExpenseModel> createExpense({
    required String description,
    required double amount,
    required String categoryId,
    required String paymentMethod,
    String? expenseDate,
  }) async {
    final id = _uuid.v4();
    final now = DateTime.now().toUtc();
    final dateStr = expenseDate ?? TimezoneUtils.getTodayBusinessDate();

    if (description.trim().isEmpty) {
      throw ArgumentError('La descripción del gasto es obligatoria');
    }

    if (amount <= 0) {
      throw ArgumentError('El monto debe ser mayor a cero');
    }

    await _db.into(_db.expensesTable).insert(
          ExpensesTableCompanion.insert(
            id: id,
            description: description.trim(),
            amount: amount,
            categoryId: categoryId,
            paymentMethod: paymentMethod,
            expenseDate: dateStr,
            createdBy: 'local-user',
            version: const Value(1),
            syncStatus: const Value('PENDING'),
            createdAt: now,
            updatedAt: now,
          ),
        );

    final expense = ExpenseModel(
      id: id,
      description: description.trim(),
      amount: amount,
      categoryId: categoryId,
      paymentMethod: paymentMethod,
      expenseDate: dateStr,
      createdBy: 'local-user',
      version: 1,
      syncStatus: 'PENDING',
      createdAt: now,
      updatedAt: now,
    );

    await _queueManager.enqueueOperation(
      entityType: 'expense',
      entityId: id,
      operation: 'CREATE',
      payload: {
        'id': id,
        'description': expense.description,
        'amount': expense.amount,
        'category_id': expense.categoryId,
        'payment_method': expense.paymentMethod,
        'expense_date': expense.expenseDate,
      },
    );

    _syncEngine.syncAll();
    return expense;
  }

  /// Actualizar gasto offline
  Future<void> updateExpense({
    required String id,
    String? description,
    double? amount,
    String? categoryId,
    String? paymentMethod,
    String? expenseDate,
  }) async {
    final current = await getExpenseById(id);
    if (current == null) return;

    final now = DateTime.now().toUtc();
    final updatedVersion = current.version + 1;

    final updatedExpense = ExpenseModel(
      id: id,
      description: description?.trim() ?? current.description,
      amount: amount ?? current.amount,
      categoryId: categoryId ?? current.categoryId,
      paymentMethod: paymentMethod ?? current.paymentMethod,
      expenseDate: expenseDate ?? current.expenseDate,
      createdBy: current.createdBy,
      version: updatedVersion,
      syncStatus: 'PENDING',
      createdAt: current.createdAt,
      updatedAt: now,
    );

    await (_db.update(_db.expensesTable)..where((t) => t.id.equals(id))).write(
      ExpensesTableCompanion(
        description: Value(updatedExpense.description),
        amount: Value(updatedExpense.amount),
        categoryId: Value(updatedExpense.categoryId),
        paymentMethod: Value(updatedExpense.paymentMethod),
        expenseDate: Value(updatedExpense.expenseDate),
        version: Value(updatedVersion),
        syncStatus: const Value('PENDING'),
        updatedAt: Value(now),
      ),
    );

    await _queueManager.enqueueOperation(
      entityType: 'expense',
      entityId: id,
      operation: 'UPDATE',
      payload: {
        'description': updatedExpense.description,
        'amount': updatedExpense.amount,
        'category_id': updatedExpense.categoryId,
        'payment_method': updatedExpense.paymentMethod,
        'expense_date': updatedExpense.expenseDate,
      },
      baseVersion: current.version,
    );

    _syncEngine.syncAll();
  }

  /// Soft delete de gasto (deletedAt = now)
  Future<void> deleteExpense(String id) async {
    final current = await getExpenseById(id);
    if (current == null) return;

    final now = DateTime.now().toUtc();
    final updatedVersion = current.version + 1;

    await (_db.update(_db.expensesTable)..where((t) => t.id.equals(id))).write(
      ExpensesTableCompanion(
        deletedAt: Value(now),
        version: Value(updatedVersion),
        syncStatus: const Value('PENDING'),
        updatedAt: Value(now),
      ),
    );

    await _queueManager.enqueueOperation(
      entityType: 'expense',
      entityId: id,
      operation: 'DELETE',
      payload: {'id': id},
      baseVersion: current.version,
    );

    _syncEngine.syncAll();
  }
}
