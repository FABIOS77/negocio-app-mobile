import 'dart:convert';
import 'package:dio/dio.dart';
import 'package:drift/drift.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../config/app_constants.dart';
import '../database/app_database.dart';
import '../network/dio_client.dart';
import '../network/network_info.dart';
import '../utils/network_error_parser.dart';
import '../utils/parse_utils.dart';
import 'sync_queue_manager.dart';

class SyncResult {
  final int pushedCount;
  final int pulledCount;
  final int conflictCount;
  final int errorCount;
  final String? message;

  SyncResult({
    required this.pushedCount,
    required this.pulledCount,
    required this.conflictCount,
    required this.errorCount,
    this.message,
  });

  bool get isSuccess => errorCount == 0 && conflictCount == 0;
}

final databaseProvider = Provider<AppDatabase>((ref) {
  final db = AppDatabase();
  ref.onDispose(() => db.close());
  return db;
});

final syncQueueManagerProvider = Provider<SyncQueueManager>((ref) {
  final db = ref.watch(databaseProvider);
  return SyncQueueManager(db);
});

final networkInfoProvider = Provider<NetworkInfo>((ref) {
  return NetworkInfo();
});

final syncEngineProvider = Provider<SyncEngine>((ref) {
  final db = ref.watch(databaseProvider);
  final queueManager = ref.watch(syncQueueManagerProvider);
  final dio = ref.watch(dioProvider);
  final networkInfo = ref.watch(networkInfoProvider);
  return SyncEngine(
    db: db,
    queueManager: queueManager,
    dio: dio,
    networkInfo: networkInfo,
  );
});

class SyncEngine {
  final AppDatabase _db;
  final SyncQueueManager _queueManager;
  final Dio _dio;
  final NetworkInfo _networkInfo;

  bool _isSyncing = false;

  SyncEngine({
    required AppDatabase db,
    required SyncQueueManager queueManager,
    required Dio dio,
    required NetworkInfo networkInfo,
  })  : _db = db,
        _queueManager = queueManager,
        _dio = dio,
        _networkInfo = networkInfo;

  bool get isSyncing => _isSyncing;

  /// Ejecuta sincronización completa (PUSH primero, luego PULL) con protección de concurrencia.
  Future<SyncResult> syncAll() async {
    if (_isSyncing) {
      return SyncResult(
        pushedCount: 0,
        pulledCount: 0,
        conflictCount: 0,
        errorCount: 0,
        message: 'Sincronización ya en progreso',
      );
    }

    final isConnected = await _networkInfo.isConnected;
    if (!isConnected) {
      return SyncResult(
        pushedCount: 0,
        pulledCount: 0,
        conflictCount: 0,
        errorCount: 0,
        message: 'Sin conexión a Internet',
      );
    }

    _isSyncing = true;

    try {
      final pushResult = await push();
      final pullCount = await pull();

      await _queueManager.removeSyncedOperations();

      return SyncResult(
        pushedCount: pushResult.processed,
        pulledCount: pullCount,
        conflictCount: pushResult.conflicts,
        errorCount: pushResult.failed,
      );
    } catch (e) {
      return SyncResult(
        pushedCount: 0,
        pulledCount: 0,
        conflictCount: 0,
        errorCount: 1,
        message: e.toString(),
      );
    } finally {
      _isSyncing = false;
    }
  }

  /// PUSH — Enviar mutaciones pendientes locales al backend
  Future<({int processed, int conflicts, int failed})> push() async {
    final pendingOps = await _queueManager.getPendingOperations(limit: AppConstants.syncBatchSize);
    if (pendingOps.isEmpty) {
      return (processed: 0, conflicts: 0, failed: 0);
    }

    final payloadOps = pendingOps.map((op) {
      final rawPayload = jsonDecode(op.payload);
      final entityType = op.entityType.toLowerCase();
      Map<String, dynamic> cleanPayload = {};

      if (rawPayload is Map<String, dynamic>) {
        if (entityType == 'dish') {
          cleanPayload = {
            'name': (rawPayload['name'] ?? '').toString().trim(),
            'price': ParseUtils.toDouble(rawPayload['price']),
            if (rawPayload['description'] != null && rawPayload['description'].toString().trim().isNotEmpty)
              'description': rawPayload['description'].toString().trim(),
            if (rawPayload['image_url'] != null || rawPayload['imageUrl'] != null)
              'image_url': (rawPayload['image_url'] ?? rawPayload['imageUrl'])?.toString().trim(),
            if (rawPayload['active'] != null) 'active': rawPayload['active'] == true,
          };
        } else if (entityType == 'daily_menu') {
          final rawDishes = rawPayload['dish_ids'] ?? rawPayload['dishes'] ?? [];
          final List<String> dishIds = [];
          if (rawDishes is List) {
            for (final item in rawDishes) {
              if (item is String) {
                dishIds.add(item);
              } else if (item is Map && item['id'] != null) {
                dishIds.add(item['id'].toString());
              }
            }
          }
          cleanPayload = {
            'menu_date': (rawPayload['menu_date'] ?? rawPayload['menuDate'])?.toString() ?? '',
            'dish_ids': dishIds,
          };
        } else if (entityType == 'order') {
          final hasStatus = rawPayload.containsKey('status');
          final hasCustomer = rawPayload.containsKey('customer_name') || rawPayload.containsKey('customerName');
          final hasItems = rawPayload.containsKey('items');

          if (hasStatus && !hasCustomer && !hasItems) {
            cleanPayload = {
              'status': rawPayload['status']?.toString() ?? 'PENDING',
            };
          } else {
            final rawItems = rawPayload['items'] ?? [];
            final List<Map<String, dynamic>> itemsList = [];
            if (rawItems is List) {
              for (final item in rawItems) {
                if (item is Map) {
                  itemsList.add({
                    'dish_id': (item['dish_id'] ?? item['dishId'])?.toString() ?? '',
                    'quantity': ParseUtils.toInt(item['quantity'], 1),
                  });
                }
              }
            }
            final locText = (rawPayload['location_text'] ?? rawPayload['locationText'])?.toString().trim();
            final orderedAt = (rawPayload['ordered_at'] ?? rawPayload['orderedAt'])?.toString().trim();
            cleanPayload = {
              'customer_name': (rawPayload['customer_name'] ?? rawPayload['customerName'])?.toString() ?? '',
              if (locText != null && locText.isNotEmpty) 'location_text': locText,
              'payment_method': (rawPayload['payment_method'] ?? rawPayload['paymentMethod'])?.toString() ?? 'CASH',
              if (orderedAt != null && orderedAt.isNotEmpty) 'ordered_at': orderedAt,
              if (hasStatus) 'status': rawPayload['status'].toString(),
              'items': itemsList,
            };
          }
        } else if (entityType == 'expense') {
          cleanPayload = {
            'description': (rawPayload['description'] ?? '').toString(),
            'amount': ParseUtils.toDouble(rawPayload['amount']),
            'category_id': (rawPayload['category_id'] ?? rawPayload['categoryId'])?.toString() ?? '',
            'payment_method': (rawPayload['payment_method'] ?? rawPayload['paymentMethod'])?.toString() ?? 'CASH',
            'expense_date': (rawPayload['expense_date'] ?? rawPayload['expenseDate'])?.toString() ?? '',
          };
        } else {
          cleanPayload = Map<String, dynamic>.from(rawPayload);
          cleanPayload.remove('created_at');
          cleanPayload.remove('updated_at');
          cleanPayload.remove('deleted_at');
          cleanPayload.remove('sync_status');
          cleanPayload.remove('version');
          cleanPayload.remove('createdAt');
          cleanPayload.remove('updatedAt');
          cleanPayload.remove('deletedAt');
          cleanPayload.remove('syncStatus');
        }
      }

      // Convertir client_timestamp a ISO-8601 UTC estricto con sufijo 'Z'
      final clientTimestampIso = op.clientTimestamp.toUtc().toIso8601String();

      return {
        'operation_id': op.operationId,
        'entity_type': entityType,
        'entity_id': op.entityId,
        'operation': op.operation.toUpperCase(),
        'payload': cleanPayload,
        'client_timestamp': clientTimestampIso,
        if (op.baseVersion != null) 'base_version': ParseUtils.toInt(op.baseVersion),
      };
    }).toList();

    try {
      final response = await _dio.post('/sync/push', data: {'operations': payloadOps});
      final data = response.data['data'] ?? response.data;
      final results = (data['results'] as List? ?? []);

      int processedCount = 0;
      int conflictCount = 0;
      int failedCount = 0;

      for (final res in results) {
        final opId = res['operation_id'] as String;
        final status = res['status'] as String;
        final serverVersion = ParseUtils.toInt(res['server_version'], 1);
        final errorMessage = res['error_message'] as String?;

        final matchingOp = pendingOps.cast<SyncQueueTableData?>().firstWhere(
          (o) => o?.operationId == opId,
          orElse: () => null,
        );

        if (status == 'PROCESSED' || status == 'DUPLICATE') {
          processedCount++;
          await _queueManager.markOperationStatus(opId, 'SYNCED');
          if (matchingOp != null) {
            await _updateLocalEntityStatus(matchingOp.entityType, matchingOp.entityId, serverVersion, 'SYNCED');
          }
        } else if (status == 'CONFLICT') {
          conflictCount++;
          await _queueManager.markOperationStatus(opId, 'CONFLICT', error: errorMessage);
          if (matchingOp != null) {
            await _updateLocalEntityStatus(matchingOp.entityType, matchingOp.entityId, serverVersion, 'CONFLICT');
          }
        } else {
          failedCount++;
          // Error permanente retornado por el backend para esta operación
          await _queueManager.markOperationStatus(opId, 'FAILED', error: errorMessage ?? 'Error de servidor');
        }
      }

      return (processed: processedCount, conflicts: conflictCount, failed: failedCount);
    } on DioException catch (e) {
      if (e.response != null) {
        debugPrint('SYNC PUSH HTTP ERROR ${e.response?.statusCode}: ${e.response?.data}');
      } else {
        debugPrint('SYNC PUSH DIO EXCEPTION: ${e.message}');
      }

      // Error temporal de red/timeout/5xx: aplicar estrategia de retry
      final isTemporary = e.type == DioExceptionType.connectionTimeout ||
          e.type == DioExceptionType.receiveTimeout ||
          e.type == DioExceptionType.connectionError ||
          (e.response?.statusCode != null && e.response!.statusCode! >= 500);

      for (final op in pendingOps) {
        if (isTemporary && op.retryCount < AppConstants.syncMaxRetries) {
          // Permanecer en PENDING con retry_count incrementado para reintento posterior
          await _queueManager.markOperationStatus(op.operationId, 'PENDING', error: e.message);
        } else {
          // Excedió reintentos o fallo permanente HTTP 400
          final errData = NetworkErrorParser.parse(e);
          await _queueManager.markOperationStatus(op.operationId, 'FAILED', error: errData);
        }
      }
      return (processed: 0, conflicts: 0, failed: pendingOps.length);
    } catch (e) {
      debugPrint('SYNC PUSH UNHANDLED ERROR: $e');
      for (final op in pendingOps) {
        await _queueManager.markOperationStatus(op.operationId, 'FAILED', error: e.toString());
      }
      return (processed: 0, conflicts: 0, failed: pendingOps.length);
    }
  }

  /// PULL — Recibir cambios del backend mediante cursor incremental (server_change_id)
  Future<int> pull() async {
    int totalChangesApplied = 0;
    bool hasMore = true;

    while (hasMore) {
      final currentCursor = await _getLastCursor();
      final response = await _dio.get('/sync/pull', queryParameters: {
        'cursor': currentCursor,
        'limit': 100,
      });

      final data = response.data['data'] ?? response.data;
      final changes = (data['changes'] as List? ?? []);
      final nextCursor = ParseUtils.toInt(data['next_cursor'], currentCursor);
      hasMore = (data['has_more'] as bool?) ?? false;

      for (final change in changes) {
        await _applyServerChange(change as Map<String, dynamic>);
        totalChangesApplied++;
      }

      // Solo avanzar el cursor tras aplicar correctamente este batch
      await _saveLastCursor(nextCursor);

      if (changes.isEmpty) break;
    }

    return totalChangesApplied;
  }

  Future<int> _getLastCursor() async {
    final entry = await (_db.select(_db.syncMetadataTable)..where((t) => t.key.equals(AppConstants.syncKeyLastCursor))).getSingleOrNull();
    if (entry == null) return 0;
    return ParseUtils.toInt(entry.value, 0);
  }

  Future<void> _saveLastCursor(int cursor) async {
    final now = DateTime.now().toUtc();
    await _db.into(_db.syncMetadataTable).insertOnConflictUpdate(
          SyncMetadataTableCompanion.insert(
            key: AppConstants.syncKeyLastCursor,
            value: cursor.toString(),
            updatedAt: now,
          ),
        );
  }

  Future<void> _updateLocalEntityStatus(String entityType, String entityId, int version, String status) async {
    switch (entityType) {
      case 'order':
        await (_db.update(_db.ordersTable)..where((t) => t.id.equals(entityId))).write(
          OrdersTableCompanion(version: Value(version), syncStatus: Value(status)),
        );
        break;
      case 'expense':
        await (_db.update(_db.expensesTable)..where((t) => t.id.equals(entityId))).write(
          ExpensesTableCompanion(version: Value(version), syncStatus: Value(status)),
        );
        break;
      case 'dish':
        await (_db.update(_db.dishesTable)..where((t) => t.id.equals(entityId))).write(
          DishesTableCompanion(version: Value(version), syncStatus: Value(status)),
        );
        break;
      case 'daily_menu':
        await (_db.update(_db.dailyMenusTable)..where((t) => t.id.equals(entityId))).write(
          DailyMenusTableCompanion(version: Value(version), syncStatus: Value(status)),
        );
        break;
      case 'expense_category':
        await (_db.update(_db.expenseCategoriesTable)..where((t) => t.id.equals(entityId))).write(
          ExpenseCategoriesTableCompanion(version: Value(version), syncStatus: Value(status)),
        );
        break;
    }
  }

  Future<void> _applyServerChange(Map<String, dynamic> change) async {
    final entityType = change['entity_type'] as String;
    final entityId = change['entity_id'] as String;
    final operation = change['operation'] as String;
    final snapshot = change['data'] as Map<String, dynamic>? ?? {};
    final version = ParseUtils.toInt(change['version'], 1);
    final now = DateTime.now().toUtc();

    switch (entityType) {
      case 'dish':
        final isDeleted = operation == 'DELETE' ||
            snapshot['deleted'] == true ||
            snapshot['deleted_at'] != null ||
            snapshot['deletedAt'] != null ||
            snapshot['active'] == false;

        if (isDeleted) {
          final deletedAt = DateTime.tryParse(snapshot['deletedAt'] ?? snapshot['deleted_at'] ?? '') ?? now;
          await (_db.update(_db.dishesTable)..where((t) => t.id.equals(entityId))).write(
            DishesTableCompanion(
              active: const Value(false),
              deletedAt: Value(deletedAt),
              version: Value(version),
              syncStatus: const Value('SYNCED'),
            ),
          );
        } else {
          await _db.into(_db.dishesTable).insertOnConflictUpdate(
                DishesTableCompanion.insert(
                  id: entityId,
                  name: snapshot['name'] ?? '',
                  description: Value(snapshot['description']),
                  price: ParseUtils.toDouble(snapshot['price']),
                  imageUrl: Value(snapshot['imageUrl'] ?? snapshot['image_url']),
                  active: const Value(true),
                  version: Value(version),
                  syncStatus: const Value('SYNCED'),
                  createdAt: DateTime.tryParse(snapshot['createdAt'] ?? snapshot['created_at'] ?? '') ?? now,
                  updatedAt: DateTime.tryParse(snapshot['updatedAt'] ?? snapshot['updated_at'] ?? '') ?? now,
                ),
              );
        }
        break;

      case 'expense_category':
        final isDeleted = operation == 'DELETE' ||
            snapshot['deleted'] == true ||
            snapshot['deleted_at'] != null ||
            snapshot['deletedAt'] != null ||
            snapshot['active'] == false;

        if (isDeleted) {
          await (_db.update(_db.expenseCategoriesTable)..where((t) => t.id.equals(entityId))).write(
            ExpenseCategoriesTableCompanion(active: const Value(false), version: Value(version), syncStatus: const Value('SYNCED')),
          );
        } else {
          await _db.into(_db.expenseCategoriesTable).insertOnConflictUpdate(
                ExpenseCategoriesTableCompanion.insert(
                  id: entityId,
                  name: snapshot['name'] ?? '',
                  active: const Value(true),
                  version: Value(version),
                  syncStatus: const Value('SYNCED'),
                  createdAt: DateTime.tryParse(snapshot['createdAt'] ?? snapshot['created_at'] ?? '') ?? now,
                  updatedAt: DateTime.tryParse(snapshot['updatedAt'] ?? snapshot['updated_at'] ?? '') ?? now,
                ),
              );
        }
        break;

      case 'expense':
        final isDeleted = operation == 'DELETE' ||
            snapshot['deleted'] == true ||
            snapshot['deleted_at'] != null ||
            snapshot['deletedAt'] != null;

        if (isDeleted) {
          final deletedAt = DateTime.tryParse(snapshot['deletedAt'] ?? snapshot['deleted_at'] ?? '') ?? now;
          await (_db.update(_db.expensesTable)..where((t) => t.id.equals(entityId))).write(
            ExpensesTableCompanion(deletedAt: Value(deletedAt), version: Value(version), syncStatus: const Value('SYNCED')),
          );
        } else {
          await _db.into(_db.expensesTable).insertOnConflictUpdate(
                ExpensesTableCompanion.insert(
                  id: entityId,
                  description: snapshot['description'] ?? '',
                  amount: ParseUtils.toDouble(snapshot['amount']),
                  categoryId: snapshot['categoryId'] ?? snapshot['category_id'] ?? '',
                  paymentMethod: snapshot['paymentMethod'] ?? snapshot['payment_method'] ?? 'CASH',
                  expenseDate: snapshot['expenseDate'] ?? snapshot['expense_date'] ?? '',
                  createdBy: snapshot['createdBy'] ?? snapshot['created_by'] ?? '',
                  version: Value(version),
                  syncStatus: const Value('SYNCED'),
                  createdAt: DateTime.tryParse(snapshot['createdAt'] ?? snapshot['created_at'] ?? '') ?? now,
                  updatedAt: DateTime.tryParse(snapshot['updatedAt'] ?? snapshot['updated_at'] ?? '') ?? now,
                ),
              );
        }
        break;

      case 'order':
        final isDeleted = operation == 'DELETE' ||
            snapshot['deleted'] == true ||
            snapshot['deleted_at'] != null ||
            snapshot['deletedAt'] != null ||
            snapshot['status'] == 'CANCELLED';

        final existingOrder = await (_db.select(_db.ordersTable)..where((t) => t.id.equals(entityId))).getSingleOrNull();

        final rawOrderNumber = snapshot['orderNumber'] ?? snapshot['order_number'];
        final orderNumber = rawOrderNumber?.toString() ?? existingOrder?.orderNumber;

        final rawCustomerName = (snapshot['customerName'] ?? snapshot['customer_name'])?.toString();
        final customerName = (rawCustomerName != null && rawCustomerName.trim().isNotEmpty)
            ? rawCustomerName.trim()
            : (existingOrder?.customerName ?? '');

        final rawLocation = snapshot['locationText'] ?? snapshot['location_text'];
        final locationText = rawLocation != null ? rawLocation.toString() : existingOrder?.locationText;

        final total = ParseUtils.toDouble(snapshot['total'], existingOrder?.total ?? 0.0);
        final paymentMethod = snapshot['paymentMethod'] ?? snapshot['payment_method'] ?? existingOrder?.paymentMethod ?? 'CASH';
        final status = isDeleted ? 'CANCELLED' : (snapshot['status'] ?? existingOrder?.status ?? 'PENDING');
        final orderedAt = DateTime.tryParse(snapshot['orderedAt'] ?? snapshot['ordered_at'] ?? '') ?? existingOrder?.orderedAt ?? now;
        final createdBy = snapshot['createdBy'] ?? snapshot['created_by'] ?? existingOrder?.createdBy ?? 'local-user';
        final createdAt = DateTime.tryParse(snapshot['createdAt'] ?? snapshot['created_at'] ?? '') ?? existingOrder?.createdAt ?? now;
        final updatedAt = DateTime.tryParse(snapshot['updatedAt'] ?? snapshot['updated_at'] ?? '') ?? now;

        await _db.into(_db.ordersTable).insertOnConflictUpdate(
              OrdersTableCompanion.insert(
                id: entityId,
                orderNumber: Value(orderNumber),
                customerName: customerName,
                locationText: Value(locationText),
                total: total,
                paymentMethod: paymentMethod,
                status: status,
                orderedAt: orderedAt,
                createdBy: createdBy,
                version: Value(version),
                syncStatus: const Value('SYNCED'),
                createdAt: createdAt,
                updatedAt: updatedAt,
              ),
            );

        // Protección de items relacionales contra snapshots parciales (ej. mutación de solo estado):
        // Solo sobrescribir/reemplazar order_items si el snapshot incluye explícitamente una lista no vacía de items.
        final rawItems = snapshot['items'];
        if (rawItems is List && rawItems.isNotEmpty) {
          await (_db.delete(_db.orderItemsTable)..where((t) => t.orderId.equals(entityId))).go();
          for (final item in rawItems) {
            if (item is Map) {
              final itemId = item['id'] as String? ?? '${entityId}_${item['dishId'] ?? item['dish_id']}';
              final qty = ParseUtils.toInt(item['quantity'], 1);
              final unitPrice = ParseUtils.toDouble(item['unitPrice'] ?? item['unit_price']);
              final subtotal = ParseUtils.toDouble(item['subtotal'], qty * unitPrice);

              await _db.into(_db.orderItemsTable).insert(
                    OrderItemsTableCompanion.insert(
                      id: itemId,
                      orderId: entityId,
                      dishId: item['dishId'] ?? item['dish_id'] ?? '',
                      dishNameSnapshot: item['dishNameSnapshot'] ?? item['dish_name_snapshot'] ?? item['dish']?['name'] ?? '',
                      quantity: qty,
                      unitPrice: unitPrice,
                      subtotal: subtotal,
                    ),
                  );
            }
          }
        }
        break;

      case 'daily_menu':
        final isDeleted = operation == 'DELETE' ||
            snapshot['deleted'] == true ||
            snapshot['deleted_at'] != null ||
            snapshot['deletedAt'] != null ||
            snapshot['active'] == false;

        final existingMenu = await (_db.select(_db.dailyMenusTable)..where((t) => t.id.equals(entityId))).getSingleOrNull();
        final menuDate = (snapshot['menuDate'] ?? snapshot['menu_date'])?.toString() ?? existingMenu?.menuDate ?? '';

        await _db.into(_db.dailyMenusTable).insertOnConflictUpdate(
              DailyMenusTableCompanion.insert(
                id: entityId,
                menuDate: menuDate,
                active: Value(!isDeleted),
                version: Value(version),
                syncStatus: const Value('SYNCED'),
                createdAt: DateTime.tryParse(snapshot['createdAt'] ?? snapshot['created_at'] ?? '') ?? existingMenu?.createdAt ?? now,
                updatedAt: DateTime.tryParse(snapshot['updatedAt'] ?? snapshot['updated_at'] ?? '') ?? now,
              ),
            );

        final rawDishes = snapshot['dishes'] ?? snapshot['dish_ids'];
        if (rawDishes is List && rawDishes.isNotEmpty) {
          await (_db.delete(_db.dailyMenuDishesTable)..where((t) => t.dailyMenuId.equals(entityId))).go();
          for (final d in rawDishes) {
            final dishId = d is Map ? (d['id'] ?? d['dish_id'] ?? '').toString() : d.toString();
            if (dishId.isNotEmpty) {
              await _db.into(_db.dailyMenuDishesTable).insert(
                    DailyMenuDishesTableCompanion.insert(
                      id: '${entityId}_$dishId',
                      dailyMenuId: entityId,
                      dishId: dishId,
                    ),
                  );
            }
          }
        }
        break;
    }
  }
}
