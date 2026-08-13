import 'package:intl/intl.dart';

class TimezoneUtils {
  /// Retorna la fecha actual de negocio en formato YYYY-MM-DD para America/La_Paz (UTC-4).
  static String getTodayBusinessDate() {
    final nowUtc = DateTime.now().toUtc();
    // America/La_Paz es UTC-4 constante (sin DST)
    final laPazTime = nowUtc.subtract(const Duration(hours: 4));
    return DateFormat('yyyy-MM-dd').format(laPazTime);
  }

  /// Convierte un DateTime UTC a String de fecha de negocio YYYY-MM-DD (UTC-4)
  static String toBusinessDateString(DateTime dateTime) {
    final laPazTime = dateTime.toUtc().subtract(const Duration(hours: 4));
    return DateFormat('yyyy-MM-dd').format(laPazTime);
  }

  /// Formato ISO 8601 UTC para timestamps del servidor
  static String toUtcIsoString(DateTime dateTime) {
    return dateTime.toUtc().toIso8601String();
  }
}
