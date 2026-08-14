import 'package:flutter/material.dart';
import '../../financial_metrics/presentation/widgets/financial_summary_card.dart';
import 'widgets/export_excel_button_widget.dart';

class ReportsScreen extends StatelessWidget {
  const ReportsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Reportes de Negocio', style: TextStyle(fontWeight: FontWeight.bold)),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const FinancialSummaryCard(),
            const SizedBox(height: 20),
            Card(
              elevation: 2,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              child: Padding(
                padding: const EdgeInsets.all(16.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: const [
                    Wrap(
                      crossAxisAlignment: WrapCrossAlignment.center,
                      spacing: 8,
                      runSpacing: 4,
                      children: [
                        Icon(Icons.assessment, color: Colors.deepOrange, size: 28),
                        Text('Exportación de Reportes Financieros', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                      ],
                    ),
                    SizedBox(height: 8),
                    Text(
                      'Descargue el libro oficial en Excel (.xlsx) con 4 hojas detalladas: Resumen Financiero, Pedidos, Gastos y Desglose por Platos.',
                      style: TextStyle(color: Colors.grey, fontSize: 13),
                    ),
                    SizedBox(height: 16),
                    Center(child: ExportExcelButtonWidget()),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
