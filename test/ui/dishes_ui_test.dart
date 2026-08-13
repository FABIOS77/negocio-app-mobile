import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:katering_grecia_app/features/dishes/presentation/dishes_screen.dart';

void main() {
  testWidgets('DishesScreen displays FloatingActionButton and opens creation dialog on tap', (WidgetTester tester) async {
    await tester.pumpWidget(
      ProviderScope(
        child: MaterialApp(
          theme: ThemeData(),
          home: const DishesScreen(),
        ),
      ),
    );
    await tester.pump(const Duration(milliseconds: 200));

    // 1. Verificar que el FloatingActionButton de creación existe
    final fabFinder = find.byKey(const Key('addDishFab'));
    expect(fabFinder, findsOneWidget);
    expect(find.text('NUEVO PLATO'), findsOneWidget);

    // 2. Tocar el FAB para abrir el diálogo de creación
    await tester.tap(fabFinder);
    await tester.pump(const Duration(milliseconds: 200));

    // 3. Verificar que se abrió el diálogo DishDetailDialog en modo creación
    expect(find.text('Nuevo Plato Offline'), findsOneWidget);
    expect(find.byKey(const Key('dishNameField')), findsOneWidget);
    expect(find.byKey(const Key('dishPriceField')), findsOneWidget);
  });
}
