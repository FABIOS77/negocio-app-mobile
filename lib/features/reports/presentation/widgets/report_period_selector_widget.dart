import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import '../../../../core/utils/timezone_utils.dart';
import '../../application/excel_export_notifier.dart';

class ReportPeriodSelectorWidget extends ConsumerWidget {
  const ReportPeriodSelectorWidget({super.key});

  Future<void> _pickCustomDateRange(BuildContext context, WidgetRef ref) async {
    final nowLaPaz = TimezoneUtils.getNowLaPaz();
    final customFrom = ref.read(reportCustomDateFromProvider);
    final customTo = ref.read(reportCustomDateToProvider);

    DateTime initialStartDate = customFrom != null ? DateTime.parse(customFrom) : nowLaPaz;
    DateTime initialEndDate = customTo != null ? DateTime.parse(customTo) : nowLaPaz;

    if (initialStartDate.isAfter(initialEndDate)) {
      initialStartDate = initialEndDate;
    }

    final picked = await showDateRangePicker(
      context: context,
      initialDateRange: DateTimeRange(start: initialStartDate, end: initialEndDate),
      firstDate: DateTime(2020),
      lastDate: DateTime(2035),
      helpText: 'SELECCIONAR RANGO DE FECHAS',
      cancelText: 'CANCELAR',
      confirmText: 'CONFIRMAR',
      builder: (context, child) {
        return Theme(
          data: Theme.of(context).copyWith(
            colorScheme: Theme.of(context).colorScheme.copyWith(
                  primary: const Color(0xFF1D6F42),
                  onPrimary: Colors.white,
                ),
          ),
          child: child!,
        );
      },
    );

    if (picked != null) {
      final fromStr = DateFormat('yyyy-MM-dd').format(picked.start);
      final toStr = DateFormat('yyyy-MM-dd').format(picked.end);

      ref.read(reportCustomDateFromProvider.notifier).state = fromStr;
      ref.read(reportCustomDateToProvider.notifier).state = toStr;
      ref.read(reportSelectedPresetProvider.notifier).state = ReportPeriodPreset.custom;
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final selectedPreset = ref.watch(reportSelectedPresetProvider);
    final dateRange = ref.watch(reportDateRangeProvider);

    final displayFrom = TimezoneUtils.formatDisplayDate(dateRange.from);
    final displayTo = TimezoneUtils.formatDisplayDate(dateRange.to);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Seleccionar Período:',
          style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15),
        ),
        const SizedBox(height: 10),
        SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: Row(
            children: [
              ChoiceChip(
                label: const Text('Hoy'),
                selected: selectedPreset == ReportPeriodPreset.today,
                onSelected: (selected) {
                  if (selected) {
                    ref.read(reportSelectedPresetProvider.notifier).state = ReportPeriodPreset.today;
                  }
                },
              ),
              const SizedBox(width: 8),
              ChoiceChip(
                label: const Text('Ayer'),
                selected: selectedPreset == ReportPeriodPreset.yesterday,
                onSelected: (selected) {
                  if (selected) {
                    ref.read(reportSelectedPresetProvider.notifier).state = ReportPeriodPreset.yesterday;
                  }
                },
              ),
              const SizedBox(width: 8),
              ChoiceChip(
                label: const Text('Esta Semana'),
                selected: selectedPreset == ReportPeriodPreset.thisWeek,
                onSelected: (selected) {
                  if (selected) {
                    ref.read(reportSelectedPresetProvider.notifier).state = ReportPeriodPreset.thisWeek;
                  }
                },
              ),
              const SizedBox(width: 8),
              ChoiceChip(
                label: const Text('Este Mes'),
                selected: selectedPreset == ReportPeriodPreset.thisMonth,
                onSelected: (selected) {
                  if (selected) {
                    ref.read(reportSelectedPresetProvider.notifier).state = ReportPeriodPreset.thisMonth;
                  }
                },
              ),
              const SizedBox(width: 8),
              ChoiceChip(
                avatar: const Icon(Icons.date_range, size: 16),
                label: const Text('Personalizado'),
                selected: selectedPreset == ReportPeriodPreset.custom,
                onSelected: (selected) {
                  if (selected) {
                    ref.read(reportSelectedPresetProvider.notifier).state = ReportPeriodPreset.custom;
                    _pickCustomDateRange(context, ref);
                  }
                },
              ),
            ],
          ),
        ),
        const SizedBox(height: 16),
        InkWell(
          onTap: () => _pickCustomDateRange(context, ref),
          borderRadius: BorderRadius.circular(10),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
            decoration: BoxDecoration(
              color: Colors.green.shade50,
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: Colors.green.shade200),
            ),
            child: Row(
              children: [
                Icon(Icons.calendar_month, color: Colors.green.shade800, size: 24),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Periodo seleccionado:',
                        style: TextStyle(
                          fontSize: 12,
                          color: Colors.green.shade900,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        '$displayFrom   ➔   $displayTo',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                          color: Colors.green.shade900,
                          letterSpacing: 0.5,
                        ),
                      ),
                    ],
                  ),
                ),
                TextButton.icon(
                  onPressed: () => _pickCustomDateRange(context, ref),
                  icon: const Icon(Icons.edit_calendar, size: 18),
                  label: const Text('Cambiar'),
                  style: TextButton.styleFrom(
                    foregroundColor: const Color(0xFF1D6F42),
                    textStyle: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}
