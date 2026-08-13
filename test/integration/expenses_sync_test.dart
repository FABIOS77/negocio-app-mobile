import 'package:dio/dio.dart';
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

import 'package:katering_grecia_app/core/database/app_database.dart';
import 'package:katering_grecia_app/core/network/network_info.dart';
import 'package:katering_grecia_app/core/sync/sync_engine.dart';
import 'package:katering_grecia_app/core/sync/sync_queue_manager.dart';
import 'package:katering_grecia_app/features/expenses/data/expenses_repository.dart';

class MockDio extends Mock implements Dio {}
class MockNetworkInfo extends Mock implements NetworkInfo {}

void main() {
  late AppDatabase db;
  late SyncQueueManager queueManager;
  late MockDio mockDio;
  late MockNetworkInfo mockNetworkInfo;
  late SyncEngine syncEngine;
  late ExpensesRepository expensesRepo;

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

    expensesRepo = ExpensesRepository(
      db: db,
      queueManager: queueManager,
      syncEngine: syncEngine,
    );

    when(() => mockNetworkInfo.isConnected).thenAnswer((_) async => true);
  });

  tearDown(() async {
    await db.close();
  });

  group('Expenses Sync Integration Tests', () {
    test('Push expense sends snake_case payload to backend', () async {
      await expensesRepo.createExpense(
        description: 'Compra de aceite',
        amount: 80.0,
        categoryId: 'cat-insumos-1',
        paymentMethod: 'CASH',
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
                  'server_version': 1,
                  'server_change_id': 500,
                }
              ]
            }
          },
        ),
      );

      final result = await syncEngine.push();
      expect(result.processed, equals(1));

      final pendingAfter = await queueManager.getPendingOperations();
      expect(pendingAfter.isEmpty, isTrue);
    });
  });
}
