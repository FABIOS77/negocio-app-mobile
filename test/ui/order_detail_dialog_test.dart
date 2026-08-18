import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

import 'package:katering_grecia_app/core/database/app_database.dart';
import 'package:katering_grecia_app/core/sync/sync_engine.dart';
import 'package:katering_grecia_app/core/sync/sync_queue_manager.dart';
import 'package:katering_grecia_app/core/utils/currency_formatter.dart';
import 'package:katering_grecia_app/features/dishes/data/dishes_repository.dart';
import 'package:katering_grecia_app/features/orders/application/orders_notifier.dart';
import 'package:katering_grecia_app/features/orders/data/orders_repository.dart';
import 'package:katering_grecia_app/features/orders/domain/order_model.dart';
import 'package:katering_grecia_app/features/orders/presentation/order_detail_dialog.dart';

class MockSyncEngine extends Mock implements SyncEngine {}

void main() {
  late AppDatabase db;
  late SyncQueueManager queueManager;
  late MockSyncEngine mockSyncEngine;
  late DishesRepository dishesRepo;
  late OrdersRepository ordersRepo;
  late OrderModel createdOrder;

  setUp(() async {
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

    final dish1 = await dishesRepo.createDish(name: 'Sopa de Maní', price: 15.0);
    final dish2 = await dishesRepo.createDish(name: 'Majadito de Pato', price: 25.0);

    createdOrder = await ordersRepo.createOrder(
      customerName: 'Fabio Saldias',
      locationText: 'Mesa 5 Terraza',
      paymentMethod: 'QR',
      itemsInput: [
        (dishId: dish1.id, quantity: 2),
        (dishId: dish2.id, quantity: 1),
      ],
    );
  });

  tearDown(() async {
    await db.close();
  });

  testWidgets('OrderDetailDialog loads OrderModel on-demand asynchronously and renders complete details', (tester) async {
    final container = ProviderContainer(
      overrides: [
        databaseProvider.overrideWithValue(db),
        syncEngineProvider.overrideWithValue(mockSyncEngine),
        ordersRepositoryProvider.overrideWithValue(ordersRepo),
      ],
    );

    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: MaterialApp(
          home: Scaffold(
            body: Builder(
              builder: (ctx) => ElevatedButton(
                onPressed: () {
                  showDialog(
                    context: ctx,
                    builder: (dCtx) => OrderDetailDialog(orderId: createdOrder.id),
                  );
                },
                child: const Text('ABRIR DETALLE'),
              ),
            ),
          ),
        ),
      ),
    );

    // 1. Tocar botón para abrir el diálogo
    await tester.tap(find.text('ABRIR DETALLE'));
    await tester.pump();
    await tester.pumpAndSettle();

    // 2. Verificar que se cargaron los datos completos bajo demanda
    expect(find.text('Cliente: Fabio Saldias'), findsOneWidget);
    expect(find.text('Ubicación: Mesa 5 Terraza'), findsOneWidget);
    expect(find.text('Pago: QR'), findsOneWidget);
    expect(find.text('PENDING'), findsOneWidget);

    // Items desglosados
    expect(find.text('2x Sopa de Maní'), findsOneWidget);
    expect(find.text(CurrencyFormatter.formatBOB(30.0)), findsOneWidget);
    expect(find.text('1x Majadito de Pato'), findsOneWidget);
    expect(find.text(CurrencyFormatter.formatBOB(25.0)), findsOneWidget);

    // Total = 55.0
    expect(find.text(CurrencyFormatter.formatBOB(55.0)), findsWidgets);

    // Botones de acción
    expect(find.text('ENTREGAR'), findsOneWidget);
    expect(find.text('Cerrar'), findsOneWidget);

    // 3. Probar entrega
    await tester.tap(find.text('ENTREGAR'));
    await tester.pump();
    await tester.pump(const Duration(seconds: 4));

    // Verificar en SQLite que cambió de estado
    final updated = await ordersRepo.getOrderById(createdOrder.id);
    expect(updated!.status, equals('DELIVERED'));

    container.dispose();
  });
}
