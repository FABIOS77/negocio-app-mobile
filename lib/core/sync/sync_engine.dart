import 'dart:convert';
import 'package:dio/dio.dart';
import 'package:drift/drift.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../config/app_constants.dart';
import '../database/app_database.dart';
import '../network/dio_client.dart';
import '../network/network_info.dart';
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
      return {
        'operation_id': op.operationId,
        'entity_type': op.entityType,
        'entity_id': op.entityId,
        'operation': op.operation,
        'payload': jsonDecode(op.payload),
        'client_timestamp': op.clientTimestamp.toIso8601String(),
        if (op.baseVersion != null) 'base_version': op.baseVersion,
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
        final serverVersion = res['server_version'] as int?;
        final errorMessage = res['error_message'] as String?;

        final matchingOp = pendingOps.cast<SyncQueueTableData?>().firstWhere(
          (o) => o?.operationId == opId,
          orElse: () => null,
        );

        if (status == 'PROCESSED' || status == 'DUPLICATE') {
          processedCount++;
          await _queueManager.markOperationStatus(opId, 'SYNCED');
          if (matchingOp != null) {
            await _updateLocalEntityStatus(matchingOp.entityType, matchingOp.entityId, serverVersion ?? 1, 'SYNCED');
          }
        } else if (status == 'CONFLICT') {
          conflictCount++;
          await _queueManager.markOperationStatus(opId, 'CONFLICT', error: errorMessage);
          if (matchingOp != null) {
            await _updateLocalEntityStatus(matchingOp.entityType, matchingOp.entityId, serverVersion ?? 1, 'CONFLICT');
          }
        } else {
          failedCount++;
          // Error permanente retornado por el backend para esta operación
          await _queueManager.markOperationStatus(opId, 'FAILED', error: errorMessage ?? 'Error de servidor');
        }
      }

      return (processed: processedCount, conflicts: conflictCount, failed: failedCount);
    } on DioException catch (e) {
      // Error temporal de red/timeout: aplicar estrategia de retry con backoff
      final isTemporary = e.type == DioExceptionType.connectionTimeout ||
          e.type == DioExceptionType.receiveTimeout ||
          e.type == DioExceptionType.connectionError ||
          (e.response?.statusCode != null && e.response!.statusCode! >= 500);

      for (final op in pendingOps) {
        if (isTemporary && op.retryCount < AppConstants.syncMaxRetries) {
          // Permanecer en PENDING con retry_count incrementado para reintento posterior
          await _queueManager.markOperationStatus(op.operationId, 'PENDING', error: e.message);
        } else {
          // Excedió reintentos o fallo permanente
          await _queueManager.markOperationStatus(op.operationId, 'FAILED', error: e.message ?? 'Fallo de envío');
        }
      }
      return (processed: 0, conflicts: 0, failed: pendingOps.length);
    } catch (e) {
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
      final nextCursor = (data['next_cursor'] as num?)?.toInt() ?? currentCursor;
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
    return int.tryParse(entry.value) ?? 0;
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
    final version = (change['version'] as num?)?.toInt() ?? 1;
    final now = DateTime.now().toUtc();

    switch (entityType) {
      case 'dish':
        if (operation == 'DELETE' || snapshot['active'] == false) {
          await (_db.update(_db.dishesTable)..where((t) => t.id.equals(entityId))).write(
            DishesTableCompanion(active: const Value(false), deletedAt: Value(now), version: Value(version), syncStatus: const Value('SYNCED')),
          );
        } else {
          await _db.into(_db.dishesTable).insertOnConflictUpdate(
                DishesTableCompanion.insert(
                  id: entityId,
                  name: snapshot['name'] ?? '',
                  description: Value(snapshot['description']),
                  price: (snapshot['price'] as num?)?.toDouble() ?? 0.0,
                  imageUrl: Value(snapshot['imageUrl'] ?? snapshot['image_url']),
                  active: Value(snapshot['active'] ?? true),
                  version: Value(version),
                  syncStatus: const Value('SYNCED'),
                  createdAt: DateTime.tryParse(snapshot['createdAt'] ?? snapshot['created_at'] ?? '') ?? now,
                  updatedAt: DateTime.tryParse(snapshot['updatedAt'] ?? snapshot['updated_at'] ?? '') ?? now,
                ),
              );
        }
        break;

      case 'expense_category':
        if (operation == 'DELETE') {
          await (_db.update(_db.expenseCategoriesTable)..where((t) => t.id.equals(entityId))).write(
            ExpenseCategoriesTableCompanion(active: const Value(false), version: Value(version), syncStatus: const Value('SYNCED')),
          );
        } else {
          await _db.into(_db.expenseCategoriesTable).insertOnConflictUpdate(
                ExpenseCategoriesTableCompanion.insert(
                  id: entityId,
                  name: snapshot['name'] ?? '',
                  active: Value(snapshot['active'] ?? true),
                  version: Value(version),
                  syncStatus: const Value('SYNCED'),
                  createdAt: DateTime.tryParse(snapshot['createdAt'] ?? snapshot['created_at'] ?? '') ?? now,
                  updatedAt: DateTime.tryParse(snapshot['updatedAt'] ?? snapshot['updated_at'] ?? '') ?? now,
                ),
              );
        }
        break;

      case 'expense':
        if (operation == 'DELETE' || snapshot['deletedAt'] != null || snapshot['deleted_at'] != null) {
          await (_db.update(_db.expensesTable)..where((t) => t.id.equals(entityId))).write(
            ExpensesTableCompanion(deletedAt: Value(now), version: Value(version), syncStatus: const Value('SYNCED')),
          );
        } else {
          await _db.into(_db.expensesTable).insertOnConflictUpdate(
                ExpensesTableCompanion.insert(
                  id: entityId,
                  description: snapshot['description'] ?? '',
                  amount: (snapshot['amount'] as num?)?.toDouble() ?? 0.0,
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
        final orderNumber = snapshot['orderNumber'] ?? snapshot['order_number'];
        await _db.into(_db.ordersTable).insertOnConflictUpdate(
              OrdersTableCompanion.insert(
                id: entityId,
                orderNumber: Value(orderNumber),
                customerName: snapshot['customerName'] ?? snapshot['customer_name'] ?? '',
                locationText: Value(snapshot['locationText'] ?? snapshot['location_text']),
                total: (snapshot['total'] as num?)?.toDouble() ?? 0.0,
                paymentMethod: snapshot['paymentMethod'] ?? snapshot['payment_method'] ?? 'CASH',
                status: snapshot['status'] ?? 'PENDING',
                orderedAt: DateTime.tryParse(snapshot['orderedAt'] ?? snapshot['ordered_at'] ?? '') ?? now,
                createdBy: snapshot['createdBy'] ?? snapshot['created_by'] ?? '',
                version: Value(version),
                syncStatus: const Value('SYNCED'),
                createdAt: DateTime.tryParse(snapshot['createdAt'] ?? snapshot['created_at'] ?? '') ?? now,
                updatedAt: DateTime.tryParse(snapshot['updatedAt'] ?? snapshot['updated_at'] ?? '') ?? now,
              ),
            );

        final items = (snapshot['items'] as List? ?? []);
        if (items.isNotEmpty) {
          await (_db.delete(_db.orderItemsTable)..where((t) => t.orderId.equals(entityId))).go();
          for (final item in items) {
            final itemId = item['id'] as String? ?? '${entityId}_${item['dishId'] ?? item['dish_id']}';
            await _db.into(_db.orderItemsTable).insert(
                  OrderItemsTableCompanion.insert(
                    id: itemId,
                    orderId: entityId,
                    dishId: item['dishId'] ?? item['dish_id'] ?? '',
                    dishNameSnapshot: item['dishNameSnapshot'] ?? item['dish_name_snapshot'] ?? item['dish']?['name'] ?? '',
                    quantity: (item['quantity'] as num?)?.toInt() ?? 1,
                    unitPrice: (item['unitPrice'] as num?)?.toDouble() ?? (item['unit_price'] as num?)?.toDouble() ?? 0.0,
                    subtotal: (item['subtotal'] as num?)?.toDouble() ?? 0.0,
                  ),
                );
          }
        }
        break;

      case 'daily_menu':
        final menuDate = snapshot['menuDate'] ?? snapshot['menu_date'] ?? '';
        await _db.into(_db.dailyMenusTable).insertOnConflictUpdate(
              DailyMenusTableCompanion.insert(
                id: entityId,
                menuDate: menuDate,
                active: Value(snapshot['active'] ?? true),
                version: Value(version),
                syncStatus: const Value('SYNCED'),
                createdAt: DateTime.tryParse(snapshot['createdAt'] ?? snapshot['created_at'] ?? '') ?? now,
                updatedAt: DateTime.tryParse(snapshot['updatedAt'] ?? snapshot['updated_at'] ?? '') ?? now,
              ),
            );

        final dishes = (snapshot['dishes'] as List? ?? []);
        if (dishes.isNotEmpty) {
          await (_db.delete(_db.dailyMenuDishesTable)..where((t) => t.dailyMenuId.equals(entityId))).go();
          for (final d in dishes) {
            final dishId = d['id'] as String? ?? d as String;
            await _db.into(_db.dailyMenuDishesTable).insert(
                  DailyMenuDishesTableCompanion.insert(
                    id: '${entityId}_$dishId',
                    dailyMenuId: entityId,
                    dishId: dishId,
                  ),
                );
          }
        }
        break;
    }
  }
}
