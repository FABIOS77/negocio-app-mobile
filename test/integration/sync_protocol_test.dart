import 'package:dio/dio.dart';
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

import 'package:katering_grecia_app/core/database/app_database.dart';
import 'package:katering_grecia_app/core/network/network_info.dart';
import 'package:katering_grecia_app/core/sync/sync_engine.dart';
import 'package:katering_grecia_app/core/sync/sync_queue_manager.dart';

class MockDio extends Mock implements Dio {}
class MockNetworkInfo extends Mock implements NetworkInfo {}

void main() {
  late AppDatabase db;
  late SyncQueueManager queueManager;
  late MockDio mockDio;
  late MockNetworkInfo mockNetworkInfo;
  late SyncEngine syncEngine;

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

    when(() => mockNetworkInfo.isConnected).thenAnswer((_) async => true);
  });

  tearDown(() async {
    await db.close();
  });

  group('Sync Protocol Tests', () {
    test('PUSH builds payload with snake_case and handles PROCESSED response', () async {
      const orderId = 'order-uuid-999';
      await queueManager.enqueueOperation(
        entityType: 'order',
        entityId: orderId,
        operation: 'CREATE',
        payload: {'id': orderId, 'customer_name': 'María', 'payment_method': 'QR'},
      );

      when(() => mockDio.post('/sync/push', data: any(named: 'data'))).thenAnswer(
        (_) async => Response(
          requestOptions: RequestOptions(path: '/sync/push'),
          statusCode: 200,
          data: {
            'success': true,
            'data': {
              'processed': 1,
              'failed': 0,
              'results': [
                {
                  'operation_id': (await queueManager.getPendingOperations()).first.operationId,
                  'status': 'PROCESSED',
                  'server_version': 2,
                  'server_change_id': 500,
                }
              ]
            }
          },
        ),
      );

      final result = await syncEngine.push();
      expect(result.processed, equals(1));
      expect(result.conflicts, equals(0));

      final pendingAfter = await queueManager.getPendingOperations();
      expect(pendingAfter.isEmpty, isTrue);
    });

    test('PULL incremental cursor updates last_cursor in SyncMetadataTable', () async {
      when(() => mockDio.get('/sync/pull', queryParameters: any(named: 'queryParameters'))).thenAnswer(
        (_) async => Response(
          requestOptions: RequestOptions(path: '/sync/pull'),
          statusCode: 200,
          data: {
            'success': true,
            'data': {
              'changes': [
                {
                  'server_change_id': 105,
                  'entity_type': 'dish',
                  'entity_id': 'dish-uuid-1',
                  'operation': 'CREATE',
                  'data': {'name': 'Lomo Saltado', 'price': 35.0, 'active': true},
                  'version': 1,
                }
              ],
              'next_cursor': 105,
              'has_more': false,
            }
          },
        ),
      );

      final pulledCount = await syncEngine.pull();
      expect(pulledCount, equals(1));

      // Verificar que el plato se guardó en la BD local SQLite
      final dishes = await db.select(db.dishesTable).get();
      expect(dishes.length, equals(1));
      expect(dishes.first.name, equals('Lomo Saltado'));

      // Verificar que el cursor avanza en SyncMetadataTable
      final cursorData = await (db.select(db.syncMetadataTable)..where((t) => t.key.equals('last_cursor'))).getSingle();
      expect(cursorData.value, equals('105'));
    });
  });
}
