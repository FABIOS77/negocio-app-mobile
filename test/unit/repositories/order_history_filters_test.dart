import 'package:drift/drift.dart';
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

import 'package:katering_grecia_app/core/database/app_database.dart';
import 'package:katering_grecia_app/core/sync/sync_engine.dart';
import 'package:katering_grecia_app/core/sync/sync_queue_manager.dart';
import 'package:katering_grecia_app/features/orders/data/orders_repository.dart';

class MockSyncEngine extends Mock implements SyncEngine {}

void main() {
  late AppDatabase db;
  late SyncQueueManager queueManager;
  late MockSyncEngine mockSyncEngine;
  late OrdersRepository repository;

  setUp(() async {
    db = AppDatabase(NativeDatabase.memory());
    queueManager = SyncQueueManager(db);
    mockSyncEngine = MockSyncEngine();

    repository = OrdersRepository(
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

    // Crear platos de prueba
    await db.into(db.dishesTable).insert(
          DishesTableCompanion.insert(
            id: 'dish-1',
            name: 'Pique Macho',
            price: 50.0,
            createdAt: DateTime.now().toUtc(),
            updatedAt: DateTime.now().toUtc(),
          ),
        );

    // Precargar pedidos con fechas en America/La_Paz (UTC-4)
    // 1. Pedido 1: 2026-08-10 12:00 La Paz (UTC: 2026-08-10 16:00)
    await db.into(db.ordersTable).insert(
          OrdersTableCompanion.insert(
            id: 'order-1',
            orderNumber: const Value('101'),
            customerName: 'Juan Perez',
            locationText: const Value('Mesa 4'),
            total: 100.0,
            paymentMethod: 'CASH',
            status: 'DELIVERED',
            orderedAt: DateTime.parse('2026-08-10T16:00:00.000Z'),
            createdBy: 'user-1',
            createdAt: DateTime.parse('2026-08-10T16:00:00.000Z'),
            updatedAt: DateTime.parse('2026-08-10T16:00:00.000Z'),
          ),
        );

    // 2. Pedido 2: 2026-08-12 14:00 La Paz (UTC: 2026-08-12 18:00)
    await db.into(db.ordersTable).insert(
          OrdersTableCompanion.insert(
            id: 'order-2',
            orderNumber: const Value('102'),
            customerName: 'Maria Gomez',
            locationText: const Value('Barrio Central'),
            total: 150.0,
            paymentMethod: 'QR',
            status: 'PENDING',
            orderedAt: DateTime.parse('2026-08-12T18:00:00.000Z'),
            createdBy: 'user-1',
            createdAt: DateTime.parse('2026-08-12T18:00:00.000Z'),
            updatedAt: DateTime.parse('2026-08-12T18:00:00.000Z'),
          ),
        );

    // 3. Pedido 3: 2026-08-14 10:00 La Paz (UTC: 2026-08-14 14:00)
    await db.into(db.ordersTable).insert(
          OrdersTableCompanion.insert(
            id: 'order-3',
            orderNumber: const Value('103'),
            customerName: 'Carlos Juan Lopez',
            locationText: const Value('Mesa 1'),
            total: 50.0,
            paymentMethod: 'CASH',
            status: 'DELIVERED',
            orderedAt: DateTime.parse('2026-08-14T14:00:00.000Z'),
            createdBy: 'user-1',
            createdAt: DateTime.parse('2026-08-14T14:00:00.000Z'),
            updatedAt: DateTime.parse('2026-08-14T14:00:00.000Z'),
          ),
        );

    // 4. Pedido 4: 2026-08-14 23:59 La Paz (UTC: 2026-08-15 03:59:00.000Z)
    await db.into(db.ordersTable).insert(
          OrdersTableCompanion.insert(
            id: 'order-4-midnight',
            orderNumber: const Value('104'),
            customerName: 'Pedro Ramirez',
            locationText: const Value('Delivery Zona Sur'),
            total: 200.0,
            paymentMethod: 'OTHER',
            status: 'CANCELLED',
            orderedAt: DateTime.parse('2026-08-15T03:59:00.000Z'),
            createdBy: 'user-1',
            createdAt: DateTime.parse('2026-08-15T03:59:00.000Z'),
            updatedAt: DateTime.parse('2026-08-15T03:59:00.000Z'),
          ),
        );

    // 5. Pedido 5: 2026-08-15 08:00 La Paz (UTC: 2026-08-15 12:00:00.000Z)
    await db.into(db.ordersTable).insert(
          OrdersTableCompanion.insert(
            id: 'order-5-nextday',
            orderNumber: const Value('105'),
            customerName: 'Ana Mendoza',
            locationText: const Value('Mesa 2'),
            total: 80.0,
            paymentMethod: 'QR',
            status: 'PENDING',
            orderedAt: DateTime.parse('2026-08-15T12:00:00.000Z'),
            createdBy: 'user-1',
            createdAt: DateTime.parse('2026-08-15T12:00:00.000Z'),
            updatedAt: DateTime.parse('2026-08-15T12:00:00.000Z'),
          ),
        );
  });

  tearDown(() async {
    await db.close();
  });

  group('Order History Filters & Search Unit Tests', () {
    test('1. Filtro por fecha inicial (dateFrom): retorna pedidos desde esa fecha', () async {
      final orders = await repository.watchOrders(dateFrom: '2026-08-14').first;
      expect(orders.length, equals(3));
      expect(orders.map((o) => o.id), containsAll(['order-3', 'order-4-midnight', 'order-5-nextday']));
    });

    test('2. Filtro por fecha final (dateTo): retorna pedidos hasta esa fecha', () async {
      final orders = await repository.watchOrders(dateTo: '2026-08-12').first;
      expect(orders.length, equals(2));
      expect(orders.map((o) => o.id), containsAll(['order-1', 'order-2']));
    });

    test('3. Rango inclusivo (dateFrom + dateTo): retorna pedidos dentro del período', () async {
      final orders = await repository.watchOrders(dateFrom: '2026-08-10', dateTo: '2026-08-12').first;
      expect(orders.length, equals(2));
      expect(orders.map((o) => o.id), containsAll(['order-1', 'order-2']));
    });

    test('4. Filtro de estado: retorna solo pedidos con ese estado', () async {
      final delivered = await repository.watchOrders(status: 'DELIVERED').first;
      expect(delivered.length, equals(2));
      expect(delivered.every((o) => o.status == 'DELIVERED'), isTrue);

      final cancelled = await repository.watchOrders(status: 'CANCELLED').first;
      expect(cancelled.length, equals(1));
      expect(cancelled.first.id, equals('order-4-midnight'));
    });

    test('5. Búsqueda case-insensitive por cliente', () async {
      final results = await repository.watchOrders(searchQuery: 'juan').first;
      expect(results.length, equals(2));
      expect(results.map((o) => o.customerName), containsAll(['Juan Perez', 'Carlos Juan Lopez']));
    });

    test('6. Búsqueda case-insensitive por ubicación', () async {
      final results = await repository.watchOrders(searchQuery: 'zona sur').first;
      expect(results.length, equals(1));
      expect(results.first.id, equals('order-4-midnight'));
    });

    test('7. Búsqueda por order_number', () async {
      final results = await repository.watchOrders(searchQuery: '102').first;
      expect(results.length, equals(1));
      expect(results.first.orderNumber, equals('102'));
    });

    test('8. Combinación Fecha + Estado', () async {
      final results = await repository.watchOrders(
        dateFrom: '2026-08-14',
        dateTo: '2026-08-15',
        status: 'DELIVERED',
      ).first;

      expect(results.length, equals(1));
      expect(results.first.id, equals('order-3'));
    });

    test('9. Combinación Fecha + Búsqueda', () async {
      final results = await repository.watchOrders(
        dateFrom: '2026-08-14',
        dateTo: '2026-08-15',
        searchQuery: 'Carlos',
      ).first;

      expect(results.length, equals(1));
      expect(results.first.id, equals('order-3'));
    });

    test('10. Combinación Fecha + Estado + Búsqueda', () async {
      final results = await repository.watchOrders(
        dateFrom: '2026-08-14',
        dateTo: '2026-08-15',
        status: 'DELIVERED',
        searchQuery: 'Juan',
      ).first;

      expect(results.length, equals(1));
      expect(results.first.id, equals('order-3'));
    });

    test('11. Limpiar filtros (sin argumentos) devuelve historial completo paginado', () async {
      final all = await repository.watchOrders().first;
      expect(all.length, equals(5));
    });

    test('12. Búsqueda sin coincidencias devuelve lista vacía', () async {
      final results = await repository.watchOrders(searchQuery: 'Cliente Inexistente XYZ').first;
      expect(results.isEmpty, isTrue);
    });

    test('13. Paginación con limit y offset', () async {
      final page1 = await repository.watchOrders(limit: 2, offset: 0).first;
      expect(page1.length, equals(2));

      final page2 = await repository.watchOrders(limit: 2, offset: 2).first;
      expect(page2.length, equals(2));

      expect(page1.first.id, isNot(equals(page2.first.id)));
    });

    test('14 & 15. ZONA HORARIA AMERICA/LA_PAZ: Pedido 23:59 del 2026-08-14 aparece en 14/08 y NO en 15/08', () async {
      // Filtrar el día 2026-08-14
      final orders14 = await repository.watchOrders(dateFrom: '2026-08-14', dateTo: '2026-08-14').first;
      expect(orders14.map((o) => o.id), contains('order-4-midnight'));
      expect(orders14.map((o) => o.id), contains('order-3'));
      expect(orders14.map((o) => o.id), isNot(contains('order-5-nextday')));

      // Filtrar el día 2026-08-15
      final orders15 = await repository.watchOrders(dateFrom: '2026-08-15', dateTo: '2026-08-15').first;
      expect(orders15.map((o) => o.id), contains('order-5-nextday'));
      expect(orders15.map((o) => o.id), isNot(contains('order-4-midnight')));
      expect(orders15.map((o) => o.id), isNot(contains('order-3')));
    });
  });
}
