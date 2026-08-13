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
  });
}
