import 'package:flutter_test/flutter_test.dart';
import 'package:katering_grecia_app/core/utils/currency_formatter.dart';
import 'package:katering_grecia_app/core/utils/timezone_utils.dart';

void main() {
  group('Utils Unit Tests', () {
    test('CurrencyFormatter formats BOB currency correctly', () {
      final formatted = CurrencyFormatter.formatBOB(125.50);
      expect(formatted, contains('125'));
      expect(formatted, contains('50'));
    });

    test('TimezoneUtils extracts business date in YYYY-MM-DD format', () {
      final todayDate = TimezoneUtils.getTodayBusinessDate();
      final regex = RegExp(r'^\d{4}-\d{2}-\d{2}$');
      expect(regex.hasMatch(todayDate), isTrue);
    });
  });
}
