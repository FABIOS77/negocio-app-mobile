import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:katering_grecia_app/core/utils/currency_formatter.dart';
import 'package:katering_grecia_app/features/expenses/domain/expense_category_model.dart';
import 'package:katering_grecia_app/features/expenses/presentation/expense_detail_dialog.dart';

void main() {
  final testCategories = [
    ExpenseCategoryModel(
      id: 'cat-1',
      name: 'Insumos de Cocina',
      active: true,
      version: 1,
      createdAt: DateTime.now(),
      updatedAt: DateTime.now(),
    ),
    ExpenseCategoryModel(
      id: 'cat-2',
      name: 'Servicios Básicos',
      active: true,
      version: 1,
      createdAt: DateTime.now(),
      updatedAt: DateTime.now(),
    ),
  ];

  testWidgets('ExpenseDetailDialog renders smoothly without RenderIntrinsicWidth errors', (tester) async {
    await tester.pumpWidget(
      ProviderScope(
        child: MaterialApp(
          home: Scaffold(
            body: ExpenseDetailDialog(
              categories: testCategories,
              onSave: (_, __, ___, ____, _____) {},
            ),
          ),
        ),
      ),
    );

    await tester.pumpAndSettle();

    expect(find.text('Nuevo Gasto Offline'), findsOneWidget);
    expect(find.text('Monto (BOB) *'), findsOneWidget);
    expect(find.text('Desglosar'), findsOneWidget);
  });

  testWidgets('ExpenseBreakdownModal supports adding, editing, deleting and applying items without overflow', (tester) async {
    List<double>? returnedItems;

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: Builder(
            builder: (context) => ElevatedButton(
              onPressed: () async {
                returnedItems = await showDialog<List<double>>(
                  context: context,
                  builder: (_) => const ExpenseBreakdownModal(initialItems: []),
                );
              },
              child: const Text('Abrir Desglose'),
            ),
          ),
        ),
      ),
    );

    // Abrir modal
    await tester.tap(find.text('Abrir Desglose'));
    await tester.pumpAndSettle();

    expect(find.text('Desglose de Importes'), findsOneWidget);

    // 1. Agregar 30.00
    final inputFinder = find.byType(TextField);
    await tester.enterText(inputFinder, '30.00');
    await tester.tap(find.text('Agregar'));
    await tester.pumpAndSettle();

    expect(find.text(CurrencyFormatter.formatBOB(30.0)), findsWidgets);
    expect(find.text('Total (1 importe):'), findsOneWidget);

    // 2. Agregar 50.00
    await tester.enterText(inputFinder, '50.00');
    await tester.tap(find.text('Agregar'));
    await tester.pumpAndSettle();

    expect(find.text('Total (2 importes):'), findsOneWidget);
    expect(find.text(CurrencyFormatter.formatBOB(80.0)), findsWidgets);

    // 3. Agregar 40.00
    await tester.enterText(inputFinder, '40.00');
    await tester.tap(find.text('Agregar'));
    await tester.pumpAndSettle();

    expect(find.text('Total (3 importes):'), findsOneWidget);
    expect(find.text(CurrencyFormatter.formatBOB(120.0)), findsWidgets);

    // 4. Eliminar el segundo elemento (50.00)
    final deleteButtons = find.byIcon(Icons.delete_outline);
    expect(deleteButtons, findsNWidgets(3));
    await tester.tap(deleteButtons.at(1));
    await tester.pumpAndSettle();

    // Total debe ser 30 + 40 = 70
    expect(find.text('Total (2 importes):'), findsOneWidget);
    expect(find.text(CurrencyFormatter.formatBOB(70.0)), findsWidgets);

    // 5. Aplicar al gasto
    await tester.tap(find.text('APLICAR AL GASTO'));
    await tester.pumpAndSettle();

    expect(returnedItems, isNotNull);
    expect(returnedItems!.length, equals(2));
    expect(returnedItems!.reduce((a, b) => a + b), equals(70.0));
  });

  testWidgets('ExpenseBreakdownModal handles 30 items without UI crash', (tester) async {
    final thirtyItems = List.generate(30, (i) => (i + 1) * 5.0);

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: ExpenseBreakdownModal(initialItems: thirtyItems),
        ),
      ),
    );

    await tester.pumpAndSettle();

    expect(find.text('Desglose de Importes'), findsOneWidget);
    expect(find.text('Total (30 importes):'), findsOneWidget);
  });
}
