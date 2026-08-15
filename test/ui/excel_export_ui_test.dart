import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:katering_grecia_app/features/reports/presentation/widgets/export_excel_button_widget.dart';
import 'package:katering_grecia_app/features/reports/presentation/widgets/report_period_selector_widget.dart';

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

    expect(find.text('EXPORTAR A EXCEL (.XLSX)'), findsOneWidget);
    expect(find.byIcon(Icons.table_chart), findsOneWidget);
  });

  testWidgets('ReportPeriodSelectorWidget renders presets correctly', (WidgetTester tester) async {
    await tester.pumpWidget(
      const ProviderScope(
        child: MaterialApp(
          home: Scaffold(
            body: SingleChildScrollView(
              child: ReportPeriodSelectorWidget(),
            ),
          ),
        ),
      ),
    );

    expect(find.text('Seleccionar Período:'), findsOneWidget);
    expect(find.text('Hoy'), findsOneWidget);
    expect(find.text('Ayer'), findsOneWidget);
    expect(find.text('Esta Semana'), findsOneWidget);
    expect(find.text('Este Mes'), findsOneWidget);
    expect(find.text('Personalizado'), findsOneWidget);
    expect(find.text('Periodo seleccionado:'), findsOneWidget);
  });
}
