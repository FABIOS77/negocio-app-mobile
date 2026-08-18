import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

import 'package:katering_grecia_app/core/database/app_database.dart';
import 'package:katering_grecia_app/core/sync/sync_engine.dart';
import 'package:katering_grecia_app/core/sync/sync_queue_manager.dart';
import 'package:katering_grecia_app/core/utils/currency_formatter.dart';
import 'package:katering_grecia_app/core/utils/timezone_utils.dart';
import 'package:katering_grecia_app/features/daily_menu/application/daily_menu_notifier.dart';
import 'package:katering_grecia_app/features/daily_menu/data/daily_menu_repository.dart';
import 'package:katering_grecia_app/features/dishes/data/dishes_repository.dart';
import 'package:katering_grecia_app/features/dishes/domain/dish_model.dart';
import 'package:katering_grecia_app/features/orders/application/orders_notifier.dart';
import 'package:katering_grecia_app/features/orders/data/orders_repository.dart';
import 'package:katering_grecia_app/features/orders/presentation/new_order_screen.dart';

class MockSyncEngine extends Mock implements SyncEngine {}

void main() {
  late AppDatabase db;
  late SyncQueueManager queueManager;
  late MockSyncEngine mockSyncEngine;
  late DishesRepository dishesRepo;
  late OrdersRepository ordersRepo;
  late DailyMenuRepository dailyMenuRepo;
  late DishModel d1;
  late DishModel d2;

  setUp(() async {
    db = AppDatabase(NativeDatabase.memory());
    queueManager = SyncQueueManager(db);
    mockSyncEngine = MockSyncEngine();

    dishesRepo = DishesRepository(db: db, queueManager: queueManager, syncEngine: mockSyncEngine);
    ordersRepo = OrdersRepository(db: db, queueManager: queueManager, syncEngine: mockSyncEngine);
    dailyMenuRepo = DailyMenuRepository(db: db, queueManager: queueManager, syncEngine: mockSyncEngine);

    when(() => mockSyncEngine.syncAll()).thenAnswer((_) async => SyncResult(
          pushedCount: 0,
          pulledCount: 0,
          conflictCount: 0,
          errorCount: 0,
        ));

    // Crear 2 platos en catálogo y agregarlos al menú del día
    d1 = await dishesRepo.createDish(name: 'Sopa de Maní', price: 15.0);
    d2 = await dishesRepo.createDish(name: 'Majadito de Pato', price: 25.0);
    await dailyMenuRepo.createDailyMenu(
      menuDate: TimezoneUtils.getTodayBusinessDate(),
      dishIds: [d1.id, d2.id],
    );
  });

  tearDown(() async {
    await db.close();
  });

  testWidgets('NewOrderScreen supports +, -, direct editable quantity and preset chips with instant total calculation', (tester) async {
    final container = ProviderContainer(
      overrides: [
        databaseProvider.overrideWithValue(db),
        syncEngineProvider.overrideWithValue(mockSyncEngine),
        ordersRepositoryProvider.overrideWithValue(ordersRepo),
        dailyMenuRepositoryProvider.overrideWithValue(dailyMenuRepo),
      ],
    );

    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: const MaterialApp(
          home: Scaffold(
            body: NewOrderScreen(),
          ),
        ),
      ),
    );

    await tester.pumpAndSettle();

    expect(find.text('Nuevo Pedido de Cocina'), findsOneWidget);
    expect(find.text('Sopa de Maní'), findsOneWidget);
    expect(find.text('Majadito de Pato'), findsOneWidget);

    // Total inicial = Bs 0.00
    expect(find.text(CurrencyFormatter.formatBOB(0.0)), findsWidgets);

    // 1. Probar botón + (Sopa de Maní incrementa a 1)
    await tester.tap(find.byKey(Key('btn_add_${d1.id}')));
    await tester.pumpAndSettle();

    expect(find.text('1'), findsOneWidget);
    // Total = 1 * 15.0 = Bs 15.00
    expect(find.text(CurrencyFormatter.formatBOB(15.0)), findsWidgets);

    // 2. Probar botón - (Sopa de Maní decrementa a 0)
    await tester.tap(find.byKey(Key('btn_remove_${d1.id}')));
    await tester.pumpAndSettle();

    expect(find.text(CurrencyFormatter.formatBOB(0.0)), findsWidgets);

    // 3. Probar edición directa tocando la cantidad (tocar la caja con el número 0 de Majadito de Pato)
    await tester.tap(find.byKey(Key('qty_badge_${d2.id}')));
    await tester.pumpAndSettle();

    // Diálogo de edición debe estar abierto
    expect(find.text('Ingrese la cantidad de platos:'), findsOneWidget);

    // 4. Ingresar 120 directamente
    final dialogInput = find.byKey(const Key('quantity_dialog_input'));
    await tester.enterText(dialogInput, '120');
    await tester.tap(find.text('ACEPTAR'));
    await tester.pumpAndSettle();

    // El diálogo se cierra y la cantidad mostrada es 120
    expect(find.text('120'), findsOneWidget);
    // Total = 120 * 25.0 = Bs 3000.00
    expect(find.text(CurrencyFormatter.formatBOB(3000.0)), findsWidgets);

    // 5. Editar nuevamente y usar chip preset +50
    await tester.tap(find.byKey(Key('qty_badge_${d2.id}')));
    await tester.pumpAndSettle();

    expect(find.text('+50'), findsOneWidget);
    await tester.tap(find.text('+50'));
    await tester.pumpAndSettle();

    // Cantidad en diálogo ahora es 170 (120 + 50)
    await tester.tap(find.text('ACEPTAR'));
    await tester.pumpAndSettle();

    // El diálogo se cerró y ahora la cantidad mostrada en la pantalla es 170
    expect(find.text('170'), findsOneWidget);
    // Total = 170 * 25.0 = Bs 4250.00
    expect(find.text(CurrencyFormatter.formatBOB(4250.0)), findsWidgets);

    // 6. Guardar pedido
    await tester.enterText(find.byType(TextField).first, 'Mesa 10 Grande');
    await tester.tap(find.text('GUARDAR PEDIDO'));
    await tester.pump();
    await tester.pump(const Duration(seconds: 4));

    // Verificar en SQLite (OrderSummaryModel)
    final orders = await ordersRepo.watchTodayOrders().first;
    expect(orders.length, equals(1));
    expect(orders.first.customerName, equals('Mesa 10 Grande'));
    expect(orders.first.itemsCount, equals(1));
    expect(orders.first.total, equals(4250.0));

    // Verificar detalle completo con OrderModel
    final fullOrder = await ordersRepo.getOrderById(orders.first.id);
    expect(fullOrder, isNotNull);
    expect(fullOrder!.items.length, equals(1));
    expect(fullOrder.items.first.quantity, equals(170));
    expect(fullOrder.items.first.dishNameSnapshot, equals('Majadito de Pato'));

    await tester.pumpWidget(const SizedBox());
    container.dispose();
  });
}
