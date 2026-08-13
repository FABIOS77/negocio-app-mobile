import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:katering_grecia_app/features/dashboard/presentation/dashboard_screen.dart';

void main() {
  testWidgets('DashboardScreen renders correctly and shows summary cards', (WidgetTester tester) async {
    await tester.pumpWidget(
      const ProviderScope(
        child: MaterialApp(
          home: DashboardScreen(),
        ),
      ),
    );

    expect(find.text('Katering Grecia'), findsOneWidget);
    expect(find.text('Resumen Ejecutivo'), findsOneWidget);
    expect(find.text('Accesos Rápidos Cocina'), findsOneWidget);
  });
}
