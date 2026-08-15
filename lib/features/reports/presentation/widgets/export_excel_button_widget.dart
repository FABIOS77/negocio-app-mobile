import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../core/utils/network_error_parser.dart';
import '../../../../core/utils/timezone_utils.dart';
import '../../application/excel_export_notifier.dart';

class ExportExcelButtonWidget extends ConsumerWidget {
  const ExportExcelButtonWidget({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final isExporting = ref.watch(isExportingExcelProvider);
    final exportService = ref.watch(excelExportServiceProvider);
    final dateRange = ref.watch(reportDateRangeProvider);

    return SizedBox(
      width: double.infinity,
      child: ElevatedButton.icon(
        style: ElevatedButton.styleFrom(
          backgroundColor: const Color(0xFF1D6F42), // Verde corporativo Excel
          foregroundColor: Colors.white,
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
          elevation: 3,
        ),
        icon: isExporting
            ? const SizedBox(
                width: 22,
                height: 22,
                child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2.5),
              )
            : const Icon(Icons.table_chart, size: 24),
        label: Text(
          isExporting ? 'GENERANDO EXCEL...' : 'EXPORTAR A EXCEL (.XLSX)',
          style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16, letterSpacing: 0.5),
        ),
        onPressed: isExporting
            ? null
            : () async {
                // Validar que date_from <= date_to
                if (dateRange.from.compareTo(dateRange.to) > 0) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text('La fecha inicial no puede ser posterior a la fecha final.'),
                      backgroundColor: Colors.redAccent,
                    ),
                  );
                  return;
                }

                ref.read(isExportingExcelProvider.notifier).state = true;
                try {
                  await exportService.downloadAndShareExcel(
                    dateFrom: dateRange.from,
                    dateTo: dateRange.to,
                  );

                  if (context.mounted) {
                    final fromFormatted = TimezoneUtils.formatDisplayDate(dateRange.from);
                    final toFormatted = TimezoneUtils.formatDisplayDate(dateRange.to);
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: Text('Reporte ($fromFormatted - $toFormatted) exportado exitosamente.'),
                        backgroundColor: Colors.green.shade700,
                        duration: const Duration(seconds: 4),
                      ),
                    );
                  }
                } catch (e) {
                  if (context.mounted) {
                    final errorMessage = e is StateError
                        ? e.message
                        : (e is ArgumentError
                            ? e.message.toString()
                            : NetworkErrorParser.parse(e, fallback: 'Error al exportar reporte Excel.'));
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: Text(errorMessage),
                        backgroundColor: Colors.redAccent,
                        duration: const Duration(seconds: 5),
                      ),
                    );
                  }
                } finally {
                  ref.read(isExportingExcelProvider.notifier).state = false;
                }
              },
      ),
    );
  }
}
