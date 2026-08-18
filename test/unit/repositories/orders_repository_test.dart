import 'dart:async';
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

import 'package:katering_grecia_app/core/database/app_database.dart';
import 'package:katering_grecia_app/core/sync/sync_engine.dart';
import 'package:katering_grecia_app/core/sync/sync_queue_manager.dart';
import 'package:katering_grecia_app/features/dishes/data/dishes_repository.dart';
import 'package:katering_grecia_app/features/orders/data/orders_repository.dart';
import 'package:katering_grecia_app/features/orders/domain/order_model.dart';

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

    test('Update order in PENDING status replaces items, recalculates total, increments version and enqueues UPDATE', () async {
      final dish1 = await dishesRepo.createDish(name: 'Sopa de Maní', price: 20.0);
      final dish2 = await dishesRepo.createDish(name: 'Pique Macho', price: 50.0);

      final order = await ordersRepo.createOrder(
        customerName: 'Juan',
        paymentMethod: 'CASH',
        itemsInput: [(dishId: dish1.id, quantity: 1)],
      );

      expect(order.total, equals(20.0));
      expect(order.version, equals(1));

      final updatedOrder = await ordersRepo.updateOrder(
        id: order.id,
        customerName: 'Juan Pérez',
        locationText: 'Mesa 3',
        paymentMethod: 'QR',
        itemsInput: [
          (dishId: dish1.id, quantity: 2),
          (dishId: dish2.id, quantity: 1),
        ],
      );

      expect(updatedOrder.customerName, equals('Juan Pérez'));
      expect(updatedOrder.locationText, equals('Mesa 3'));
      expect(updatedOrder.paymentMethod, equals('QR'));
      expect(updatedOrder.total, equals(90.0)); // 20*2 + 50*1 = 90
      expect(updatedOrder.version, equals(2));
      expect(updatedOrder.items.length, equals(2));

      final pendingOps = await queueManager.getPendingOperations();
      final updateOp = pendingOps.firstWhere((op) => op.operation == 'UPDATE' && op.entityId == order.id);
      expect(updateOp.baseVersion, equals(1));

      // Verificar que intentar editar un pedido en estado DELIVERED lanza StateError
      await ordersRepo.changeOrderStatus(order.id, 'DELIVERED');
      expect(
        () => ordersRepo.updateOrder(
          id: order.id,
          customerName: 'Juan Editado',
          paymentMethod: 'CASH',
          itemsInput: [(dishId: dish1.id, quantity: 1)],
        ),
        throwsA(isA<StateError>()),
      );
    });

    test('Delete order marks status CANCELLED, sets deletedAt, increments version and enqueues DELETE', () async {
      final dish = await dishesRepo.createDish(name: 'Majadito', price: 25.0);
      final order = await ordersRepo.createOrder(
        customerName: 'Pedro',
        paymentMethod: 'CASH',
        itemsInput: [(dishId: dish.id, quantity: 1)],
      );

      await ordersRepo.deleteOrder(order.id);

      final deletedOrder = await ordersRepo.getOrderById(order.id);
      expect(deletedOrder!.status, equals('CANCELLED'));
      expect(deletedOrder.version, equals(2));

      final pendingOps = await queueManager.getPendingOperations();
      final deleteOp = pendingOps.firstWhere((op) => op.operation == 'DELETE' && op.entityId == order.id);
      expect(deleteOp.baseVersion, equals(1));
    });

    test('watchTodayOrders strictly excludes CANCELLED and deleted orders', () async {
      final dish = await dishesRepo.createDish(name: 'Keperi', price: 35.0);

      // Crear 2 pedidos
      final order1 = await ordersRepo.createOrder(
        customerName: 'Cliente Activo',
        paymentMethod: 'CASH',
        itemsInput: [(dishId: dish.id, quantity: 1)],
      );
      final order2 = await ordersRepo.createOrder(
        customerName: 'Cliente a Cancelar',
        paymentMethod: 'QR',
        itemsInput: [(dishId: dish.id, quantity: 2)],
      );

      // Eliminar el segundo pedido
      await ordersRepo.deleteOrder(order2.id);

      // watchTodayOrders solo debe contener order1
      final todayOrders = await ordersRepo.watchTodayOrders().first;
      expect(todayOrders.length, equals(1));
      expect(todayOrders.first.id, equals(order1.id));
      expect(todayOrders.any((o) => o.id == order2.id), isFalse);
    });

    test('watchTodayOrders immediately emits complete order_items on order creation and updates', () async {
      final dish1 = await dishesRepo.createDish(name: 'Sopa de Maní', price: 20.0);
      final dish2 = await dishesRepo.createDish(name: 'Majadito', price: 25.0);

      final completers = <Completer<List<OrderModel>>>[
        Completer<List<OrderModel>>(),
      ];

      final sub = ordersRepo.watchTodayOrders().listen((orders) {
        if (!completers.last.isCompleted) {
          completers.last.complete(orders);
        }
      });

      // 1. Inicial: 0 pedidos
      var list = await completers.last.future;
      expect(list, isEmpty);

      // 2. Crear pedido grande de 120 porciones de Sopa de Maní y 80 de Majadito
      completers.add(Completer<List<OrderModel>>());
      final createdOrder = await ordersRepo.createOrder(
        customerName: 'Evento Corporativo',
        paymentMethod: 'CASH',
        itemsInput: [
          (dishId: dish1.id, quantity: 120),
          (dishId: dish2.id, quantity: 80),
        ],
      );

      list = await completers.last.future;
      expect(list.length, equals(1));
      final emittedOrder = list.first;

      // El pedido debe emitirse con sus 2 items completos de inmediato
      expect(emittedOrder.id, equals(createdOrder.id));
      expect(emittedOrder.items.length, equals(2));
      expect(emittedOrder.total, equals(120 * 20.0 + 80 * 25.0)); // 2400 + 2000 = 4400

      final sopaItem = emittedOrder.items.firstWhere((i) => i.dishId == dish1.id);
      expect(sopaItem.quantity, equals(120));
      expect(sopaItem.dishNameSnapshot, equals('Sopa de Maní'));
      expect(sopaItem.subtotal, equals(2400.0));

      final majaditoItem = emittedOrder.items.firstWhere((i) => i.dishId == dish2.id);
      expect(majaditoItem.quantity, equals(80));
      expect(majaditoItem.subtotal, equals(2000.0));

      // 3. Actualizar items del pedido a 150 Sopas
      completers.add(Completer<List<OrderModel>>());
      await ordersRepo.updateOrder(
        id: createdOrder.id,
        customerName: 'Evento Corporativo VIP',
        paymentMethod: 'QR',
        itemsInput: [
          (dishId: dish1.id, quantity: 150),
        ],
      );

      list = await completers.last.future;
      expect(list.length, equals(1));
      final updatedEmitted = list.first;
      expect(updatedEmitted.customerName, equals('Evento Corporativo VIP'));
      expect(updatedEmitted.items.length, equals(1));
      expect(updatedEmitted.items.first.quantity, equals(150));
      expect(updatedEmitted.total, equals(150 * 20.0));

      await sub.cancel();
    });
  });
}
