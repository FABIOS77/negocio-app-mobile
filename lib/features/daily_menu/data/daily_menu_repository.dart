import 'dart:math';
import 'package:drift/drift.dart';
import 'package:uuid/uuid.dart';
import '../../../core/database/app_database.dart';
import '../../../core/sync/sync_engine.dart';
import '../../../core/sync/sync_queue_manager.dart';
import '../../../core/utils/timezone_utils.dart';
import '../../dishes/domain/dish_model.dart';
import '../domain/daily_menu_model.dart';

class DailyMenuRepository {
  final AppDatabase _db;
  final SyncQueueManager _queueManager;
  final SyncEngine _syncEngine;
  final Uuid _uuid;

  DailyMenuRepository({
    required AppDatabase db,
    required SyncQueueManager queueManager,
    required SyncEngine syncEngine,
    Uuid? uuid,
  })  : _db = db,
        _queueManager = queueManager,
        _syncEngine = syncEngine,
        _uuid = uuid ?? const Uuid();

  /// Observa reactivamente el menú activo de hoy en la zona horaria America/La_Paz (YYYY-MM-DD)
  Stream<DailyMenuModel?> watchTodayMenu() {
    final todayDate = TimezoneUtils.getTodayBusinessDate();
    return watchMenuByDate(todayDate);
  }

  /// Observa un menú diario por fecha YYYY-MM-DD (Tolerante a duplicados usando .watch())
  Stream<DailyMenuModel?> watchMenuByDate(String menuDate) {
    final query = _db.select(_db.dailyMenusTable)
      ..where((t) => t.menuDate.equals(menuDate))
      ..orderBy([(t) => OrderingTerm(expression: t.createdAt, mode: OrderingMode.desc)]);

    return query.watch().asyncMap((rows) async {
      if (rows.isEmpty) return null;
      final menuRow = rows.first;
      final dishes = await _getDishesForMenu(menuRow.id);
      return DailyMenuModel(
        id: menuRow.id,
        menuDate: menuRow.menuDate,
        active: menuRow.active,
        version: menuRow.version,
        syncStatus: menuRow.syncStatus,
        dishes: dishes,
        createdAt: menuRow.createdAt,
        updatedAt: menuRow.updatedAt,
      );
    });
  }

  /// Obtiene los platos asociados a un menú diario desde SQLite
  Future<List<DishModel>> _getDishesForMenu(String menuId) async {
    final relations = await (_db.select(_db.dailyMenuDishesTable)..where((t) => t.dailyMenuId.equals(menuId))).get();
    if (relations.isEmpty) return [];

    final dishIds = relations.map((r) => r.dishId).toList();
    final dishRows = await (_db.select(_db.dishesTable)..where((t) => t.id.isIn(dishIds))).get();

    return dishRows.map((r) {
      return DishModel(
        id: r.id,
        name: r.name,
        description: r.description,
        price: r.price,
        imageUrl: r.imageUrl,
        active: r.active,
        version: r.version,
        syncStatus: r.syncStatus,
        deletedAt: r.deletedAt,
        createdAt: r.createdAt,
        updatedAt: r.updatedAt,
      );
    }).toList();
  }

  /// Crear un menú diario offline mediante Transacción Drift Atómica
  Future<DailyMenuModel> createDailyMenu({
    required String menuDate,
    required List<String> dishIds,
  }) async {
    final menuId = _uuid.v4();
    final now = DateTime.now().toUtc();

    // 1. Ejecutar Transacción Atómica en SQLite (DailyMenu + DailyMenuDishes)
    await _db.transaction(() async {
      await _db.into(_db.dailyMenusTable).insert(
            DailyMenusTableCompanion.insert(
              id: menuId,
              menuDate: menuDate,
              active: const Value(true),
              version: const Value(1),
              syncStatus: const Value('PENDING'),
              createdAt: now,
              updatedAt: now,
            ),
          );

      for (final dishId in dishIds) {
        await _db.into(_db.dailyMenuDishesTable).insert(
              DailyMenuDishesTableCompanion.insert(
                id: '${menuId}_$dishId',
                dailyMenuId: menuId,
                dishId: dishId,
              ),
            );
      }
    });

    final dishes = await _getDishesForMenu(menuId);
    final menu = DailyMenuModel(
      id: menuId,
      menuDate: menuDate,
      active: true,
      version: 1,
      syncStatus: 'PENDING',
      dishes: dishes,
      createdAt: now,
      updatedAt: now,
    );

    // 2. Encolar mutación offline PUSH
    await _queueManager.enqueueOperation(
      entityType: 'daily_menu',
      entityId: menuId,
      operation: 'CREATE',
      payload: {
        'id': menuId,
        'menu_date': menuDate,
        'dish_ids': dishIds,
      },
    );

    _syncEngine.syncAll();
    return menu;
  }

  /// Actualizar los platos de un menú diario offline con transacción
  Future<void> updateDailyMenu({
    required String id,
    required String menuDate,
    required List<String> dishIds,
    required int currentVersion,
  }) async {
    final now = DateTime.now().toUtc();
    final newVersion = currentVersion + 1;

    await _db.transaction(() async {
      await (_db.update(_db.dailyMenusTable)..where((t) => t.id.equals(id))).write(
        DailyMenusTableCompanion(
          menuDate: Value(menuDate),
          version: Value(newVersion),
          syncStatus: const Value('PENDING'),
          updatedAt: Value(now),
        ),
      );

      // Reconstruir relaciones platos-menú
      await (_db.delete(_db.dailyMenuDishesTable)..where((t) => t.dailyMenuId.equals(id))).go();
      for (final dishId in dishIds) {
        await _db.into(_db.dailyMenuDishesTable).insert(
              DailyMenuDishesTableCompanion.insert(
                id: '${id}_$dishId',
                dailyMenuId: id,
                dishId: dishId,
              ),
            );
      }
    });

    await _queueManager.enqueueOperation(
      entityType: 'daily_menu',
      entityId: id,
      operation: 'UPDATE',
      payload: {
        'id': id,
        'menu_date': menuDate,
        'dish_ids': dishIds,
      },
      baseVersion: currentVersion,
    );

    _syncEngine.syncAll();
  }

  /// Realiza un sorteo local/offline de platos activos para sugerencia de menú
  List<DishModel> drawRandomDishes(List<DishModel> availableDishes, {int count = 3}) {
    final active = availableDishes.where((d) => d.active).toList();
    if (active.isEmpty) return [];
    active.shuffle(Random());
    return active.take(count).toList();
  }
}
