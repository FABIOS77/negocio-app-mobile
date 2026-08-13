import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

import 'package:katering_grecia_app/core/database/app_database.dart';
import 'package:katering_grecia_app/core/sync/sync_engine.dart';
import 'package:katering_grecia_app/core/sync/sync_queue_manager.dart';
import 'package:katering_grecia_app/features/dishes/data/dishes_repository.dart';
import 'package:katering_grecia_app/features/orders/data/orders_repository.dart';
import 'package:katering_grecia_app/features/production/data/production_repository.dart';

class MockSyncEngine extends Mock implements SyncEngine {}

void main() {
  late AppDatabase db;
  late SyncQueueManager queueManager;
  late MockSyncEngine mockSyncEngine;
  late DishesRepository dishesRepo;
  late OrdersRepository ordersRepo;
  late ProductionRepository productionRepo;

  setUp(() {
    db = AppDatabase(NativeDatabase.memory());
    queueManager = SyncQueueManager(db);
    mockSyncEngine = MockSyncEngine();

    dishesRepo = DishesRepository(db: db, queueManager: queueManager, syncEngine: mockSyncEngine);
    ordersRepo = OrdersRepository(db: db, queueManager: queueManager, syncEngine: mockSyncEngine);
    productionRepo = ProductionRepository(db: db);

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

  group('ProductionRepository Aggregation Tests', () {
    test('Calculates aggregated quantity grouped by dish excluding CANCELLED orders', () async {
      final dish1 = await dishesRepo.createDish(name: 'Sopa de Maní', price: 15.0);
      final dish2 = await dishesRepo.createDish(name: 'Pique Macho', price: 35.0);

      // Pedido 1 PENDING: 2 Sopas, 1 Pique
      await ordersRepo.createOrder(
        customerName: 'Mesa 1',
        paymentMethod: 'CASH',
        itemsInput: [
          (dishId: dish1.id, quantity: 2),
          (dishId: dish2.id, quantity: 1),
        ],
      );

      // Pedido 2 PENDING: 3 Sopas
      await ordersRepo.createOrder(
        customerName: 'Mesa 2',
        paymentMethod: 'QR',
        itemsInput: [
          (dishId: dish1.id, quantity: 3),
        ],
      );

      // Pedido 3 CANCELLED: 10 Piques (debe ignorarse en producción)
      final order3 = await ordersRepo.createOrder(
        customerName: 'Mesa Cancelada',
        paymentMethod: 'CASH',
        itemsInput: [
          (dishId: dish2.id, quantity: 10),
        ],
      );
      await ordersRepo.changeOrderStatus(order3.id, 'CANCELLED');

      // Consultar resumen de producción
      final production = await productionRepo.watchProductionSummary().first;

      expect(production.length, equals(2));
      // Sopa de Maní debe tener 5 porciones (2 + 3) y estar al inicio por mayor cantidad
      expect(production.first.dishName, equals('Sopa de Maní'));
      expect(production.first.totalQuantity, equals(5));

      // Pique Macho debe tener 1 porción (1 del Pedido 1, ignorando el CANCELLED)
      expect(production.last.dishName, equals('Pique Macho'));
      expect(production.last.totalQuantity, equals(1));
    });
  });
}
