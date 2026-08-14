import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:katering_grecia_app/core/database/app_database.dart';
import 'package:katering_grecia_app/core/sync/sync_engine.dart';
import 'package:katering_grecia_app/core/sync/sync_queue_manager.dart';
import 'package:katering_grecia_app/core/utils/timezone_utils.dart';
import 'package:katering_grecia_app/features/daily_menu/data/daily_menu_repository.dart';
import 'package:katering_grecia_app/features/dishes/data/dishes_repository.dart';

class MockSyncEngine extends Mock implements SyncEngine {}

void main() {
  late AppDatabase db;
  late SyncQueueManager queueManager;
  late MockSyncEngine mockSyncEngine;
  late DishesRepository dishesRepo;
  late DailyMenuRepository menuRepo;

  setUp(() {
    db = AppDatabase(NativeDatabase.memory());
    queueManager = SyncQueueManager(db);
    mockSyncEngine = MockSyncEngine();

    dishesRepo = DishesRepository(
      db: db,
      queueManager: queueManager,
      syncEngine: mockSyncEngine,
    );

    menuRepo = DailyMenuRepository(
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

  group('DailyMenuRepository Unit Tests', () {
    test('Create Daily Menu with 3 Dishes using atomic Drift Transaction and relational 1-to-N grouping', () async {
      // 1. Crear 3 platos en el catálogo
      final dish1 = await dishesRepo.createDish(name: 'Sopa de Maní', price: 15.0);
      final dish2 = await dishesRepo.createDish(name: 'Silpancho Cochabambino', price: 30.0);
      final dish3 = await dishesRepo.createDish(name: 'Majadito de Pollo', price: 25.0);

      final todayDate = TimezoneUtils.getTodayBusinessDate();

      // 2. Crear menú diario con 3 platos en transacción atómica
      final menu = await menuRepo.createDailyMenu(
        menuDate: todayDate,
        dishIds: [dish1.id, dish2.id, dish3.id],
      );

      expect(menu.menuDate, equals(todayDate));
      expect(menu.dishes.length, equals(3));

      // 3. Consultar hoy reactivamente mediante watchMenuByDate (JOIN + Agrupación 1-a-N)
      final todayMenu = await menuRepo.watchTodayMenu().first;
      expect(todayMenu, isNotNull);
      expect(todayMenu!.dishes.length, equals(3));
      expect(
        todayMenu.dishes.map((d) => d.name),
        containsAll(['Sopa de Maní', 'Silpancho Cochabambino', 'Majadito de Pollo']),
      );
    });
  });
}
