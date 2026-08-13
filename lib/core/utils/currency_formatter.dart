import 'package:intl/intl.dart';

class CurrencyFormatter {
  static final _bobFormat = NumberFormat.currency(
    symbol: 'Bs ',
    decimalDigits: 2,
    locale: 'es_BO',
  );

  /// Formatea un valor numérico a moneda Bolivianos (ej. Bs 25.50)
  static String formatBOB(num amount) {
    return _bobFormat.format(amount);
  }
}
