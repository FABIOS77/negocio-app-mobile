import 'package:dio/dio.dart';
import 'package:drift/drift.dart';
import 'package:flutter/foundation.dart';
import 'package:uuid/uuid.dart';
import '../../../core/database/app_database.dart';
import '../../../core/network/network_info.dart';
import '../../../core/sync/sync_engine.dart';
import '../../../core/sync/sync_queue_manager.dart';
import '../../../core/utils/parse_utils.dart';
import '../../../core/utils/timezone_utils.dart';
import '../domain/expense_category_model.dart';
import '../domain/expense_model.dart';

class ExpensesRepository {
  final AppDatabase _db;
  final SyncQueueManager _queueManager;
  final SyncEngine _syncEngine;
  final Dio? _dio;
  final NetworkInfo? _networkInfo;
  final Uuid _uuid;

  ExpensesRepository({
    required AppDatabase db,
    required SyncQueueManager queueManager,
    required SyncEngine syncEngine,
    Dio? dio,
    NetworkInfo? networkInfo,
    Uuid? uuid,
  })  : _db = db,
        _queueManager = queueManager,
        _syncEngine = syncEngine,
        _dio = dio,
        _networkInfo = networkInfo,
        _uuid = uuid ?? const Uuid();

  // ─── EXPENSE CATEGORIES INITIAL SYNC & CRUD OFFLINE ──────────────────────────

  /// Sincroniza las categorías existentes desde el backend (GET /expenses/categories)
  /// e hidrata la base de datos local SQLite (ExpenseCategoriesTable) sin duplicar registros.
  Future<List<ExpenseCategoryModel>> fetchAndCacheCategories() async {
    if (_dio != null) {
      try {
        final isConnected = await _networkInfo?.isConnected ?? true;
        if (isConnected) {
          final response = await _dio.get('/expenses/categories');
          final data = response.data;
          final rawList = data is Map ? (data['data'] as List? ?? []) : (data as List? ?? []);

          final now = DateTime.now().toUtc();

          for (final item in rawList) {
            if (item is Map) {
              final id = item['id']?.toString() ?? '';
              final name = (item['name'] ?? '').toString().trim();
              final active = item['active'] != false;
              final version = ParseUtils.toInt(item['version'], 1);
              final createdAt = DateTime.tryParse(item['createdAt']?.toString() ?? item['created_at']?.toString() ?? '') ?? now;
              final updatedAt = DateTime.tryParse(item['updatedAt']?.toString() ?? item['updated_at']?.toString() ?? '') ?? now;

              if (id.isNotEmpty && name.isNotEmpty) {
                await _db.into(_db.expenseCategoriesTable).insertOnConflictUpdate(
                      ExpenseCategoriesTableCompanion.insert(
                        id: id,
                        name: name,
                        active: Value(active),
                        version: Value(version),
                        syncStatus: const Value('SYNCED'),
                        createdAt: createdAt,
                        updatedAt: updatedAt,
                      ),
                    );
              }
            }
          }
        }
      } catch (e) {
        debugPrint('[ExpensesRepository] fetchAndCacheCategories error (operating offline): $e');
      }
    }

    return getCategories();
  }

  /// Observa las categorías de gastos activas
  Stream<List<ExpenseCategoryModel>> watchCategories() {
    final query = _db.select(_db.expenseCategoriesTable)
      ..where((t) => t.active.equals(true))
      ..orderBy([(t) => OrderingTerm(expression: t.name, mode: OrderingMode.asc)]);

    return query.watch().map((rows) {
      return rows.map((r) => ExpenseCategoryModel(
            id: r.id,
            name: r.name,
            active: r.active,
            version: r.version,
            createdAt: r.createdAt,
            updatedAt: r.updatedAt,
          )).toList();
    });
  }

  /// Observa todas las categorías (activas e inactivas)
  Stream<List<ExpenseCategoryModel>> watchAllCategories() {
    final query = _db.select(_db.expenseCategoriesTable)
      ..orderBy([(t) => OrderingTerm(expression: t.name, mode: OrderingMode.asc)]);

    return query.watch().map((rows) {
      return rows.map((r) => ExpenseCategoryModel(
            id: r.id,
            name: r.name,
            active: r.active,
            version: r.version,
            createdAt: r.createdAt,
            updatedAt: r.updatedAt,
          )).toList();
    });
  }

  /// Obtiene una lista estática de categorías activas
  Future<List<ExpenseCategoryModel>> getCategories() async {
    final rows = await (_db.select(_db.expenseCategoriesTable)
          ..where((t) => t.active.equals(true))
          ..orderBy([(t) => OrderingTerm(expression: t.name, mode: OrderingMode.asc)]))
        .get();

    return rows
        .map((r) => ExpenseCategoryModel(
              id: r.id,
              name: r.name,
              active: r.active,
              version: r.version,
              createdAt: r.createdAt,
              updatedAt: r.updatedAt,
            ))
        .toList();
  }

  /// Obtiene una categoría por ID
  Future<ExpenseCategoryModel?> getCategoryById(String id) async {
    final row = await (_db.select(_db.expenseCategoriesTable)..where((t) => t.id.equals(id))).getSingleOrNull();
    if (row == null) return null;

    return ExpenseCategoryModel(
      id: row.id,
      name: row.name,
      active: row.active,
      version: row.version,
      createdAt: row.createdAt,
      updatedAt: row.updatedAt,
    );
  }

  /// Crear categoría de gasto offline (inserta en SQLite, encola en SyncQueue y dispara sync)
  Future<ExpenseCategoryModel> createCategory({
    required String name,
    bool active = true,
  }) async {
    final trimmedName = name.trim();
    if (trimmedName.isEmpty) {
      throw ArgumentError('El nombre de la categoría es obligatorio');
    }
    if (trimmedName.length > 100) {
      throw ArgumentError('El nombre de la categoría no puede superar los 100 caracteres');
    }

    final id = _uuid.v4();
    final now = DateTime.now().toUtc();

    await _db.into(_db.expenseCategoriesTable).insert(
          ExpenseCategoriesTableCompanion.insert(
            id: id,
            name: trimmedName,
            active: Value(active),
            version: const Value(1),
            syncStatus: const Value('PENDING'),
            createdAt: now,
            updatedAt: now,
          ),
        );

    final category = ExpenseCategoryModel(
      id: id,
      name: trimmedName,
      active: active,
      version: 1,
      createdAt: now,
      updatedAt: now,
    );

    await _queueManager.enqueueOperation(
      entityType: 'expense_category',
      entityId: id,
      operation: 'CREATE',
      payload: {
        'id': id,
        'name': category.name,
        'active': category.active,
      },
    );

    _syncEngine.syncAll();
    return category;
  }

  /// Actualizar categoría de gasto offline
  Future<ExpenseCategoryModel> updateCategory({
    required String id,
    String? name,
    bool? active,
  }) async {
    final current = await getCategoryById(id);
    if (current == null) {
      throw StateError('La categoría no existe');
    }

    final updatedName = name != null ? name.trim() : current.name;
    if (updatedName.isEmpty) {
      throw ArgumentError('El nombre de la categoría no puede estar vacío');
    }
    if (updatedName.length > 100) {
      throw ArgumentError('El nombre de la categoría no puede superar los 100 caracteres');
    }

    final updatedActive = active ?? current.active;
    final now = DateTime.now().toUtc();
    final updatedVersion = current.version + 1;

    await (_db.update(_db.expenseCategoriesTable)..where((t) => t.id.equals(id))).write(
      ExpenseCategoriesTableCompanion(
        name: Value(updatedName),
        active: Value(updatedActive),
        version: Value(updatedVersion),
        syncStatus: const Value('PENDING'),
        updatedAt: Value(now),
      ),
    );

    final updatedCategory = ExpenseCategoryModel(
      id: id,
      name: updatedName,
      active: updatedActive,
      version: updatedVersion,
      createdAt: current.createdAt,
      updatedAt: now,
    );

    await _queueManager.enqueueOperation(
      entityType: 'expense_category',
      entityId: id,
      operation: 'UPDATE',
      payload: {
        'name': updatedCategory.name,
        'active': updatedCategory.active,
      },
      baseVersion: current.version,
    );

    _syncEngine.syncAll();
    return updatedCategory;
  }

  /// Desactivar/Eliminar categoría de gasto
  Future<void> deleteCategory(String id) async {
    final current = await getCategoryById(id);
    if (current == null) return;

    final now = DateTime.now().toUtc();
    final updatedVersion = current.version + 1;

    await (_db.update(_db.expenseCategoriesTable)..where((t) => t.id.equals(id))).write(
      ExpenseCategoriesTableCompanion(
        active: const Value(false),
        version: Value(updatedVersion),
        syncStatus: const Value('PENDING'),
        updatedAt: Value(now),
      ),
    );

    await _queueManager.enqueueOperation(
      entityType: 'expense_category',
      entityId: id,
      operation: 'DELETE',
      payload: {'id': id},
      baseVersion: current.version,
    );

    _syncEngine.syncAll();
  }

  // ─── EXPENSES CRUD OFFLINE ───────────────────────────────────────────────────

  /// Observa la lista de gastos filtrada y paginada desde SQLite (excluyendo eliminados)
  Stream<List<ExpenseModel>> watchExpenses({
    String? date,
    String? dateFrom,
    String? dateTo,
    String? categoryId,
    String? paymentMethod,
    int limit = 50,
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
    } else {
      if (dateFrom != null && dateFrom.isNotEmpty) {
        query.where(_db.expensesTable.expenseDate.isBiggerOrEqualValue(dateFrom));
      }
      if (dateTo != null && dateTo.isNotEmpty) {
        query.where(_db.expensesTable.expenseDate.isSmallerOrEqualValue(dateTo));
      }
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
    final trimmedDesc = description.trim();
    if (trimmedDesc.isEmpty) {
      throw ArgumentError('La descripción del gasto es obligatoria');
    }
    if (trimmedDesc.length > 500) {
      throw ArgumentError('La descripción del gasto no puede exceder 500 caracteres');
    }

    final roundedAmount = double.parse(amount.toStringAsFixed(2));
    if (roundedAmount <= 0) {
      throw ArgumentError('El monto debe ser mayor a cero');
    }

    // Validar existencia y estado activo de la categoría localmente
    final category = await (_db.select(_db.expenseCategoriesTable)..where((t) => t.id.equals(categoryId))).getSingleOrNull();
    if (category == null || !category.active) {
      throw StateError('La categoría seleccionada no es válida o está inactiva');
    }

    if (paymentMethod != 'CASH' && paymentMethod != 'QR' && paymentMethod != 'OTHER') {
      throw ArgumentError('Método de pago inválido. Valores aceptados: CASH, QR, OTHER');
    }

    final dateStr = expenseDate ?? TimezoneUtils.getTodayBusinessDate();
    if (!RegExp(r'^\d{4}-\d{2}-\d{2}$').hasMatch(dateStr)) {
      throw ArgumentError('La fecha del gasto debe tener el formato YYYY-MM-DD');
    }

    final id = _uuid.v4();
    final now = DateTime.now().toUtc();

    await _db.into(_db.expensesTable).insert(
          ExpensesTableCompanion.insert(
            id: id,
            description: trimmedDesc,
            amount: roundedAmount,
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
      description: trimmedDesc,
      amount: roundedAmount,
      categoryId: categoryId,
      categoryName: category.name,
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
  Future<ExpenseModel> updateExpense({
    required String id,
    String? description,
    double? amount,
    String? categoryId,
    String? paymentMethod,
    String? expenseDate,
  }) async {
    final current = await getExpenseById(id);
    if (current == null) {
      throw StateError('El gasto no existe');
    }

    final updatedDesc = description != null ? description.trim() : current.description;
    if (updatedDesc.isEmpty) {
      throw ArgumentError('La descripción del gasto no puede estar vacía');
    }
    if (updatedDesc.length > 500) {
      throw ArgumentError('La descripción del gasto no puede exceder 500 caracteres');
    }

    final updatedAmount = amount != null ? double.parse(amount.toStringAsFixed(2)) : current.amount;
    if (updatedAmount <= 0) {
      throw ArgumentError('El monto debe ser mayor a cero');
    }

    final updatedCategoryId = categoryId ?? current.categoryId;
    final category = await (_db.select(_db.expenseCategoriesTable)..where((t) => t.id.equals(updatedCategoryId))).getSingleOrNull();
    if (category == null || !category.active) {
      throw StateError('La categoría seleccionada no es válida o está inactiva');
    }

    final updatedPaymentMethod = paymentMethod ?? current.paymentMethod;
    if (updatedPaymentMethod != 'CASH' && updatedPaymentMethod != 'QR' && updatedPaymentMethod != 'OTHER') {
      throw ArgumentError('Método de pago inválido. Valores aceptados: CASH, QR, OTHER');
    }

    final updatedDate = expenseDate ?? current.expenseDate;
    if (!RegExp(r'^\d{4}-\d{2}-\d{2}$').hasMatch(updatedDate)) {
      throw ArgumentError('La fecha del gasto debe tener el formato YYYY-MM-DD');
    }

    final now = DateTime.now().toUtc();
    final updatedVersion = current.version + 1;

    final updatedExpense = ExpenseModel(
      id: id,
      description: updatedDesc,
      amount: updatedAmount,
      categoryId: updatedCategoryId,
      categoryName: category.name,
      paymentMethod: updatedPaymentMethod,
      expenseDate: updatedDate,
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
    return updatedExpense;
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

  // ─── MÉTRICAS LOCALES DE GASTOS ──────────────────────────────────────────────

  /// Total acumulado de gastos en un período
  Future<double> getTotalExpenses({String? date, String? dateFrom, String? dateTo}) async {
    final query = _db.selectOnly(_db.expensesTable)..where(_db.expensesTable.deletedAt.isNull());

    if (date != null && date.isNotEmpty) {
      query.where(_db.expensesTable.expenseDate.equals(date));
    } else {
      if (dateFrom != null && dateFrom.isNotEmpty) {
        query.where(_db.expensesTable.expenseDate.isBiggerOrEqualValue(dateFrom));
      }
      if (dateTo != null && dateTo.isNotEmpty) {
        query.where(_db.expensesTable.expenseDate.isSmallerOrEqualValue(dateTo));
      }
    }

    final totalExp = _db.expensesTable.amount.sum();
    query.addColumns([totalExp]);

    final row = await query.getSingle();
    return row.read(totalExp) ?? 0.0;
  }

  /// Conteo de registros de gastos en un período
  Future<int> getExpenseCount({String? date, String? dateFrom, String? dateTo}) async {
    final query = _db.selectOnly(_db.expensesTable)..where(_db.expensesTable.deletedAt.isNull());

    if (date != null && date.isNotEmpty) {
      query.where(_db.expensesTable.expenseDate.equals(date));
    } else {
      if (dateFrom != null && dateFrom.isNotEmpty) {
        query.where(_db.expensesTable.expenseDate.isBiggerOrEqualValue(dateFrom));
      }
      if (dateTo != null && dateTo.isNotEmpty) {
        query.where(_db.expensesTable.expenseDate.isSmallerOrEqualValue(dateTo));
      }
    }

    final countExp = _db.expensesTable.id.count();
    query.addColumns([countExp]);

    final row = await query.getSingle();
    return row.read(countExp) ?? 0;
  }
}
