import 'dart:async';
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:katering_grecia_app/core/database/app_database.dart';
import 'package:katering_grecia_app/core/sync/sync_engine.dart';
import 'package:katering_grecia_app/core/sync/sync_queue_manager.dart';
import 'package:katering_grecia_app/features/dishes/data/dishes_repository.dart';
import 'package:katering_grecia_app/features/orders/data/orders_repository.dart';
import 'package:katering_grecia_app/features/orders/domain/order_summary_model.dart';

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
    dishesRepo = DishesRepository(db: db, queueManager: queueManager, syncEngine: mockSyncEngine);
    ordersRepo = OrdersRepository(db: db, queueManager: queueManager, syncEngine: mockSyncEngine);

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

  group('OrdersRepository Unit Tests', () {
    test('Create order freezes dish price snapshot in order_items and calculates total correctly', () async {
      final dish1 = await dishesRepo.createDish(name: 'Sopa de Maní', price: 15.0);
      final dish2 = await dishesRepo.createDish(name: 'Majadito', price: 25.0);

      final order = await ordersRepo.createOrder(
        customerName: 'Juan Pérez',
        locationText: 'Mesa 4',
        paymentMethod: 'CASH',
        itemsInput: [
          (dishId: dish1.id, quantity: 2),
          (dishId: dish2.id, quantity: 1),
        ],
      );

      expect(order.customerName, equals('Juan Pérez'));
      expect(order.locationText, equals('Mesa 4'));
      expect(order.status, equals('PENDING'));
      expect(order.total, equals(55.0)); // 2*15 + 1*25 = 55.0
      expect(order.items.length, equals(2));

      final item1 = order.items.firstWhere((i) => i.dishId == dish1.id);
      expect(item1.unitPrice, equals(15.0));
      expect(item1.quantity, equals(2));
      expect(item1.subtotal, equals(30.0));
      expect(item1.dishNameSnapshot, equals('Sopa de Maní'));

      // Verificar que si cambia el precio del plato original, el snapshot de la orden NO cambia
      await dishesRepo.updateDish(id: dish1.id, name: 'Sopa de Maní Gourmet', price: 99.0);
      final retrievedOrder = await ordersRepo.getOrderById(order.id);
      expect(retrievedOrder, isNotNull);
      expect(retrievedOrder!.total, equals(55.0));
      expect(retrievedOrder.items.firstWhere((i) => i.dishId == dish1.id).unitPrice, equals(15.0));
    });

    test('Order status transitions follow domain rules: PENDING -> DELIVERED / CANCELLED', () async {
      final dish = await dishesRepo.createDish(name: 'Sopa de Maní', price: 15.0);
      final order = await ordersRepo.createOrder(
        customerName: 'Ana López',
        paymentMethod: 'QR',
        itemsInput: [(dishId: dish.id, quantity: 1)],
      );

      expect(order.status, equals('PENDING'));

      // 1. Cambiar a DELIVERED
      await ordersRepo.changeOrderStatus(order.id, 'DELIVERED');
      final deliveredOrder = await ordersRepo.getOrderById(order.id);
      expect(deliveredOrder!.status, equals('DELIVERED'));
      expect(deliveredOrder.version, equals(2));

      // 2. Intentar cambiar desde DELIVERED a otro estado debe fallar (estado terminal)
      expect(
        () => ordersRepo.changeOrderStatus(order.id, 'PENDING'),
        throwsA(isA<StateError>()),
      );
    });

    test('Update order in PENDING status replaces items, recalcs total and increments version', () async {
      final dish1 = await dishesRepo.createDish(name: 'Sopa de Maní', price: 15.0);
      final dish2 = await dishesRepo.createDish(name: 'Pique Macho', price: 40.0);

      final originalOrder = await ordersRepo.createOrder(
        customerName: 'Carlos',
        paymentMethod: 'CASH',
        itemsInput: [(dishId: dish1.id, quantity: 2)],
      );
      expect(originalOrder.total, equals(30.0));
      expect(originalOrder.version, equals(1));

      // Actualizar cambiando items a 1 Pique Macho
      final updatedOrder = await ordersRepo.updateOrder(
        id: originalOrder.id,
        customerName: 'Carlos Gómez',
        locationText: 'Mesa VIP',
        paymentMethod: 'QR',
        itemsInput: [(dishId: dish2.id, quantity: 1)],
      );

      expect(updatedOrder.customerName, equals('Carlos Gómez'));
      expect(updatedOrder.locationText, equals('Mesa VIP'));
      expect(updatedOrder.paymentMethod, equals('QR'));
      expect(updatedOrder.total, equals(40.0));
      expect(updatedOrder.version, equals(2));
      expect(updatedOrder.items.length, equals(1));
      expect(updatedOrder.items.first.dishId, equals(dish2.id));
    });

    test('watchTodayOrders strictly excludes CANCELLED and deleted orders', () async {
      final dish = await dishesRepo.createDish(name: 'Sopa de Maní', price: 15.0);

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

    test('watchTodayOrders immediately emits OrderSummaryModel on order creation and updates', () async {
      final dish1 = await dishesRepo.createDish(name: 'Sopa de Maní', price: 20.0);
      final dish2 = await dishesRepo.createDish(name: 'Majadito', price: 25.0);

      final completers = <Completer<List<OrderSummaryModel>>>[
        Completer<List<OrderSummaryModel>>(),
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
      completers.add(Completer<List<OrderSummaryModel>>());
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
      final emittedSummary = list.first;

      // El resumen emitido debe tener itemsCount == 2 y total correcto
      expect(emittedSummary.id, equals(createdOrder.id));
      expect(emittedSummary.itemsCount, equals(2));
      expect(emittedSummary.total, equals(120 * 20.0 + 80 * 25.0)); // 2400 + 2000 = 4400

      // Comprobar que getOrderById devuelve el modelo completo con sus items
      final fullOrder = await ordersRepo.getOrderById(createdOrder.id);
      expect(fullOrder, isNotNull);
      expect(fullOrder!.items.length, equals(2));
      final sopaItem = fullOrder.items.firstWhere((i) => i.dishId == dish1.id);
      expect(sopaItem.quantity, equals(120));
      expect(sopaItem.dishNameSnapshot, equals('Sopa de Maní'));
      expect(sopaItem.subtotal, equals(2400.0));

      final majaditoItem = fullOrder.items.firstWhere((i) => i.dishId == dish2.id);
      expect(majaditoItem.quantity, equals(80));
      expect(majaditoItem.subtotal, equals(2000.0));

      // 3. Actualizar items del pedido a 150 Sopas
      completers.add(Completer<List<OrderSummaryModel>>());
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
      expect(updatedEmitted.itemsCount, equals(1));
      expect(updatedEmitted.total, equals(150 * 20.0));

      await sub.cancel();
    });
  });
}
