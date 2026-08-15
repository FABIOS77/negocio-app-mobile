import 'dart:io';
import 'package:dio/dio.dart';
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:path/path.dart' as p;

import 'package:katering_grecia_app/core/database/app_database.dart';
import 'package:katering_grecia_app/core/network/network_info.dart';
import 'package:katering_grecia_app/core/sync/sync_engine.dart';
import 'package:katering_grecia_app/core/sync/sync_queue_manager.dart';
import 'package:katering_grecia_app/features/expenses/data/expenses_repository.dart';

class MockDio extends Mock implements Dio {}
class MockNetworkInfo extends Mock implements NetworkInfo {}
class MockSyncEngine extends Mock implements SyncEngine {}

void main() {
  late AppDatabase db;
  late SyncQueueManager queueManager;
  late MockDio mockDio;
  late MockNetworkInfo mockNetworkInfo;
  late MockSyncEngine mockSyncEngine;
  late ExpensesRepository repository;

  final canonical5Categories = [
    {
      'id': '550e8400-e29b-41d4-a716-446655440400',
      'name': 'Insumos / Verduras y Carnes',
      'active': true,
      'version': 1,
      'createdAt': '2026-08-10T10:00:00.000Z',
      'updatedAt': '2026-08-10T10:00:00.000Z',
    },
    {
      'id': '550e8400-e29b-41d4-a716-446655440401',
      'name': 'Servicios Básicos (Luz, Agua, Gas)',
      'active': true,
      'version': 1,
      'createdAt': '2026-08-10T10:00:00.000Z',
      'updatedAt': '2026-08-10T10:00:00.000Z',
    },
    {
      'id': '550e8400-e29b-41d4-a716-446655440402',
      'name': 'Personal / Sueldos',
      'active': true,
      'version': 1,
      'createdAt': '2026-08-10T10:00:00.000Z',
      'updatedAt': '2026-08-10T10:00:00.000Z',
    },
    {
      'id': '550e8400-e29b-41d4-a716-446655440403',
      'name': 'Equipamiento y Utensilios',
      'active': true,
      'version': 1,
      'createdAt': '2026-08-10T10:00:00.000Z',
      'updatedAt': '2026-08-10T10:00:00.000Z',
    },
    {
      'id': '550e8400-e29b-41d4-a716-446655440404',
      'name': 'Otros Gastos Operativos',
      'active': true,
      'version': 1,
      'createdAt': '2026-08-10T10:00:00.000Z',
      'updatedAt': '2026-08-10T10:00:00.000Z',
    },
  ];

  setUp(() {
    db = AppDatabase(NativeDatabase.memory());
    queueManager = SyncQueueManager(db);
    mockDio = MockDio();
    mockNetworkInfo = MockNetworkInfo();
    mockSyncEngine = MockSyncEngine();

    when(() => mockNetworkInfo.isConnected).thenAnswer((_) async => true);
    when(() => mockSyncEngine.syncAll()).thenAnswer((_) async => SyncResult(
          pushedCount: 0,
          pulledCount: 0,
          conflictCount: 0,
          errorCount: 0,
        ));

    repository = ExpensesRepository(
      db: db,
      queueManager: queueManager,
      syncEngine: mockSyncEngine,
      dio: mockDio,
      networkInfo: mockNetworkInfo,
    );
  });

  tearDown(() async {
    await db.close();
  });

  group('Expense Categories Initial Sync & Offline-First Tests', () {
    test('1 & 2 & 3. Backend devuelve 5 categorías -> se insertan en SQLite -> stream muestra las 5 con IDs del backend', () async {
      when(() => mockDio.get('/expenses/categories')).thenAnswer(
        (_) async => Response(
          requestOptions: RequestOptions(path: '/expenses/categories'),
          statusCode: 200,
          data: {
            'success': true,
            'data': canonical5Categories,
          },
        ),
      );

      final cached = await repository.fetchAndCacheCategories();
      expect(cached.length, equals(5));

      final streamList = await repository.watchCategories().first;
      expect(streamList.length, equals(5));
      expect(streamList.map((c) => c.name), containsAll([
        'Insumos / Verduras y Carnes',
        'Servicios Básicos (Luz, Agua, Gas)',
        'Personal / Sueldos',
        'Equipamiento y Utensilios',
        'Otros Gastos Operativos',
      ]));

      expect(streamList.firstWhere((c) => c.name == 'Insumos / Verduras y Carnes').id, equals('550e8400-e29b-41d4-a716-446655440400'));
    });

    test('4 & 5. Reinicio de app conserva categorías en SQLite y selector offline funciona sin HTTP', () async {
      final tempDir = Directory.systemTemp.createTempSync('katering_cat_restart_');
      final dbFile = File(p.join(tempDir.path, 'cat_restart.sqlite'));

      try {
        final db1 = AppDatabase(NativeDatabase(dbFile));
        final queue1 = SyncQueueManager(db1);
        final repo1 = ExpensesRepository(
          db: db1,
          queueManager: queue1,
          syncEngine: mockSyncEngine,
          dio: mockDio,
          networkInfo: mockNetworkInfo,
        );

        when(() => mockDio.get('/expenses/categories')).thenAnswer(
          (_) async => Response(
            requestOptions: RequestOptions(path: '/expenses/categories'),
            statusCode: 200,
            data: {'success': true, 'data': canonical5Categories},
          ),
        );

        await repo1.fetchAndCacheCategories();
        await db1.close();

        final db2 = AppDatabase(NativeDatabase(dbFile));
        final queue2 = SyncQueueManager(db2);
        final mockNetworkOffline = MockNetworkInfo();
        when(() => mockNetworkOffline.isConnected).thenAnswer((_) async => false);

        final repo2 = ExpensesRepository(
          db: db2,
          queueManager: queue2,
          syncEngine: mockSyncEngine,
          dio: mockDio,
          networkInfo: mockNetworkOffline,
        );

        final offlineCategories = await repo2.watchCategories().first;
        expect(offlineCategories.length, equals(5));
        expect(offlineCategories.map((c) => c.name), contains('Servicios Básicos (Luz, Agua, Gas)'));

        await db2.close();
      } finally {
        if (dbFile.existsSync()) dbFile.deleteSync();
        if (tempDir.existsSync()) tempDir.deleteSync(recursive: true);
      }
    });

    test('6. Segunda sincronización (upsert) no duplica categorías en SQLite', () async {
      when(() => mockDio.get('/expenses/categories')).thenAnswer(
        (_) async => Response(
          requestOptions: RequestOptions(path: '/expenses/categories'),
          statusCode: 200,
          data: {'success': true, 'data': canonical5Categories},
        ),
      );

      await repository.fetchAndCacheCategories();
      final count1 = (await repository.getCategories()).length;
      expect(count1, equals(5));

      await repository.fetchAndCacheCategories();
      final count2 = (await repository.getCategories()).length;
      expect(count2, equals(5));

      final dbRows = await db.select(db.expenseCategoriesTable).get();
      expect(dbRows.length, equals(5));
    });

    test('7. Backend actualiza una categoría -> SQLite refleja el cambio de nombre y versión', () async {
      when(() => mockDio.get('/expenses/categories')).thenAnswer(
        (_) async => Response(
          requestOptions: RequestOptions(path: '/expenses/categories'),
          statusCode: 200,
          data: {'success': true, 'data': canonical5Categories},
        ),
      );
      await repository.fetchAndCacheCategories();

      final updatedBackendCategories = List<Map<String, dynamic>>.from(canonical5Categories);
      updatedBackendCategories[0] = {
        'id': '550e8400-e29b-41d4-a716-446655440400',
        'name': 'Insumos / Carnes, Pollo y Verduras',
        'active': true,
        'version': 2,
        'createdAt': '2026-08-10T10:00:00.000Z',
        'updatedAt': '2026-08-15T12:00:00.000Z',
      };

      when(() => mockDio.get('/expenses/categories')).thenAnswer(
        (_) async => Response(
          requestOptions: RequestOptions(path: '/expenses/categories'),
          statusCode: 200,
          data: {'success': true, 'data': updatedBackendCategories},
        ),
      );

      await repository.fetchAndCacheCategories();

      final updatedCat = await repository.getCategoryById('550e8400-e29b-41d4-a716-446655440400');
      expect(updatedCat, isNotNull);
      expect(updatedCat!.name, equals('Insumos / Carnes, Pollo y Verduras'));
      expect(updatedCat.version, equals(2));
    });

    test('8. Categoría inactiva (active: false) no aparece en watchCategories() del selector', () async {
      final categoriesWithInactive = [
        ...canonical5Categories,
        {
          'id': 'cat-inactiva-uuid-999',
          'name': 'Categoría Antigua Desactivada',
          'active': false,
          'version': 1,
          'createdAt': '2026-08-10T10:00:00.000Z',
          'updatedAt': '2026-08-10T10:00:00.000Z',
        }
      ];

      when(() => mockDio.get('/expenses/categories')).thenAnswer(
        (_) async => Response(
          requestOptions: RequestOptions(path: '/expenses/categories'),
          statusCode: 200,
          data: {'success': true, 'data': categoriesWithInactive},
        ),
      );

      await repository.fetchAndCacheCategories();

      final activeList = await repository.watchCategories().first;
      expect(activeList.length, equals(5));
      expect(activeList.any((c) => c.id == 'cat-inactiva-uuid-999'), isFalse);

      final allList = await repository.watchAllCategories().first;
      expect(allList.length, equals(6));
      expect(allList.firstWhere((c) => c.id == 'cat-inactiva-uuid-999').active, isFalse);
    });

    test('9. Crear nueva categoría offline genera UUID v4 y encola CREATE en SyncQueue', () async {
      final newCat = await repository.createCategory(name: 'Publicidad y Marketing');
      expect(newCat.name, equals('Publicidad y Marketing'));
      expect(newCat.active, isTrue);

      final ops = await queueManager.getPendingOperations();
      expect(ops.length, equals(1));
      expect(ops.first.entityType, equals('expense_category'));
      expect(ops.first.operation, equals('CREATE'));
      expect(ops.first.entityId, equals(newCat.id));

      final activeList = await repository.watchCategories().first;
      expect(activeList.any((c) => c.id == newCat.id), isTrue);
    });

    test('10. Expense creado usa el UUID exacto de category_id en SQLite y SyncQueue', () async {
      when(() => mockDio.get('/expenses/categories')).thenAnswer(
        (_) async => Response(
          requestOptions: RequestOptions(path: '/expenses/categories'),
          statusCode: 200,
          data: {'success': true, 'data': canonical5Categories},
        ),
      );
      await repository.fetchAndCacheCategories();

      final targetCategoryId = '550e8400-e29b-41d4-a716-446655440401'; // Servicios Básicos

      final exp = await repository.createExpense(
        description: 'Pago Factura de Luz',
        amount: 320.50,
        categoryId: targetCategoryId,
        paymentMethod: 'QR',
        expenseDate: '2026-08-15',
      );

      expect(exp.categoryId, equals(targetCategoryId));
      expect(exp.categoryName, equals('Servicios Básicos (Luz, Agua, Gas)'));

      final dbExp = await repository.getExpenseById(exp.id);
      expect(dbExp!.categoryId, equals(targetCategoryId));

      final ops = await queueManager.getPendingOperations();
      final expOp = ops.firstWhere((o) => o.entityId == exp.id);
      expect(expOp.payload, contains('"category_id":"$targetCategoryId"'));
    });
  });
}
