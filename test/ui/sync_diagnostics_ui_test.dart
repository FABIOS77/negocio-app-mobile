import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:katering_grecia_app/features/common/presentation/widgets/confirm_dialog.dart';
import 'package:katering_grecia_app/features/sync/presentation/sync_diagnostics_screen.dart';

void main() {
  testWidgets('SyncDiagnosticsScreen renders correctly', (WidgetTester tester) async {
    await tester.pumpWidget(
      const ProviderScope(
        child: MaterialApp(
          home: SyncDiagnosticsScreen(),
        ),
      ),
    );

    expect(find.text('Diagnóstico de Sincronización'), findsOneWidget);
  });

  testWidgets('ConfirmDialog displays title, content and buttons', (WidgetTester tester) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: Builder(
            builder: (context) {
              return ElevatedButton(
                onPressed: () {
                  ConfirmDialog.show(
                    context,
                    title: 'Cancelar Pedido',
                    content: '¿Está seguro de cancelar el pedido?',
                  );
                },
                child: const Text('Abrir'),
              );
            },
          ),
        ),
      ),
    );

    await tester.tap(find.text('Abrir'));
    await tester.pumpAndSettle();

    expect(find.text('Cancelar Pedido'), findsOneWidget);
    expect(find.text('¿Está seguro de cancelar el pedido?'), findsOneWidget);
    expect(find.text('CONFIRMAR'), findsOneWidget);
    expect(find.text('Cancelar'), findsOneWidget);
  });
}
