import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

import 'package:katering_grecia_app/core/database/app_database.dart';
import 'package:katering_grecia_app/core/sync/sync_engine.dart';
import 'package:katering_grecia_app/core/sync/sync_queue_manager.dart';
import 'package:katering_grecia_app/features/dishes/data/dishes_repository.dart';
import 'package:katering_grecia_app/features/orders/data/orders_repository.dart';

class MockSyncEngine extends Mock implements SyncEngine {}

void main() {
  late AppDatabase db;
  late SyncQueueManager queueManager;
  late MockSyncEngine mockSyncEngine;
  late DishesRepository dishesRepo;
  late OrdersRepository ordersRepo;

  setUp(() {
    db = AppDatabase(NativeDatabase.memory());
    queueManager = SyncQueueManager(db);
    mockSyncEngine = MockSyncEngine();

    dishesRepo = DishesRepository(
      db: db,
      queueManager: queueManager,
      syncEngine: mockSyncEngine,
    );

    ordersRepo = OrdersRepository(
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

  group('OrdersRepository Unit & Price History Tests', () {
    test('Create order freezes dish price snapshot in order_items', () async {
      // 1. Crear Plato a Bs 25.0
      final dish = await dishesRepo.createDish(name: 'Sopa de Maní', price: 25.0);

      // 2. Crear Pedido offline de 2 porciones
      final order = await ordersRepo.createOrder(
        customerName: 'Mesa 4',
        paymentMethod: 'CASH',
        itemsInput: [(dishId: dish.id, quantity: 2)],
      );

      expect(order.total, equals(50.0));
      expect(order.items.length, equals(1));
      expect(order.items.first.unitPrice, equals(25.0));

      // 3. Modificar el precio del plato en el catálogo a Bs 35.0
      await dishesRepo.updateDish(id: dish.id, price: 35.0);

      // 4. Verificar que el historial del pedido sigue con unitPrice = 25.0 e inmutable
      final orderAfter = await ordersRepo.getOrderById(order.id);
      expect(orderAfter!.items.first.unitPrice, equals(25.0));
      expect(orderAfter.total, equals(50.0));
    });

    test('Order status transitions follow domain rules', () async {
      final dish = await dishesRepo.createDish(name: 'Chicharron', price: 40.0);
      final order = await ordersRepo.createOrder(
        customerName: 'Carlos',
        paymentMethod: 'QR',
        itemsInput: [(dishId: dish.id, quantity: 1)],
      );

      expect(order.status, equals('PENDING'));

      // Transición válida: PENDING -> DELIVERED
      await ordersRepo.changeOrderStatus(order.id, 'DELIVERED');
      final deliveredOrder = await ordersRepo.getOrderById(order.id);
      expect(deliveredOrder!.status, equals('DELIVERED'));

      // Transición inválida: DELIVERED -> PENDING debe lanzar error
      expect(
        () => ordersRepo.changeOrderStatus(order.id, 'PENDING'),
        throwsA(isA<StateError>()),
      );
    });
  });
}
