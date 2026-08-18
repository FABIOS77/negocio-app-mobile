import 'package:drift/drift.dart';
import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

import 'package:katering_grecia_app/core/database/app_database.dart';
import 'package:katering_grecia_app/core/sync/sync_engine.dart';
import 'package:katering_grecia_app/core/sync/sync_queue_manager.dart';
import 'package:katering_grecia_app/features/orders/application/orders_notifier.dart';
import 'package:katering_grecia_app/features/orders/data/orders_repository.dart';
import 'package:katering_grecia_app/features/orders/presentation/order_history_screen.dart';

class MockSyncEngine extends Mock implements SyncEngine {}

void main() {
  late AppDatabase db;
  late SyncQueueManager queueManager;
  late MockSyncEngine mockSyncEngine;
  late OrdersRepository ordersRepo;

  setUp(() async {
    db = AppDatabase(NativeDatabase.memory());
    queueManager = SyncQueueManager(db);
    mockSyncEngine = MockSyncEngine();
    ordersRepo = OrdersRepository(db: db, queueManager: queueManager, syncEngine: mockSyncEngine);

    when(() => mockSyncEngine.syncAll()).thenAnswer((_) async => SyncResult(
          pushedCount: 0,
          pulledCount: 0,
          conflictCount: 0,
          errorCount: 0,
        ));

    // Precargar 60 pedidos para probar paginación de 50 -> 100
    final now = DateTime.now().toUtc();
    await db.batch((batch) {
      for (int i = 1; i <= 60; i++) {
        batch.insert(
          db.ordersTable,
          OrdersTableCompanion.insert(
            id: 'order-hist-$i',
            orderNumber: Value('$i'),
            customerName: 'Cliente Historial #$i',
            total: 20.0,
            paymentMethod: 'CASH',
            status: 'PENDING',
            orderedAt: now.subtract(Duration(minutes: i)),
            createdBy: 'user',
            createdAt: now,
            updatedAt: now,
          ),
        );
      }
    });
  });

  tearDown(() async {
    await db.close();
  });

  testWidgets('OrderHistoryScreen renders first 50 items and scrolls to load remaining items via infinite scroll', (tester) async {
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
        child: const MaterialApp(
          home: OrderHistoryScreen(),
        ),
      ),
    );

    await tester.pumpAndSettle();

    // 1. Verificar que el límite inicial es 50
    expect(container.read(orderHistoryLimitProvider), equals(50));
    expect(find.text('Cliente Historial #1'), findsOneWidget);

    // 2. Hacer scroll hasta el final para disparar el listener de paginación
    await tester.drag(find.byType(ListView), const Offset(0, -3000));
    await tester.pumpAndSettle();

    // 3. El límite debe haberse incrementado a 100 y el item #60 debe estar visible o disponible
    expect(container.read(orderHistoryLimitProvider), greaterThanOrEqualTo(100));

    container.dispose();
  });
}
