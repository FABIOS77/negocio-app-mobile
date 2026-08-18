import 'package:drift/drift.dart';
import 'package:uuid/uuid.dart';
import '../../../core/database/app_database.dart';
import '../../../core/sync/sync_engine.dart';
import '../../../core/sync/sync_queue_manager.dart';
import '../../../core/utils/timezone_utils.dart';
import '../domain/order_item_model.dart';
import '../domain/order_model.dart';
import '../domain/order_summary_model.dart';

class OrdersRepository {
  final AppDatabase _db;
  final SyncQueueManager _queueManager;
  final SyncEngine _syncEngine;
  final Uuid _uuid;

  OrdersRepository({
    required AppDatabase db,
    required SyncQueueManager queueManager,
    required SyncEngine syncEngine,
    Uuid? uuid,
  })  : _db = db,
        _queueManager = queueManager,
        _syncEngine = syncEngine,
        _uuid = uuid ?? const Uuid();

  /// Observa reactivamente los pedidos activos del día (America/La_Paz) ordenados por orderedAt DESC, excluyendo cancelados
  Stream<List<OrderSummaryModel>> watchTodayOrders() {
    final todayDate = TimezoneUtils.getTodayBusinessDate();
    return watchOrders(date: todayDate, excludeCancelled: true, limit: 100);
  }

  /// Observa pedidos con filtros de fecha (desde/hasta en America/La_Paz), estado, búsqueda de texto paginados.
  /// Emite OrderSummaryModel con itemsCount agregado en SQL de forma instantánea y reactiva con readsFrom.
  Stream<List<OrderSummaryModel>> watchOrders({
    String? status,
    String? date,
    String? dateFrom,
    String? dateTo,
    String? searchQuery,
    bool excludeCancelled = false,
    int limit = 50,
    int offset = 0,
  }) {
    final whereClauses = <String>[];
    final variables = <Variable>[];

    // 1. Filtro de estado
    if (status != null && status.isNotEmpty) {
      whereClauses.add('o.status = ?');
      variables.add(Variable.withString(status));
    } else if (excludeCancelled) {
      whereClauses.add("o.status != 'CANCELLED'");
    }

    // 2. Filtro de fechas en America/La_Paz (UTC-4: el inicio del día es a las 04:00:00Z)
    if (date != null && date.isNotEmpty) {
      final dateStart = DateTime.parse('${date}T00:00:00.000Z').add(const Duration(hours: 4));
      final dateEnd = dateStart.add(const Duration(days: 1));
      whereClauses.add('o.ordered_at >= ? AND o.ordered_at < ?');
      variables.add(Variable.withDateTime(dateStart));
      variables.add(Variable.withDateTime(dateEnd));
    } else {
      if (dateFrom != null && dateFrom.isNotEmpty) {
        final dateStart = DateTime.parse('${dateFrom}T00:00:00.000Z').add(const Duration(hours: 4));
        whereClauses.add('o.ordered_at >= ?');
        variables.add(Variable.withDateTime(dateStart));
      }
      if (dateTo != null && dateTo.isNotEmpty) {
        final dateEnd = DateTime.parse('${dateTo}T00:00:00.000Z').add(const Duration(hours: 4 + 24));
        whereClauses.add('o.ordered_at < ?');
        variables.add(Variable.withDateTime(dateEnd));
      }
    }

    // 3. Búsqueda por texto (customer_name, location_text, order_number)
    if (searchQuery != null && searchQuery.trim().isNotEmpty) {
      final term = '%${searchQuery.trim().toLowerCase()}%';
      whereClauses.add("(LOWER(o.customer_name) LIKE ? OR LOWER(COALESCE(o.location_text, '')) LIKE ? OR CAST(COALESCE(o.order_number, '') AS TEXT) LIKE ?)");
      variables.add(Variable.withString(term));
      variables.add(Variable.withString(term));
      variables.add(Variable.withString(term));
    }

    final whereSql = whereClauses.isNotEmpty ? 'WHERE ${whereClauses.join(' AND ')}' : '';

    final sql = '''
      SELECT 
        o.id,
        o.order_number,
        o.customer_name,
        o.location_text,
        o.total,
        o.payment_method,
        o.status,
        o.ordered_at,
        o.created_by,
        o.version,
        o.sync_status,
        o.created_at,
        o.updated_at,
        COALESCE((SELECT COUNT(*) FROM order_items_table WHERE order_id = o.id), 0) AS items_count
      FROM orders_table o
      $whereSql
      ORDER BY o.ordered_at DESC
      LIMIT ? OFFSET ?
    ''';

    variables.add(Variable.withInt(limit));
    variables.add(Variable.withInt(offset));

    return _db.customSelect(
      sql,
      variables: variables,
      readsFrom: {_db.ordersTable, _db.orderItemsTable},
    ).watch().map((rows) {
      return rows.map((r) {
        return OrderSummaryModel(
          id: r.read<String>('id'),
          orderNumber: r.readNullable<String>('order_number'),
          customerName: r.read<String>('customer_name'),
          locationText: r.readNullable<String>('location_text'),
          total: r.read<double>('total'),
          paymentMethod: r.read<String>('payment_method'),
          status: r.read<String>('status'),
          orderedAt: r.read<DateTime>('ordered_at'),
          createdBy: r.read<String>('created_by'),
          version: r.read<int>('version'),
          syncStatus: r.read<String>('sync_status'),
          itemsCount: r.read<int>('items_count'),
          createdAt: r.read<DateTime>('created_at'),
          updatedAt: r.read<DateTime>('updated_at'),
        );
      }).toList();
    });
  }

  Future<List<OrderItemModel>> _getOrderItems(String orderId) async {
    final itemRows = await (_db.select(_db.orderItemsTable)..where((t) => t.orderId.equals(orderId))).get();
    return itemRows
        .map(
          (r) => OrderItemModel(
            id: r.id,
            orderId: r.orderId,
            dishId: r.dishId,
            dishNameSnapshot: r.dishNameSnapshot,
            quantity: r.quantity,
            unitPrice: r.unitPrice,
            subtotal: r.subtotal,
          ),
        )
        .toList();
  }

  /// Obtiene un pedido completo por ID con sus items
  Future<OrderModel?> getOrderById(String id) async {
    final row = await (_db.select(_db.ordersTable)..where((t) => t.id.equals(id))).getSingleOrNull();
    if (row == null) return null;

    final items = await _getOrderItems(row.id);
    return OrderModel(
      id: row.id,
      orderNumber: row.orderNumber,
      customerName: row.customerName,
      locationText: row.locationText,
      total: row.total,
      paymentMethod: row.paymentMethod,
      status: row.status,
      orderedAt: row.orderedAt,
      createdBy: row.createdBy,
      version: row.version,
      syncStatus: row.syncStatus,
      items: items,
      createdAt: row.createdAt,
      updatedAt: row.updatedAt,
    );
  }

  /// Crear pedido offline (calcula total con precio congelado, guarda pedido + items atómicamente, encola CREATE y dispara sync)
  Future<OrderModel> createOrder({
    required String customerName,
    String? locationText,
    required String paymentMethod,
    required List<({String dishId, int quantity})> itemsInput,
  }) async {
    final orderId = _uuid.v4();
    final now = DateTime.now().toUtc();

    if (customerName.trim().isEmpty) {
      throw ArgumentError('El nombre del cliente es obligatorio');
    }

    if (itemsInput.isEmpty) {
      throw ArgumentError('El pedido debe incluir al menos un plato');
    }

    final aggregatedMap = <String, int>{};
    for (final item in itemsInput) {
      if (item.quantity > 0) {
        aggregatedMap[item.dishId] = (aggregatedMap[item.dishId] ?? 0) + item.quantity;
      }
    }

    if (aggregatedMap.isEmpty) {
      throw ArgumentError('El pedido debe incluir al menos un plato con cantidad positiva');
    }

    final orderItems = <OrderItemModel>[];
    double calculatedTotal = 0.0;

    for (final entry in aggregatedMap.entries) {
      final dishId = entry.key;
      final quantity = entry.value;

      final dish = await (_db.select(_db.dishesTable)..where((t) => t.id.equals(dishId))).getSingleOrNull();
      if (dish == null || !dish.active) {
        throw StateError('El plato no está disponible en el catálogo local');
      }

      final unitPrice = dish.price;
      final subtotal = (unitPrice * quantity);
      calculatedTotal += subtotal;

      final itemId = _uuid.v4();
      orderItems.add(
        OrderItemModel(
          id: itemId,
          orderId: orderId,
          dishId: dishId,
          dishNameSnapshot: dish.name,
          quantity: quantity,
          unitPrice: unitPrice,
          subtotal: subtotal,
        ),
      );
    }

    await _db.transaction(() async {
      await _db.into(_db.ordersTable).insert(
            OrdersTableCompanion.insert(
              id: orderId,
              customerName: customerName.trim(),
              locationText: locationText != null && locationText.trim().isNotEmpty ? Value(locationText.trim()) : const Value.absent(),
              total: calculatedTotal,
              paymentMethod: paymentMethod,
              status: 'PENDING',
              orderedAt: now,
              createdBy: 'local-user',
              version: const Value(1),
              syncStatus: const Value('PENDING'),
              createdAt: now,
              updatedAt: now,
            ),
          );

      for (final item in orderItems) {
        await _db.into(_db.orderItemsTable).insert(
              OrderItemsTableCompanion.insert(
                id: item.id,
                orderId: orderId,
                dishId: item.dishId,
                dishNameSnapshot: item.dishNameSnapshot,
                quantity: item.quantity,
                unitPrice: item.unitPrice,
                subtotal: item.subtotal,
              ),
            );
      }
    });

    final order = OrderModel(
      id: orderId,
      customerName: customerName.trim(),
      locationText: locationText?.trim(),
      total: calculatedTotal,
      paymentMethod: paymentMethod,
      status: 'PENDING',
      orderedAt: now,
      createdBy: 'local-user',
      version: 1,
      syncStatus: 'PENDING',
      items: orderItems,
      createdAt: now,
      updatedAt: now,
    );

    await _queueManager.enqueueOperation(
      entityType: 'order',
      entityId: orderId,
      operation: 'CREATE',
      payload: {
        'id': orderId,
        'customer_name': order.customerName,
        if (order.locationText != null) 'location_text': order.locationText,
        'payment_method': order.paymentMethod,
        'ordered_at': now.toIso8601String(),
        'items': orderItems.map((i) => {'dish_id': i.dishId, 'quantity': i.quantity}).toList(),
      },
    );

    _syncEngine.syncAll();
    return order;
  }

  /// Actualizar pedido en estado PENDING (reemplaza order_items, recalcula total, incrementa version)
  Future<OrderModel> updateOrder({
    required String id,
    required String customerName,
    String? locationText,
    required String paymentMethod,
    required List<({String dishId, int quantity})> itemsInput,
  }) async {
    final current = await getOrderById(id);
    if (current == null) {
      throw StateError('El pedido no existe');
    }

    if (current.status != 'PENDING') {
      throw StateError('Solo se pueden editar pedidos en estado PENDING');
    }

    if (customerName.trim().isEmpty) {
      throw ArgumentError('El nombre del cliente es obligatorio');
    }

    if (itemsInput.isEmpty) {
      throw ArgumentError('El pedido debe incluir al menos un plato');
    }

    final aggregatedMap = <String, int>{};
    for (final item in itemsInput) {
      if (item.quantity > 0) {
        aggregatedMap[item.dishId] = (aggregatedMap[item.dishId] ?? 0) + item.quantity;
      }
    }

    if (aggregatedMap.isEmpty) {
      throw ArgumentError('El pedido debe incluir al menos un plato con cantidad positiva');
    }

    final now = DateTime.now().toUtc();
    final updatedVersion = current.version + 1;

    final orderItems = <OrderItemModel>[];
    double calculatedTotal = 0.0;

    for (final entry in aggregatedMap.entries) {
      final dishId = entry.key;
      final quantity = entry.value;

      final dish = await (_db.select(_db.dishesTable)..where((t) => t.id.equals(dishId))).getSingleOrNull();
      if (dish == null || !dish.active) {
        throw StateError('El plato no está disponible en el catálogo local');
      }

      final unitPrice = dish.price;
      final subtotal = (unitPrice * quantity);
      calculatedTotal += subtotal;

      final itemId = _uuid.v4();
      orderItems.add(
        OrderItemModel(
          id: itemId,
          orderId: id,
          dishId: dishId,
          dishNameSnapshot: dish.name,
          quantity: quantity,
          unitPrice: unitPrice,
          subtotal: subtotal,
        ),
      );
    }

    await _db.transaction(() async {
      // 1. Limpiar items anteriores
      await (_db.delete(_db.orderItemsTable)..where((t) => t.orderId.equals(id))).go();

      // 2. Insertar nuevos items
      for (final item in orderItems) {
        await _db.into(_db.orderItemsTable).insert(
              OrderItemsTableCompanion.insert(
                id: item.id,
                orderId: id,
                dishId: item.dishId,
                dishNameSnapshot: item.dishNameSnapshot,
                quantity: item.quantity,
                unitPrice: item.unitPrice,
                subtotal: item.subtotal,
              ),
            );
      }

      // 3. Actualizar registro principal
      await (_db.update(_db.ordersTable)..where((t) => t.id.equals(id))).write(
        OrdersTableCompanion(
          customerName: Value(customerName.trim()),
          locationText: locationText != null && locationText.trim().isNotEmpty ? Value(locationText.trim()) : const Value(null),
          total: Value(calculatedTotal),
          paymentMethod: Value(paymentMethod),
          version: Value(updatedVersion),
          syncStatus: const Value('PENDING'),
          updatedAt: Value(now),
        ),
      );
    });

    final updatedOrder = OrderModel(
      id: id,
      orderNumber: current.orderNumber,
      customerName: customerName.trim(),
      locationText: locationText?.trim(),
      total: calculatedTotal,
      paymentMethod: paymentMethod,
      status: current.status,
      orderedAt: current.orderedAt,
      createdBy: current.createdBy,
      version: updatedVersion,
      syncStatus: 'PENDING',
      items: orderItems,
      createdAt: current.createdAt,
      updatedAt: now,
    );

    await _queueManager.enqueueOperation(
      entityType: 'order',
      entityId: id,
      operation: 'UPDATE',
      payload: {
        'customer_name': updatedOrder.customerName,
        if (updatedOrder.locationText != null) 'location_text': updatedOrder.locationText,
        'payment_method': updatedOrder.paymentMethod,
        'ordered_at': current.orderedAt.toIso8601String(),
        'items': orderItems.map((i) => {'dish_id': i.dishId, 'quantity': i.quantity}).toList(),
      },
      baseVersion: current.version,
    );

    _syncEngine.syncAll();
    return updatedOrder;
  }

  /// Eliminar pedido (soft delete marca status CANCELLED, encola DELETE en SyncQueueTable)
  Future<void> deleteOrder(String id) async {
    final current = await getOrderById(id);
    if (current == null) return;

    final now = DateTime.now().toUtc();
    final updatedVersion = current.version + 1;

    await _db.transaction(() async {
      await (_db.update(_db.ordersTable)..where((t) => t.id.equals(id))).write(
        OrdersTableCompanion(
          status: const Value('CANCELLED'),
          version: Value(updatedVersion),
          syncStatus: const Value('PENDING'),
          updatedAt: Value(now),
        ),
      );
    });

    await _queueManager.enqueueOperation(
      entityType: 'order',
      entityId: id,
      operation: 'DELETE',
      payload: {'id': id},
      baseVersion: current.version,
    );

    _syncEngine.syncAll();
  }

  /// Marcar orden localmente como CANCELLED sin encolar operación de PUSH (usado durante PULL)
  Future<void> deleteOrderLocalOnly(String id, {int? version}) async {
    final now = DateTime.now().toUtc();
    await (_db.update(_db.ordersTable)..where((t) => t.id.equals(id))).write(
      OrdersTableCompanion(
        status: const Value('CANCELLED'),
        version: version != null ? Value(version) : const Value.absent(),
        syncStatus: const Value('SYNCED'),
        updatedAt: Value(now),
      ),
    );
  }

  Future<void> changeOrderStatus(String id, String newStatus) async {
    final current = await getOrderById(id);
    if (current == null) return;

    if (current.status == 'DELIVERED' || current.status == 'CANCELLED') {
      throw StateError('El pedido ya se encuentra en un estado terminal (${current.status})');
    }

    if (newStatus != 'DELIVERED' && newStatus != 'CANCELLED') {
      throw ArgumentError('Estado inválido. Solo se permite DELIVERED o CANCELLED');
    }

    final now = DateTime.now().toUtc();
    final updatedVersion = current.version + 1;

    await (_db.update(_db.ordersTable)..where((t) => t.id.equals(id))).write(
      OrdersTableCompanion(
        status: Value(newStatus),
        version: Value(updatedVersion),
        syncStatus: const Value('PENDING'),
        updatedAt: Value(now),
      ),
    );

    await _queueManager.enqueueOperation(
      entityType: 'order',
      entityId: id,
      operation: 'UPDATE',
      payload: {
        'status': newStatus,
      },
      baseVersion: current.version,
    );

    _syncEngine.syncAll();
  }
}
