import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:katering_grecia_app/features/dishes/presentation/dish_detail_dialog.dart';

void main() {
  testWidgets('DishDetailDialog validates required fields, numeric price > 0 and http/https imageUrl', (WidgetTester tester) async {
    bool onSaveCalled = false;
    String? savedName;
    double? savedPrice;
    String? savedImageUrl;

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: DishDetailDialog(
            onSave: (name, description, price, imageUrl) {
              onSaveCalled = true;
              savedName = name;
              savedPrice = price;
              savedImageUrl = imageUrl;
            },
          ),
        ),
      ),
    );

    // 1. Tocar CREAR PLATO con campos vacíos -> Debería fallar
    await tester.tap(find.text('CREAR PLATO'));
    await tester.pump();

    expect(find.text('El nombre del plato es obligatorio'), findsOneWidget);
    expect(find.text('El precio es obligatorio'), findsOneWidget);
    expect(onSaveCalled, isFalse);

    // 2. Ingresar precio <= 0 o texto no numérico
    await tester.enterText(find.byKey(const Key('dishNameField')), 'Sopa de Maní');
    await tester.enterText(find.byKey(const Key('dishPriceField')), '-15.5');
    await tester.tap(find.text('CREAR PLATO'));
    await tester.pump();

    expect(find.text('El precio debe ser estrictamente mayor a 0'), findsOneWidget);
    expect(onSaveCalled, isFalse);

    // 3. Ingresar URL malformada
    await tester.enterText(find.byKey(const Key('dishPriceField')), '18.50');
    await tester.enterText(find.byKey(const Key('dishImageUrlField')), 'invalid-url-text');
    await tester.tap(find.text('CREAR PLATO'));
    await tester.pump();

    expect(find.text('URL inválida. Debe comenzar con http:// o https://'), findsOneWidget);
    expect(onSaveCalled, isFalse);

    // 4. Ingresar datos válidos
    await tester.enterText(find.byKey(const Key('dishImageUrlField')), 'https://ejemplo.com/plato.jpg');
    await tester.tap(find.text('CREAR PLATO'));
    await tester.pump();

    expect(onSaveCalled, isTrue);
    expect(savedName, equals('Sopa de Maní'));
    expect(savedPrice, equals(18.50));
    expect(savedImageUrl, equals('https://ejemplo.com/plato.jpg'));
  });
}
