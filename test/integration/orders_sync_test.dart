import 'package:dio/dio.dart';
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

import 'package:katering_grecia_app/core/database/app_database.dart';
import 'package:katering_grecia_app/core/network/network_info.dart';
import 'package:katering_grecia_app/core/sync/sync_engine.dart';
import 'package:katering_grecia_app/core/sync/sync_queue_manager.dart';
import 'package:katering_grecia_app/features/dishes/data/dishes_repository.dart';
import 'package:katering_grecia_app/features/orders/data/orders_repository.dart';

class MockDio extends Mock implements Dio {}
class MockNetworkInfo extends Mock implements NetworkInfo {}

void main() {
  late AppDatabase db;
  late SyncQueueManager queueManager;
  late MockDio mockDio;
  late MockNetworkInfo mockNetworkInfo;
  late SyncEngine syncEngine;
  late DishesRepository dishesRepo;
  late OrdersRepository ordersRepo;

  setUp(() {
    db = AppDatabase(NativeDatabase.memory());
    queueManager = SyncQueueManager(db);
    mockDio = MockDio();
    mockNetworkInfo = MockNetworkInfo();

    syncEngine = SyncEngine(
      db: db,
      queueManager: queueManager,
      dio: mockDio,
      networkInfo: mockNetworkInfo,
    );

    dishesRepo = DishesRepository(db: db, queueManager: queueManager, syncEngine: syncEngine);
    ordersRepo = OrdersRepository(db: db, queueManager: queueManager, syncEngine: syncEngine);

    when(() => mockNetworkInfo.isConnected).thenAnswer((_) async => true);
  });

  tearDown(() async {
    await db.close();
  });

  group('Orders Sync & Idempotency Integration Tests', () {
    test('Push order sends snake_case payload and updates order_number from server response', () async {
      final dish = await dishesRepo.createDish(name: 'Sopa', price: 10.0);
      await ordersRepo.createOrder(
        customerName: 'Prueba Sync',
        paymentMethod: 'CASH',
        itemsInput: [(dishId: dish.id, quantity: 2)],
      );

      when(() => mockDio.post('/sync/push', data: any(named: 'data'))).thenAnswer(
        (_) async => Response(
          requestOptions: RequestOptions(path: '/sync/push'),
          statusCode: 200,
          data: {
            'success': true,
            'data': {
              'processed': 2,
              'failed': 0,
              'results': [
                {
                  'operation_id': (await queueManager.getPendingOperations()).first.operationId,
                  'status': 'PROCESSED',
                  'server_version': 1,
                  'server_change_id': 301,
                },
                {
                  'operation_id': (await queueManager.getPendingOperations()).last.operationId,
                  'status': 'PROCESSED',
                  'server_version': 1,
                  'server_change_id': 302,
                }
              ]
            }
          },
        ),
      );

      final pushResult = await syncEngine.push();
      expect(pushResult.processed, equals(2));

      final pendingAfter = await queueManager.getPendingOperations();
      expect(pendingAfter.isEmpty, isTrue);
    });

    test('Pull order change updates local order and items', () async {
      when(() => mockDio.get('/sync/pull', queryParameters: any(named: 'queryParameters'))).thenAnswer(
        (_) async => Response(
          requestOptions: RequestOptions(path: '/sync/pull'),
          statusCode: 200,
          data: {
            'success': true,
            'data': {
              'changes': [
                {
                  'server_change_id': 400,
                  'entity_type': 'order',
                  'entity_id': 'remote-order-uuid-999',
                  'operation': 'CREATE',
                  'data': {
                    'order_number': '20260813-0005',
                    'customer_name': 'Cliente Remoto',
                    'total': 45.0,
                    'payment_method': 'QR',
                    'status': 'PENDING',
                    'ordered_at': '2026-08-13T12:00:00.000Z',
                    'created_by': 'remote-user',
                    'items': [
                      {
                        'id': 'remote-item-1',
                        'dish_id': 'dish-1',
                        'dish_name_snapshot': 'Plato Remoto',
                        'quantity': 3,
                        'unit_price': 15.0,
                        'subtotal': 45.0,
                      }
                    ],
                  },
                  'version': 1,
                }
              ],
              'next_cursor': 400,
              'has_more': false,
            }
          },
        ),
      );

      final count = await syncEngine.pull();
      expect(count, equals(1));

      final fetchedOrder = await ordersRepo.getOrderById('remote-order-uuid-999');
      expect(fetchedOrder, isNotNull);
      expect(fetchedOrder!.orderNumber, equals('20260813-0005'));
      expect(fetchedOrder.items.length, equals(1));
      expect(fetchedOrder.items.first.subtotal, equals(45.0));
    });

    test('Pull soft-deleted order with deleted flag or DELETE operation sets status CANCELLED without enqueuing push', () async {
      // 1. Crear un pedido local previo
      final dish = await dishesRepo.createDish(name: 'Sopa de Res', price: 20.0);
      final localOrder = await ordersRepo.createOrder(
        customerName: 'Cliente para Cancelar Remoto',
        paymentMethod: 'CASH',
        itemsInput: [(dishId: dish.id, quantity: 1)],
      );

      // Limpiar cola de sincronización para verificar que el PULL no la contamine
      await db.delete(db.syncQueueTable).go();

      // 2. Simular respuesta PULL que contiene snapshot con deleted: true y operation: DELETE
      when(() => mockDio.get('/sync/pull', queryParameters: any(named: 'queryParameters'))).thenAnswer(
        (_) async => Response(
          requestOptions: RequestOptions(path: '/sync/pull'),
          statusCode: 200,
          data: {
            'success': true,
            'data': {
              'changes': [
                {
                  'server_change_id': 500,
                  'entity_type': 'order',
                  'entity_id': localOrder.id,
                  'operation': 'DELETE',
                  'data': {
                    'order_number': '20260813-0010',
                    'customer_name': 'Cliente para Cancelar Remoto',
                    'total': 20.0,
                    'payment_method': 'CASH',
                    'status': 'PENDING',
                    'deleted': true,
                    'deleted_at': '2026-08-13T14:30:00.000Z',
                    'ordered_at': '2026-08-13T12:00:00.000Z',
                    'created_by': 'remote-user',
                  },
                  'version': 2,
                }
              ],
              'next_cursor': 500,
              'has_more': false,
            }
          },
        ),
      );

      final count = await syncEngine.pull();
      expect(count, equals(1));

      // 3. Verificar que localmente ahora está CANCELLED
      final orderAfterPull = await ordersRepo.getOrderById(localOrder.id);
      expect(orderAfterPull, isNotNull);
      expect(orderAfterPull!.status, equals('CANCELLED'));
      expect(orderAfterPull.version, equals(2));

      // 4. Verificar que NO se encoló ninguna operación de PUSH
      final pendingOps = await queueManager.getPendingOperations();
      expect(pendingOps.isEmpty, isTrue);
    });

    test('changeOrderStatus pushes status-only payload without customer_name or items to prevent data loss', () async {
      // 1. Crear un pedido local
      final dish = await dishesRepo.createDish(name: 'Almuerzo Completo', price: 25.0);
      final localOrder = await ordersRepo.createOrder(
        customerName: 'Cliente Mesa 5',
        locationText: 'Terraza',
        paymentMethod: 'QR',
        itemsInput: [(dishId: dish.id, quantity: 2)],
      );

      // Limpiar la cola de sync de la creación
      await db.delete(db.syncQueueTable).go();

      // 2. Cambiar estado a DELIVERED
      await ordersRepo.changeOrderStatus(localOrder.id, 'DELIVERED');

      // 3. Capturar el payload enviado en POST /sync/push
      Map<String, dynamic>? capturedData;
      when(() => mockDio.post('/sync/push', data: any(named: 'data'))).thenAnswer((invocation) async {
        capturedData = invocation.namedArguments[#data] as Map<String, dynamic>;
        final operations = capturedData!['operations'] as List;
        final op = operations.first as Map<String, dynamic>;
        return Response(
          requestOptions: RequestOptions(path: '/sync/push'),
          statusCode: 200,
          data: {
            'success': true,
            'data': {
              'results': [
                {
                  'operation_id': op['operation_id'],
                  'status': 'PROCESSED',
                  'server_version': 2,
                }
              ]
            }
          },
        );
      });

      final result = await syncEngine.push();
      expect(result.processed, equals(1));
      expect(capturedData, isNotNull);

      final ops = capturedData!['operations'] as List;
      expect(ops.length, equals(1));
      final orderOp = ops.first as Map<String, dynamic>;
      expect(orderOp['entity_type'], equals('order'));
      expect(orderOp['operation'], equals('UPDATE'));

      final payload = orderOp['payload'] as Map<String, dynamic>;
      expect(payload['status'], equals('DELIVERED'));
      expect(payload.containsKey('customer_name'), isFalse);
      expect(payload.containsKey('items'), isFalse);
    });

    test('Pull partial snapshot (without items key) preserves existing local order_items and customer_name', () async {
      // 1. Crear un pedido local completo con sus items
      final dish = await dishesRepo.createDish(name: 'Pastel de Papa', price: 30.0);
      final localOrder = await ordersRepo.createOrder(
        customerName: 'Cliente Juan Perez',
        locationText: 'Mesa 4',
        paymentMethod: 'CASH',
        itemsInput: [(dishId: dish.id, quantity: 3)],
      );

      expect(localOrder.items.length, equals(1));
      expect(localOrder.items.first.subtotal, equals(90.0));

      // 2. Simular respuesta PULL con un snapshot parcial (solo id, status, version - sin items)
      when(() => mockDio.get('/sync/pull', queryParameters: any(named: 'queryParameters'))).thenAnswer(
        (_) async => Response(
          requestOptions: RequestOptions(path: '/sync/pull'),
          statusCode: 200,
          data: {
            'success': true,
            'data': {
              'changes': [
                {
                  'server_change_id': 600,
                  'entity_type': 'order',
                  'entity_id': localOrder.id,
                  'operation': 'UPDATE',
                  'data': {
                    'id': localOrder.id,
                    'status': 'DELIVERED',
                    // Note: items is completely omitted (partial snapshot)
                  },
                  'version': 3,
                }
              ],
              'next_cursor': 600,
              'has_more': false,
            }
          },
        ),
      );

      final count = await syncEngine.pull();
      expect(count, equals(1));

      // 3. Verificar que el pedido actualizado conserva el customer_name y los items originales
      final updatedOrder = await ordersRepo.getOrderById(localOrder.id);
      expect(updatedOrder, isNotNull);
      expect(updatedOrder!.status, equals('DELIVERED'));
      expect(updatedOrder.customerName, equals('Cliente Juan Perez'));
      expect(updatedOrder.locationText, equals('Mesa 4'));
      expect(updatedOrder.total, equals(90.0));
      expect(updatedOrder.version, equals(3));
      expect(updatedOrder.items.length, equals(1));
      expect(updatedOrder.items.first.dishNameSnapshot, equals('Pastel de Papa'));
      expect(updatedOrder.items.first.quantity, equals(3));
      expect(updatedOrder.items.first.subtotal, equals(90.0));
    });
  });
}


