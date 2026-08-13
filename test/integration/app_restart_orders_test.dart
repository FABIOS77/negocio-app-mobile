import 'dart:io';
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:path/path.dart' as p;

import 'package:katering_grecia_app/core/database/app_database.dart';
import 'package:katering_grecia_app/core/sync/sync_engine.dart';
import 'package:katering_grecia_app/core/sync/sync_queue_manager.dart';
import 'package:katering_grecia_app/features/dishes/data/dishes_repository.dart';
import 'package:katering_grecia_app/features/orders/data/orders_repository.dart';
import 'package:katering_grecia_app/features/production/data/production_repository.dart';

class MockSyncEngine extends Mock implements SyncEngine {}

void main() {
  late File dbFile;
  late MockSyncEngine mockSyncEngine;

  setUp(() {
    final tempDir = Directory.systemTemp.createTempSync('katering_orders_test_');
    dbFile = File(p.join(tempDir.path, 'test_orders_db.sqlite'));
    mockSyncEngine = MockSyncEngine();

    when(() => mockSyncEngine.syncAll()).thenAnswer((_) async => SyncResult(
          pushedCount: 0,
          pulledCount: 0,
          conflictCount: 0,
          errorCount: 0,
        ));
  });

  tearDown(() {
    if (dbFile.existsSync()) {
      dbFile.deleteSync();
    }
  });

  group('App Restart Orders & Items Persistence Test', () {
    test('Offline created order and items persist across DB restarts', () async {
      // 1. Instancia 1 de BD en archivo temporal
      var db1 = AppDatabase(NativeDatabase(dbFile));
      var queueManager1 = SyncQueueManager(db1);
      var dishesRepo1 = DishesRepository(db: db1, queueManager: queueManager1, syncEngine: mockSyncEngine);
      var ordersRepo1 = OrdersRepository(db: db1, queueManager: queueManager1, syncEngine: mockSyncEngine);

      final dish = await dishesRepo1.createDish(name: 'Majadito', price: 20.0);
      final createdOrder = await ordersRepo1.createOrder(
        customerName: 'Cliente Persistencia',
        paymentMethod: 'CASH',
        itemsInput: [(dishId: dish.id, quantity: 3)],
      );

      expect(createdOrder.total, equals(60.0));

      // 2. Simular Cierre de App
      await db1.close();

      // 3. Simular Reinicio de App (Reabrir conexión sobre el mismo archivo SQLite)
      var db2 = AppDatabase(NativeDatabase(dbFile));
      var queueManager2 = SyncQueueManager(db2);
      var ordersRepo2 = OrdersRepository(db: db2, queueManager: queueManager2, syncEngine: mockSyncEngine);
      var productionRepo2 = ProductionRepository(db: db2);

      // Comprobar que el pedido e items persisten intactos
      final restoredOrder = await ordersRepo2.getOrderById(createdOrder.id);
      expect(restoredOrder, isNotNull);
      expect(restoredOrder!.customerName, equals('Cliente Persistencia'));
      expect(restoredOrder.items.length, equals(1));
      expect(restoredOrder.items.first.quantity, equals(3));
      expect(restoredOrder.items.first.subtotal, equals(60.0));

      // Comprobar que la cola de sync mantiene la operación PENDING
      final pendingOps = await queueManager2.getPendingOperations();
      expect(pendingOps.length, greaterThanOrEqualTo(1));

      // Comprobar que el resumen de producción calcula las 3 porciones
      final production = await productionRepo2.watchProductionSummary().first;
      expect(production.first.totalQuantity, equals(3));

      await db2.close();
    });
  });
}
