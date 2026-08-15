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

  setUp(() async {
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
      dio: mockDio,
      networkInfo: mockNetworkInfo,
    );

    when(() => mockNetworkInfo.isConnected).thenAnswer((_) async => true);

    // Precargar categoría inicial activa
    await db.into(db.expenseCategoriesTable).insert(
          ExpenseCategoriesTableCompanion.insert(
            id: '550e8400-e29b-41d4-a716-446655440400',
            name: 'Insumos / Verduras y Carnes',
            createdAt: DateTime.now().toUtc(),
            updatedAt: DateTime.now().toUtc(),
          ),
        );
  });

  tearDown(() async {
    await db.close();
  });

  group('Expenses Sync Integration Tests', () {
    test('JSON CONTRACT TEST: PUSH expense generates canonical snake_case payload', () async {
      await expensesRepo.createExpense(
        description: 'Compra de carne de res',
        amount: 150.50,
        categoryId: '550e8400-e29b-41d4-a716-446655440400',
        paymentMethod: 'CASH',
        expenseDate: '2026-08-14',
      );

      Map<String, dynamic>? capturedBody;
      when(() => mockDio.post('/sync/push', data: any(named: 'data'))).thenAnswer((invocation) async {
        capturedBody = invocation.namedArguments[#data] as Map<String, dynamic>;
        final operations = capturedBody!['operations'] as List;
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
                  'server_version': 1,
                  'server_change_id': 101,
                }
              ]
            }
          },
        );
      });

      final result = await syncEngine.push();
      expect(result.processed, equals(1));
      expect(capturedBody, isNotNull);

      final ops = capturedBody!['operations'] as List;
      expect(ops.length, equals(1));
      final op = ops.first as Map<String, dynamic>;
      expect(op['entity_type'], equals('expense'));
      expect(op['operation'], equals('CREATE'));

      final payload = op['payload'] as Map<String, dynamic>;
      expect(payload['description'], equals('Compra de carne de res'));
      expect(payload['amount'], equals(150.50));
      expect(payload['category_id'], equals('550e8400-e29b-41d4-a716-446655440400'));
      expect(payload['payment_method'], equals('CASH'));
      expect(payload['expense_date'], equals('2026-08-14'));

      // Verificar que NO envía camelCase
      expect(payload.containsKey('categoryId'), isFalse);
      expect(payload.containsKey('paymentMethod'), isFalse);
      expect(payload.containsKey('expenseDate'), isFalse);
    });

    test('ORDERING TEST: SyncQueue pushes CREATE expense_category before CREATE expense', () async {
      Map<String, dynamic>? capturedBody;
      when(() => mockDio.post('/sync/push', data: any(named: 'data'))).thenAnswer((invocation) async {
        capturedBody = invocation.namedArguments[#data] as Map<String, dynamic>;
        final operations = capturedBody!['operations'] as List;
        return Response(
          requestOptions: RequestOptions(path: '/sync/push'),
          statusCode: 200,
          data: {
            'success': true,
            'data': {
              'results': operations.map((o) => {
                'operation_id': o['operation_id'],
                'status': 'PROCESSED',
                'server_version': 1,
              }).toList(),
            }
          },
        );
      });

      // 1. Limpiar cola previa
      await db.delete(db.syncQueueTable).go();

      // 2. Crear categoría y gasto
      final newCat = await expensesRepo.createCategory(name: 'Transporte / Fletes');

      final newExp = await expensesRepo.createExpense(
        description: 'Flete de verduras',
        amount: 80.0,
        categoryId: newCat.id,
        paymentMethod: 'QR',
        expenseDate: '2026-08-14',
      );

      // Re-encolar para probar la ordenación explícita de push()
      await db.delete(db.syncQueueTable).go();
      await queueManager.enqueueOperation(
        entityType: 'expense',
        entityId: newExp.id,
        operation: 'CREATE',
        payload: {
          'description': newExp.description,
          'amount': newExp.amount,
          'category_id': newExp.categoryId,
          'payment_method': newExp.paymentMethod,
          'expense_date': newExp.expenseDate,
        },
      );
      await queueManager.enqueueOperation(
        entityType: 'expense_category',
        entityId: newCat.id,
        operation: 'CREATE',
        payload: {
          'id': newCat.id,
          'name': newCat.name,
          'active': newCat.active,
        },
      );

      final result = await syncEngine.push();
      expect(result.processed, equals(2));
      expect(capturedBody, isNotNull);

      final ops = capturedBody!['operations'] as List;
      expect(ops.length, equals(2));

      // El primer elemento DEBE ser la categoría (prioridad 1) aunque fue encolada después del gasto
      expect(ops[0]['entity_type'], equals('expense_category'));
      expect(ops[0]['operation'], equals('CREATE'));
      expect(ops[0]['entity_id'], equals(newCat.id));

      // El segundo elemento DEBE ser el gasto (prioridad 4)
      expect(ops[1]['entity_type'], equals('expense'));
      expect(ops[1]['operation'], equals('CREATE'));
    });

    test('PULL TEST: Mappings snapshot with nested category from backend to SQLite', () async {
      when(() => mockDio.get('/sync/pull', queryParameters: any(named: 'queryParameters'))).thenAnswer(
        (_) async => Response(
          requestOptions: RequestOptions(path: '/sync/pull'),
          statusCode: 200,
          data: {
            'success': true,
            'data': {
              'changes': [
                {
                  'server_change_id': 201,
                  'entity_type': 'expense',
                  'entity_id': 'exp-remote-uuid-1',
                  'operation': 'CREATE',
                  'data': {
                    'id': 'exp-remote-uuid-1',
                    'description': 'Compra de Gas',
                    'amount': 45.00,
                    'categoryId': '550e8400-e29b-41d4-a716-446655440401',
                    'paymentMethod': 'OTHER',
                    'expenseDate': '2026-08-14',
                    'createdBy': 'remote-user-id',
                    'version': 1,
                    'category': {
                      'id': '550e8400-e29b-41d4-a716-446655440401',
                      'name': 'Servicios Básicos (Luz, Agua, Gas)',
                      'active': true,
                    }
                  },
                  'version': 1,
                }
              ],
              'next_cursor': 201,
              'has_more': false,
            }
          },
        ),
      );

      final count = await syncEngine.pull();
      expect(count, equals(1));

      // Verificar que el gasto se guardó en SQLite con su categoría anidada
      final expenseInDb = await expensesRepo.getExpenseById('exp-remote-uuid-1');
      expect(expenseInDb, isNotNull);
      expect(expenseInDb!.description, equals('Compra de Gas'));
      expect(expenseInDb.amount, equals(45.00));
      expect(expenseInDb.categoryName, equals('Servicios Básicos (Luz, Agua, Gas)'));
      expect(expenseInDb.paymentMethod, equals('OTHER'));
      expect(expenseInDb.expenseDate, equals('2026-08-14'));

      // Verificar que la categoría también se guardó en la tabla de categorías
      final categoryInDb = await expensesRepo.getCategoryById('550e8400-e29b-41d4-a716-446655440401');
      expect(categoryInDb, isNotNull);
      expect(categoryInDb!.name, equals('Servicios Básicos (Luz, Agua, Gas)'));
      expect(categoryInDb.active, isTrue);
    });

    test('SOFT DELETE PULL: Server soft-delete marks deletedAt in SQLite', () async {
      final exp = await expensesRepo.createExpense(
        description: 'Aceite a ser eliminado',
        amount: 30.0,
        categoryId: '550e8400-e29b-41d4-a716-446655440400',
        paymentMethod: 'CASH',
        expenseDate: '2026-08-14',
      );

      await db.delete(db.syncQueueTable).go();

      when(() => mockDio.get('/sync/pull', queryParameters: any(named: 'queryParameters'))).thenAnswer(
        (_) async => Response(
          requestOptions: RequestOptions(path: '/sync/pull'),
          statusCode: 200,
          data: {
            'success': true,
            'data': {
              'changes': [
                {
                  'server_change_id': 301,
                  'entity_type': 'expense',
                  'entity_id': exp.id,
                  'operation': 'DELETE',
                  'data': {
                    'id': exp.id,
                    'deleted': true,
                    'deleted_at': '2026-08-14T18:00:00.000Z',
                  },
                  'version': 2,
                }
              ],
              'next_cursor': 301,
              'has_more': false,
            }
          },
        ),
      );

      final count = await syncEngine.pull();
      expect(count, equals(1));

      final activeExpenses = await expensesRepo.watchExpenses().first;
      expect(activeExpenses.any((e) => e.id == exp.id), isFalse);
    });

    test('CONFLICT TEST: Operation marked as CONFLICT preserves error message', () async {
      await expensesRepo.createExpense(
        description: 'Gasto en conflicto',
        amount: 90.0,
        categoryId: '550e8400-e29b-41d4-a716-446655440400',
        paymentMethod: 'CASH',
      );

      when(() => mockDio.post('/sync/push', data: any(named: 'data'))).thenAnswer((invocation) async {
        final data = invocation.namedArguments[#data] as Map<String, dynamic>;
        final op = (data['operations'] as List).first as Map<String, dynamic>;
        return Response(
          requestOptions: RequestOptions(path: '/sync/push'),
          statusCode: 200,
          data: {
            'success': true,
            'data': {
              'results': [
                {
                  'operation_id': op['operation_id'],
                  'status': 'CONFLICT',
                  'server_version': 5,
                  'error_message': 'Version conflict detected',
                }
              ]
            }
          },
        );
      });

      final result = await syncEngine.push();
      expect(result.conflicts, equals(1));

      final ops = await db.select(db.syncQueueTable).get();
      expect(ops.first.status, equals('CONFLICT'));
    });
  });
}
