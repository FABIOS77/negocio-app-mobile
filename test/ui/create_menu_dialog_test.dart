import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:katering_grecia_app/features/daily_menu/presentation/create_menu_dialog.dart';
import 'package:katering_grecia_app/features/dishes/domain/dish_model.dart';

void main() {
  final now = DateTime.now().toUtc();
  final d1 = DishModel(id: 'd1', name: 'Sopa de Maní', price: 15.0, active: true, createdAt: now, updatedAt: now);
  final d2 = DishModel(id: 'd2', name: 'Pique Macho', price: 40.0, active: true, createdAt: now, updatedAt: now);
  final d3 = DishModel(id: 'd3', name: 'Pollo al Horno', price: 25.0, active: true, createdAt: now, updatedAt: now);
  final d4 = DishModel(id: 'd4', name: 'Silpancho Cochabambino', price: 30.0, active: true, createdAt: now, updatedAt: now);
  final dInactive = DishModel(id: 'd_inact', name: 'Plato Inactivo', price: 10.0, active: false, createdAt: now, updatedAt: now);

  final testDishes = [d1, d2, d3, d4, dInactive];

  group('CreateMenuDialog Comprehensive Tests', () {
    testWidgets('CASO 1 & 9: Opens without selection, displays only active dishes and 0 selected counter', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: CreateMenuDialog(
              initialDate: '2026-08-20',
              availableDishes: testDishes,
              onSave: (_, __) {},
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('Menú Diario Offline'), findsOneWidget);
      expect(find.text('0 seleccionados'), findsOneWidget);
      expect(find.text('2026-08-20'), findsOneWidget);

      // Platos activos visibles
      expect(find.text('Sopa de Maní'), findsOneWidget);
      expect(find.text('Pique Macho'), findsOneWidget);
      expect(find.text('Pollo al Horno'), findsOneWidget);
      expect(find.text('Silpancho Cochabambino'), findsOneWidget);

      // Plato inactivo NO debe aparecer
      expect(find.text('Plato Inactivo'), findsNothing);
    });

    testWidgets('CASO 2, 3, 4 & 5: Case-insensitive search, persistence of selections across searches and clear button', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: CreateMenuDialog(
              initialDate: '2026-08-20',
              availableDishes: testDishes,
              onSave: (_, __) {},
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      // 1. Seleccionar Pollo al Horno y Pique Macho
      await tester.tap(find.text('Pollo al Horno'));
      await tester.tap(find.text('Pique Macho'));
      await tester.pumpAndSettle();

      expect(find.text('2 seleccionados'), findsOneWidget);

      // 2. Buscar "SOPA" (case insensitive)
      final searchInput = find.widgetWithText(TextField, 'Buscar plato...');
      await tester.enterText(searchInput, 'SOPA');
      await tester.pumpAndSettle();

      // Solo Sopa de Maní debe estar en la lista filtrada
      expect(find.text('Sopa de Maní'), findsOneWidget);
      expect(find.text('Pique Macho'), findsNothing);
      expect(find.text('Pollo al Horno'), findsNothing);

      // El contador sigue mostrando el total global de 2
      expect(find.text('2 seleccionados'), findsOneWidget);

      // 3. Seleccionar Sopa de Maní mientras está filtrado
      await tester.tap(find.text('Sopa de Maní'));
      await tester.pumpAndSettle();

      // Contador incrementa a 3
      expect(find.text('3 seleccionados'), findsOneWidget);

      // 4. Limpiar búsqueda usando el botón X suffixIcon
      await tester.tap(find.byIcon(Icons.clear));
      await tester.pumpAndSettle();

      // Todos los platos vuelven a aparecer
      expect(find.text('Sopa de Maní'), findsOneWidget);
      expect(find.text('Pique Macho'), findsOneWidget);
      expect(find.text('Pollo al Horno'), findsOneWidget);
      expect(find.text('Silpancho Cochabambino'), findsOneWidget);

      // Los 3 platos previamente seleccionados continúan seleccionados y el contador muestra 3
      expect(find.text('3 seleccionados'), findsOneWidget);
    });

    testWidgets('CASO 6 & 7: initialSelectedDishIds pre-populates selection and allows deselecting', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: CreateMenuDialog(
              initialDate: '2026-08-20',
              availableDishes: testDishes,
              initialSelectedDishIds: const ['d1', 'd2'],
              onSave: (_, __) {},
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('2 seleccionados'), findsOneWidget);

      // Deseleccionar Pique Macho (d2)
      await tester.tap(find.text('Pique Macho'));
      await tester.pumpAndSettle();

      expect(find.text('1 seleccionados'), findsOneWidget);
    });

    testWidgets('CASO 8: Search for non-existent text displays empty search state', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: CreateMenuDialog(
              initialDate: '2026-08-20',
              availableDishes: testDishes,
              onSave: (_, __) {},
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      final searchInput = find.widgetWithText(TextField, 'Buscar plato...');
      await tester.enterText(searchInput, 'Pizza Hawaiana');
      await tester.pumpAndSettle();

      expect(find.text('No se encontraron platos con esa búsqueda'), findsOneWidget);
    });

    testWidgets('CASO 9: Empty active dishes list shows appropriate message', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: CreateMenuDialog(
              initialDate: '2026-08-20',
              availableDishes: [dInactive],
              onSave: (_, __) {},
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('No hay platos activos guardados en SQLite.'), findsOneWidget);
    });

    testWidgets('CASO 10, 11, 12 & 13: Date editing, validation and successful submit onSave callback', (tester) async {
      String? savedDate;
      List<String>? savedDishes;

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: CreateMenuDialog(
              initialDate: '2026-08-20',
              availableDishes: testDishes,
              onSave: (date, dishes) {
                savedDate = date;
                savedDishes = dishes;
              },
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      // 1. Intentar guardar sin platos seleccionados (CASO 12)
      await tester.tap(find.text('GUARDAR MENÚ'));
      await tester.pumpAndSettle();

      expect(find.text('Seleccione la fecha y al menos un plato'), findsOneWidget);
      expect(savedDate, isNull);

      // 2. Modificar fecha a fecha futura (CASO 10)
      final dateInput = find.widgetWithText(TextField, 'Fecha de Negocio (YYYY-MM-DD)');
      await tester.enterText(dateInput, '2026-09-01');
      await tester.pumpAndSettle();

      // 3. Seleccionar platos
      await tester.tap(find.text('Pique Macho'));
      await tester.pumpAndSettle();

      // 4. Guardar correctamente (CASO 13)
      await tester.tap(find.text('GUARDAR MENÚ'));
      await tester.pump();

      expect(savedDate, equals('2026-09-01'));
      expect(savedDishes, equals(['d2']));
    });

    testWidgets('CASO 14: Random draw onRandomDraw triggers callback and closes dialog', (tester) async {
      bool drawTriggered = false;

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: CreateMenuDialog(
              initialDate: '2026-08-20',
              availableDishes: testDishes,
              onRandomDraw: () {
                drawTriggered = true;
              },
              onSave: (_, __) {},
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.byIcon(Icons.shuffle), findsOneWidget);
      await tester.tap(find.byIcon(Icons.shuffle));
      await tester.pump();

      expect(drawTriggered, isTrue);
    });
  });
}
