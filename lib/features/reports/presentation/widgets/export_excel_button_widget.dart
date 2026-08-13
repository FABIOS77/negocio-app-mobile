import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../application/excel_export_notifier.dart';

class ExportExcelButtonWidget extends ConsumerWidget {
  final String? dateFrom;
  final String? dateTo;

  const ExportExcelButtonWidget({
    super.key,
    this.dateFrom,
    this.dateTo,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final isExporting = ref.watch(isExportingExcelProvider);
    final exportService = ref.watch(excelExportServiceProvider);

    return ElevatedButton.icon(
      style: ElevatedButton.styleFrom(
        backgroundColor: Colors.green.shade700,
        foregroundColor: Colors.white,
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        elevation: 3,
      ),
      icon: isExporting
          ? const SizedBox(
              width: 20,
              height: 20,
              child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2),
            )
          : const Icon(Icons.table_chart, size: 22),
      label: Text(
        isExporting ? 'Generando Excel...' : 'Exportar a Excel (.xlsx)',
        style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15),
      ),
      onPressed: isExporting
          ? null
          : () async {
              ref.read(isExportingExcelProvider.notifier).state = true;
              try {
                await exportService.downloadAndShareExcel(
                  dateFrom: dateFrom,
                  dateTo: dateTo,
                );
              } catch (e) {
                if (context.mounted) {
                  final errorMessage = e is StateError ? e.message : 'Error al exportar reporte Excel: $e';
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text(errorMessage),
                      backgroundColor: Colors.redAccent,
                      duration: const Duration(seconds: 4),
                    ),
                  );
                }
              } finally {
                ref.read(isExportingExcelProvider.notifier).state = false;
              }
            },
    );
  }
}
