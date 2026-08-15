import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:katering_grecia_app/core/utils/timezone_utils.dart';
import 'package:katering_grecia_app/features/reports/application/excel_export_notifier.dart';

void main() {
  group('Report Period Presets & Timezone Tests', () {
    test('Preset HOY returns today date in America/La_Paz format YYYY-MM-DD', () {
      final container = ProviderContainer();
      container.read(reportSelectedPresetProvider.notifier).state = ReportPeriodPreset.today;

      final range = container.read(reportDateRangeProvider);
      final today = TimezoneUtils.getTodayBusinessDate();

      expect(range.from, equals(today));
      expect(range.to, equals(today));
      expect(RegExp(r'^\d{4}-\d{2}-\d{2}$').hasMatch(range.from), isTrue);
      expect(RegExp(r'^\d{4}-\d{2}-\d{2}$').hasMatch(range.to), isTrue);
    });

    test('Preset AYER returns yesterday date in America/La_Paz format YYYY-MM-DD', () {
      final container = ProviderContainer();
      container.read(reportSelectedPresetProvider.notifier).state = ReportPeriodPreset.yesterday;

      final range = container.read(reportDateRangeProvider);
      final yesterday = TimezoneUtils.getYesterdayBusinessDate();

      expect(range.from, equals(yesterday));
      expect(range.to, equals(yesterday));
      expect(RegExp(r'^\d{4}-\d{2}-\d{2}$').hasMatch(range.from), isTrue);
    });

    test('Preset ESTA SEMANA returns valid weekly range in America/La_Paz', () {
      final container = ProviderContainer();
      container.read(reportSelectedPresetProvider.notifier).state = ReportPeriodPreset.thisWeek;

      final range = container.read(reportDateRangeProvider);
      expect(range.from.compareTo(range.to) <= 0, isTrue);

      final fromDate = DateTime.parse(range.from);
      expect(fromDate.weekday, equals(DateTime.monday));
    });

    test('Preset ESTE MES returns first day to last day of current month', () {
      final container = ProviderContainer();
      container.read(reportSelectedPresetProvider.notifier).state = ReportPeriodPreset.thisMonth;

      final range = container.read(reportDateRangeProvider);
      expect(range.from.compareTo(range.to) <= 0, isTrue);

      expect(range.from.endsWith('-01'), isTrue);
    });

    test('Preset PERSONALIZADO returns selected custom dates', () {
      final container = ProviderContainer();
      container.read(reportSelectedPresetProvider.notifier).state = ReportPeriodPreset.custom;
      container.read(reportCustomDateFromProvider.notifier).state = '2026-08-01';
      container.read(reportCustomDateToProvider.notifier).state = '2026-08-15';

      final range = container.read(reportDateRangeProvider);
      expect(range.from, equals('2026-08-01'));
      expect(range.to, equals('2026-08-15'));
    });

    test('FormatDisplayDate converts YYYY-MM-DD to DD/MM/YYYY', () {
      expect(TimezoneUtils.formatDisplayDate('2026-08-14'), equals('14/08/2026'));
      expect(TimezoneUtils.formatDisplayDate('2026-01-05'), equals('05/01/2026'));
    });
  });
}
