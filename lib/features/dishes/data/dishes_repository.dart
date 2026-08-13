import 'package:drift/drift.dart';
import 'package:uuid/uuid.dart';
import '../../../core/database/app_database.dart';
import '../../../core/sync/sync_engine.dart';
import '../../../core/sync/sync_queue_manager.dart';
import '../domain/dish_model.dart';

class DishesRepository {
  final AppDatabase _db;
  final SyncQueueManager _queueManager;
  final SyncEngine _syncEngine;
  final Uuid _uuid;

  DishesRepository({
    required AppDatabase db,
    required SyncQueueManager queueManager,
    required SyncEngine syncEngine,
    Uuid? uuid,
  })  : _db = db,
        _queueManager = queueManager,
        _syncEngine = syncEngine,
        _uuid = uuid ?? const Uuid();

  /// Emite la lista de platos almacenada en SQLite con filtrado, búsqueda e índices
  Stream<List<DishModel>> watchDishes({
    bool? activeOnly = true,
    String? searchQuery,
    int limit = 20,
    int offset = 0,
  }) {
    final query = _db.select(_db.dishesTable);

    if (activeOnly != null && activeOnly) {
      query.where((t) => t.active.equals(true) & t.deletedAt.isNull());
    }

    if (searchQuery != null && searchQuery.trim().isNotEmpty) {
      final pattern = '%${searchQuery.trim().toLowerCase()}%';
      query.where((t) => t.name.lower().like(pattern));
    }

    query.orderBy([(t) => OrderingTerm(expression: t.name, mode: OrderingMode.asc)]);
    query.limit(limit, offset: offset);

    return query.watch().map((rows) {
      return rows.map((r) {
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
    });
  }

  /// Obtiene un plato por ID desde SQLite
  Future<DishModel?> getDishById(String id) async {
    final row = await (_db.select(_db.dishesTable)..where((t) => t.id.equals(id))).getSingleOrNull();
    if (row == null) return null;
    return DishModel(
      id: row.id,
      name: row.name,
      description: row.description,
      price: row.price,
      imageUrl: row.imageUrl,
      active: row.active,
      version: row.version,
      syncStatus: row.syncStatus,
      deletedAt: row.deletedAt,
      createdAt: row.createdAt,
      updatedAt: row.updatedAt,
    );
  }

  /// Crear plato offline (genera UUID, guarda en SQLite, encola sync PENDING y dispara sync)
  Future<DishModel> createDish({
    required String name,
    String? description,
    required double price,
    String? imageUrl,
  }) async {
    final id = _uuid.v4();
    final now = DateTime.now().toUtc();
    final cleanName = name.trim();
    final cleanDesc = (description != null && description.trim().isNotEmpty) ? description.trim() : null;
    final cleanImageUrl = (imageUrl != null && imageUrl.trim().isNotEmpty) ? imageUrl.trim() : null;

    // 1. Guardar en SQLite
    await _db.into(_db.dishesTable).insert(
          DishesTableCompanion.insert(
            id: id,
            name: cleanName,
            description: Value(cleanDesc),
            price: price,
            imageUrl: Value(cleanImageUrl),
            active: const Value(true),
            version: const Value(1),
            syncStatus: const Value('PENDING'),
            createdAt: now,
            updatedAt: now,
          ),
        );

    final dish = DishModel(
      id: id,
      name: cleanName,
      description: cleanDesc,
      price: price,
      imageUrl: cleanImageUrl,
      active: true,
      version: 1,
      syncStatus: 'PENDING',
      createdAt: now,
      updatedAt: now,
    );

    // 2. Encolar mutación offline
    await _queueManager.enqueueOperation(
      entityType: 'dish',
      entityId: id,
      operation: 'CREATE',
      payload: dish.toJson(),
    );

    // 3. Disparar sincronización de fondo si hay red disponible
    _syncEngine.syncAll();

    return dish;
  }

  /// Actualizar plato offline con versión base
  Future<void> updateDish({
    required String id,
    String? name,
    String? description,
    double? price,
    String? imageUrl,
    bool? active,
  }) async {
    final current = await getDishById(id);
    if (current == null) return;

    final now = DateTime.now().toUtc();
    final updatedVersion = current.version + 1;

    final cleanName = name != null ? name.trim() : current.name;
    final cleanDesc = description != null
        ? (description.trim().isNotEmpty ? description.trim() : null)
        : current.description;
    final cleanImageUrl = imageUrl != null
        ? (imageUrl.trim().isNotEmpty ? imageUrl.trim() : null)
        : current.imageUrl;

    final updatedDish = DishModel(
      id: id,
      name: cleanName,
      description: cleanDesc,
      price: price ?? current.price,
      imageUrl: cleanImageUrl,
      active: active ?? current.active,
      version: updatedVersion,
      syncStatus: 'PENDING',
      createdAt: current.createdAt,
      updatedAt: now,
    );

    // 1. Actualizar SQLite
    await (_db.update(_db.dishesTable)..where((t) => t.id.equals(id))).write(
      DishesTableCompanion(
        name: Value(updatedDish.name),
        description: Value(updatedDish.description),
        price: Value(updatedDish.price),
        imageUrl: Value(updatedDish.imageUrl),
        active: Value(updatedDish.active),
        version: Value(updatedVersion),
        syncStatus: const Value('PENDING'),
        updatedAt: Value(now),
      ),
    );

    // 2. Encolar mutación UPDATE con base_version
    await _queueManager.enqueueOperation(
      entityType: 'dish',
      entityId: id,
      operation: 'UPDATE',
      payload: updatedDish.toJson(),
      baseVersion: current.version,
    );

    _syncEngine.syncAll();
  }

  /// Soft delete de plato (active: false)
  Future<void> deleteDish(String id) async {
    final current = await getDishById(id);
    if (current == null) return;

    final now = DateTime.now().toUtc();
    final updatedVersion = current.version + 1;

    // 1. Marcar inactivo y deletedAt en SQLite
    await (_db.update(_db.dishesTable)..where((t) => t.id.equals(id))).write(
      DishesTableCompanion(
        active: const Value(false),
        deletedAt: Value(now),
        version: Value(updatedVersion),
        syncStatus: const Value('PENDING'),
        updatedAt: Value(now),
      ),
    );

    // 2. Encolar mutación DELETE
    await _queueManager.enqueueOperation(
      entityType: 'dish',
      entityId: id,
      operation: 'DELETE',
      payload: {'id': id},
      baseVersion: current.version,
    );

    _syncEngine.syncAll();
  }
}
