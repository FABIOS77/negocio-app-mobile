import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:katering_grecia_app/features/reports/presentation/widgets/export_excel_button_widget.dart';

void main() {
  testWidgets('ExportExcelButtonWidget renders correctly', (WidgetTester tester) async {
    await tester.pumpWidget(
      const ProviderScope(
        child: MaterialApp(
          home: Scaffold(
            body: ExportExcelButtonWidget(),
          ),
        ),
      ),
    );

    expect(find.text('Exportar a Excel (.xlsx)'), findsOneWidget);
    expect(find.byIcon(Icons.table_chart), findsOneWidget);
  });
}
