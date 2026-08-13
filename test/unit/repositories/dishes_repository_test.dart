import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:katering_grecia_app/core/database/app_database.dart';
import 'package:katering_grecia_app/core/sync/sync_engine.dart';
import 'package:katering_grecia_app/core/sync/sync_queue_manager.dart';
import 'package:katering_grecia_app/features/dishes/data/dishes_repository.dart';

class MockSyncEngine extends Mock implements SyncEngine {}

void main() {
  late AppDatabase db;
  late SyncQueueManager queueManager;
  late MockSyncEngine mockSyncEngine;
  late DishesRepository repository;

  setUp(() {
    db = AppDatabase(NativeDatabase.memory());
    queueManager = SyncQueueManager(db);
    mockSyncEngine = MockSyncEngine();

    repository = DishesRepository(
      db: db,
      queueManager: queueManager,
      syncEngine: mockSyncEngine,
    );

    when(() => mockSyncEngine.syncAll()).thenAnswer((_) async => SyncResult(
          pushedCount: 0,
          pulledCount: 0,
          conflictCount: 0,
          errorCount: 0,
        ));
  });

  tearDown(() async {
    await db.close();
  });

  group('DishesRepository Unit Tests', () {
    test('Create, Read, Search and Soft Delete Dish offline', () async {
      // 1. Crear Plato Offline
      final dish = await repository.createDish(
        name: 'Majadito de Pato',
        description: 'Plato típico con huevo y plátano',
        price: 25.0,
      );

      expect(dish.name, equals('Majadito de Pato'));
      expect(dish.price, equals(25.0));
      expect(dish.syncStatus, equals('PENDING'));

      // Verificar que se encoló la operación CREATE
      final pendingOps = await queueManager.getPendingOperations();
      expect(pendingOps.length, equals(1));
      expect(pendingOps.first.entityId, equals(dish.id));
      expect(pendingOps.first.operation, equals('CREATE'));

      // 2. Búsqueda local insensible a mayúsculas
      final searchResult = await repository.watchDishes(searchQuery: 'majadito').first;
      expect(searchResult.length, equals(1));
      expect(searchResult.first.id, equals(dish.id));

      // 3. Soft delete (active: false)
      await repository.deleteDish(dish.id);

      final activeDishes = await repository.watchDishes(activeOnly: true).first;
      expect(activeDishes.isEmpty, isTrue);

      final allDishes = await repository.watchDishes(activeOnly: false).first;
      expect(allDishes.length, equals(1));
      expect(allDishes.first.active, isFalse);
    });
  });
}
