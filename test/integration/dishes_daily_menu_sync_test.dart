import 'package:dio/dio.dart';
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

import 'package:katering_grecia_app/core/database/app_database.dart';
import 'package:katering_grecia_app/core/network/network_info.dart';
import 'package:katering_grecia_app/core/sync/sync_engine.dart';
import 'package:katering_grecia_app/core/sync/sync_queue_manager.dart';
import 'package:katering_grecia_app/features/daily_menu/data/daily_menu_repository.dart';
import 'package:katering_grecia_app/features/dishes/data/dishes_repository.dart';

class MockDio extends Mock implements Dio {}
class MockNetworkInfo extends Mock implements NetworkInfo {}

void main() {
  late AppDatabase db;
  late SyncQueueManager queueManager;
  late MockDio mockDio;
  late MockNetworkInfo mockNetworkInfo;
  late SyncEngine syncEngine;
  late DishesRepository dishesRepo;
  late DailyMenuRepository menuRepo;

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

    dishesRepo = DishesRepository(
      db: db,
      queueManager: queueManager,
      syncEngine: syncEngine,
    );

    menuRepo = DailyMenuRepository(
      db: db,
      queueManager: queueManager,
      syncEngine: syncEngine,
    );

    when(() => mockNetworkInfo.isConnected).thenAnswer((_) async => true);
  });

  tearDown(() async {
    await db.close();
  });

  group('Dishes & Daily Menu Sync Integration Tests', () {
    test('Create dish offline and push to backend successfully', () async {
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
                  'server_version': 1,
                  'server_change_id': 100,
                }
              ]
            }
          },
        ),
      );

      final dish = await dishesRepo.createDish(name: 'Pique Macho', price: 40.0);
      expect(dish.name, equals('Pique Macho'));

      // Esperar a que syncAll() procese la cola
      await syncEngine.syncAll();

      final pendingAfter = await queueManager.getPendingOperations();
      expect(pendingAfter.isEmpty, isTrue);
    });

    test('Pull daily menu change from backend and store in SQLite', () async {
      when(() => mockDio.get('/sync/pull', queryParameters: any(named: 'queryParameters'))).thenAnswer(
        (_) async => Response(
          requestOptions: RequestOptions(path: '/sync/pull'),
          statusCode: 200,
          data: {
            'success': true,
            'data': {
              'changes': [
                {
                  'server_change_id': 120,
                  'entity_type': 'daily_menu',
                  'entity_id': 'menu-uuid-2026-08-13',
                  'operation': 'CREATE',
                  'data': {
                    'menu_date': '2026-08-13',
                    'active': true,
                    'dishes': [],
                  },
                  'version': 1,
                }
              ],
              'next_cursor': 120,
              'has_more': false,
            }
          },
        ),
      );

      final count = await syncEngine.pull();
      expect(count, equals(1));

      final menu = await menuRepo.watchMenuByDate('2026-08-13').first;
      expect(menu, isNotNull);
      expect(menu!.menuDate, equals('2026-08-13'));
    });
  });
}
