import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

import 'package:katering_grecia_app/core/database/app_database.dart';
import 'package:katering_grecia_app/core/sync/sync_engine.dart';
import 'package:katering_grecia_app/core/sync/sync_queue_manager.dart';
import 'package:katering_grecia_app/features/dishes/application/dishes_notifier.dart';
import 'package:katering_grecia_app/features/dishes/data/dishes_repository.dart';
import 'package:katering_grecia_app/features/dishes/presentation/dishes_screen.dart';

class MockSyncEngine extends Mock implements SyncEngine {}

void main() {
  late AppDatabase db;
  late SyncQueueManager queueManager;
  late MockSyncEngine mockSyncEngine;
  late DishesRepository dishesRepo;

  setUp(() async {
    db = AppDatabase(NativeDatabase.memory());
    queueManager = SyncQueueManager(db);
    mockSyncEngine = MockSyncEngine();
    dishesRepo = DishesRepository(db: db, queueManager: queueManager, syncEngine: mockSyncEngine);

    when(() => mockSyncEngine.syncAll()).thenAnswer((_) async => SyncResult(
          pushedCount: 0,
          pulledCount: 0,
          conflictCount: 0,
          errorCount: 0,
        ));

    // Crear 2 platos de prueba en SQLite
    await dishesRepo.createDish(name: 'Sopa de Maní', price: 15.0);
    await dishesRepo.createDish(name: 'Majadito de Pato', price: 25.0);
  });

  tearDown(() async {
    await db.close();
  });

  testWidgets('DishesScreen resets search query and displays all dishes upon re-entering screen', (tester) async {
    final container = ProviderContainer(
      overrides: [
        databaseProvider.overrideWithValue(db),
        syncEngineProvider.overrideWithValue(mockSyncEngine),
        dishesRepositoryProvider.overrideWithValue(dishesRepo),
      ],
    );

    // 1. Renderizar DishesScreen inicialmente
    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: const MaterialApp(
          home: DishesScreen(),
        ),
      ),
    );

    await tester.pumpAndSettle();

    // Catálogo inicial muestra ambos platos
    expect(find.text('Sopa de Maní'), findsOneWidget);
    expect(find.text('Majadito de Pato'), findsOneWidget);

    // 2. Buscar "Sopa"
    await tester.enterText(find.byType(TextField), 'Sopa');
    await tester.pumpAndSettle();

    expect(find.text('Sopa de Maní'), findsOneWidget);
    expect(find.text('Majadito de Pato'), findsNothing);

    // 3. Simular navegación a otra pantalla (desmontar DishesScreen)
    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: const MaterialApp(
          home: Scaffold(body: Text('Otra Pantalla')),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Otra Pantalla'), findsOneWidget);
    expect(find.text('Sopa de Maní'), findsNothing);

    // 4. Volver a DishesScreen
    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: const MaterialApp(
          home: DishesScreen(),
        ),
      ),
    );
    await tester.pumpAndSettle();

    // 5. El campo de búsqueda debe estar vacío y mostrar TODOS los platos
    final searchField = tester.widget<TextField>(find.byType(TextField));
    expect(searchField.controller?.text ?? '', isEmpty);
    expect(find.text('Sopa de Maní'), findsOneWidget);
    expect(find.text('Majadito de Pato'), findsOneWidget);
  });
}
