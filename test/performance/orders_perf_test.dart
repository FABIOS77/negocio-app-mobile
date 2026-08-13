import 'package:drift/drift.dart';
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:katering_grecia_app/core/database/app_database.dart';
import 'package:katering_grecia_app/features/production/data/production_repository.dart';

void main() {
  late AppDatabase db;
  late ProductionRepository productionRepo;

  setUp(() {
    db = AppDatabase(NativeDatabase.memory());
    productionRepo = ProductionRepository(db: db);
  });

  tearDown(() async {
    await db.close();
  });

  group('Orders & Production Performance Tests (5,000 Orders)', () {
    test('Handles 5,000 orders & 10,000 order items query & production summary sub-50ms', () async {
      final now = DateTime.now().toUtc();

      // 1. Inserción masiva de 5,000 pedidos
      await db.batch((batch) {
        for (int i = 1; i <= 5000; i++) {
          batch.insert(
            db.ordersTable,
            OrdersTableCompanion.insert(
              id: 'order-perf-$i',
              orderNumber: Value('20260813-${i.toString().padLeft(4, '0')}'),
              customerName: 'Cliente Perf #$i',
              total: 50.0,
              paymentMethod: i % 2 == 0 ? 'CASH' : 'QR',
              status: i % 10 == 0 ? 'CANCELLED' : 'PENDING',
              orderedAt: now,
              createdBy: 'perf-user',
              createdAt: now,
              updatedAt: now,
            ),
          );
        }
      });

      // 2. Inserción masiva de 10,000 order items
      await db.batch((batch) {
        for (int i = 1; i <= 5000; i++) {
          batch.insert(
            db.orderItemsTable,
            OrderItemsTableCompanion.insert(
              id: 'item-1-$i',
              orderId: 'order-perf-$i',
              dishId: 'dish-1',
              dishNameSnapshot: 'Sopa de Maní',
              quantity: 2,
              unitPrice: 15.0,
              subtotal: 30.0,
            ),
          );
          batch.insert(
            db.orderItemsTable,
            OrderItemsTableCompanion.insert(
              id: 'item-2-$i',
              orderId: 'order-perf-$i',
              dishId: 'dish-2',
              dishNameSnapshot: 'Pique Macho',
              quantity: 1,
              unitPrice: 35.0,
              subtotal: 35.0,
            ),
          );
        }
      });

      // 3. Medir tiempo de consulta paginada de pedidos de hoy (20 items)
      final stopwatchOrders = Stopwatch()..start();
      final todayOrdersPage = await (db.select(db.ordersTable)
            ..where((t) => t.status.equals('PENDING'))
            ..orderBy([(t) => OrderingTerm(expression: t.orderedAt, mode: OrderingMode.desc)])
            ..limit(20, offset: 0))
          .get();
      stopwatchOrders.stop();

      expect(todayOrdersPage.length, equals(20));
      expect(stopwatchOrders.elapsedMilliseconds, lessThan(50));

      // 4. Medir tiempo de agregación SQL de Producción sobre los 10,000 items
      final stopwatchProduction = Stopwatch()..start();
      final productionSummary = await productionRepo.watchProductionSummary().first;
      stopwatchProduction.stop();

      expect(productionSummary.length, equals(2));
      // 4,500 pedidos no cancelados * 2 sopas = 9,000 porciones
      expect(productionSummary.first.totalQuantity, equals(9000));
      expect(stopwatchProduction.elapsedMilliseconds, lessThan(50));
    });
  });
}
