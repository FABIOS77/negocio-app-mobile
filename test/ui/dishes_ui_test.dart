import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:katering_grecia_app/features/dishes/presentation/dishes_screen.dart';

void main() {
  testWidgets('DishesScreen renders correctly and shows search bar', (WidgetTester tester) async {
    await tester.pumpWidget(
      const ProviderScope(
        child: MaterialApp(
          home: DishesScreen(),
        ),
      ),
    );

    expect(find.text('Catálogo de Platos'), findsOneWidget);
    expect(find.byType(TextField), findsOneWidget);
    expect(find.text('NUEVO PLATO'), findsOneWidget);
  });
}
