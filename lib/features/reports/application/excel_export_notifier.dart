import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/network/dio_client.dart';
import '../../../core/sync/sync_engine.dart';
import '../../../core/utils/timezone_utils.dart';
import '../data/excel_export_service.dart';

enum ReportPeriodPreset {
  today,
  yesterday,
  thisWeek,
  thisMonth,
  custom,
}

final excelExportServiceProvider = Provider<ExcelExportService>((ref) {
  final dio = ref.watch(dioProvider);
  final networkInfo = ref.watch(networkInfoProvider);
  return ExcelExportService(dio: dio, networkInfo: networkInfo);
});

final isExportingExcelProvider = StateProvider<bool>((ref) => false);

final reportSelectedPresetProvider = StateProvider<ReportPeriodPreset>((ref) => ReportPeriodPreset.today);
final reportCustomDateFromProvider = StateProvider<String?>((ref) => null);
final reportCustomDateToProvider = StateProvider<String?>((ref) => null);

/// Proveedor computado que entrega el rango exacto {from, to} según el preset o fechas personalizadas
final reportDateRangeProvider = Provider<({String from, String to})>((ref) {
  final preset = ref.watch(reportSelectedPresetProvider);
  final customFrom = ref.watch(reportCustomDateFromProvider);
  final customTo = ref.watch(reportCustomDateToProvider);

  switch (preset) {
    case ReportPeriodPreset.today:
      final today = TimezoneUtils.getTodayBusinessDate();
      return (from: today, to: today);

    case ReportPeriodPreset.yesterday:
      final yesterday = TimezoneUtils.getYesterdayBusinessDate();
      return (from: yesterday, to: yesterday);

    case ReportPeriodPreset.thisWeek:
      return TimezoneUtils.getThisWeekBusinessDateRange();

    case ReportPeriodPreset.thisMonth:
      return TimezoneUtils.getThisMonthBusinessDateRange();

    case ReportPeriodPreset.custom:
      final today = TimezoneUtils.getTodayBusinessDate();
      final from = customFrom ?? today;
      final to = customTo ?? today;
      return (from: from, to: to);
  }
});
