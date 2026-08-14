import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:katering_grecia_app/features/dishes/application/dishes_notifier.dart';
import 'package:katering_grecia_app/features/dishes/domain/dish_model.dart';
import 'package:katering_grecia_app/features/dishes/presentation/dishes_screen.dart';

void main() {
  testWidgets('DishesScreen displays FloatingActionButton and opens creation dialog on tap', (WidgetTester tester) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          dishesStreamProvider.overrideWith((ref) => Stream.value(<DishModel>[])),
        ],
        child: MaterialApp(
          theme: ThemeData(),
          home: const DishesScreen(),
        ),
      ),
    );
    await tester.pumpAndSettle();

    // 1. Verificar que el FloatingActionButton de creación existe
    final fabFinder = find.byKey(const Key('addDishFab'));
    expect(fabFinder, findsOneWidget);
    expect(find.text('NUEVO PLATO'), findsOneWidget);

    // 2. Tocar el FAB para abrir el diálogo de creación
    await tester.tap(fabFinder);
    await tester.pumpAndSettle();

    // 3. Verificar que se abrió el diálogo DishDetailDialog en modo creación
    expect(find.text('Nuevo Plato Offline'), findsOneWidget);
    expect(find.byKey(const Key('dishNameField')), findsOneWidget);
    expect(find.byKey(const Key('dishPriceField')), findsOneWidget);
  });
}
