import 'package:intl/intl.dart';

class TimezoneUtils {
  /// Retorna la fecha DateTime en America/La_Paz (UTC-4 constante sin DST)
  static DateTime getNowLaPaz() {
    final nowUtc = DateTime.now().toUtc();
    return nowUtc.subtract(const Duration(hours: 4));
  }

  /// Retorna la fecha actual de negocio en formato YYYY-MM-DD para America/La_Paz (UTC-4).
  static String getTodayBusinessDate() {
    return DateFormat('yyyy-MM-dd').format(getNowLaPaz());
  }

  /// Retorna la fecha de ayer en formato YYYY-MM-DD para America/La_Paz (UTC-4).
  static String getYesterdayBusinessDate() {
    final yesterday = getNowLaPaz().subtract(const Duration(days: 1));
    return DateFormat('yyyy-MM-dd').format(yesterday);
  }

  /// Retorna el rango de fechas de esta semana (Lunes a Domingo o Hoy) en formato YYYY-MM-DD
  static ({String from, String to}) getThisWeekBusinessDateRange() {
    final nowLaPaz = getNowLaPaz();
    final startOfWeek = nowLaPaz.subtract(Duration(days: nowLaPaz.weekday - 1));
    final endOfWeek = startOfWeek.add(const Duration(days: 6));
    return (
      from: DateFormat('yyyy-MM-dd').format(startOfWeek),
      to: DateFormat('yyyy-MM-dd').format(endOfWeek),
    );
  }

  /// Retorna el rango de fechas de este mes (1er día al último día) en formato YYYY-MM-DD
  static ({String from, String to}) getThisMonthBusinessDateRange() {
    final nowLaPaz = getNowLaPaz();
    final startOfMonth = DateTime.utc(nowLaPaz.year, nowLaPaz.month, 1);
    final endOfMonth = DateTime.utc(nowLaPaz.year, nowLaPaz.month + 1, 0);
    return (
      from: DateFormat('yyyy-MM-dd').format(startOfMonth),
      to: DateFormat('yyyy-MM-dd').format(endOfMonth),
    );
  }

  /// Convierte un DateTime UTC a String de fecha de negocio YYYY-MM-DD (UTC-4)
  static String toBusinessDateString(DateTime dateTime) {
    final laPazTime = dateTime.toUtc().subtract(const Duration(hours: 4));
    return DateFormat('yyyy-MM-dd').format(laPazTime);
  }

  /// Convierte una fecha YYYY-MM-DD al formato legible DD/MM/YYYY
  static String formatDisplayDate(String yyyyMmDd) {
    final parts = yyyyMmDd.split('-');
    if (parts.length == 3) {
      return '${parts[2]}/${parts[1]}/${parts[0]}';
    }
    return yyyyMmDd;
  }

  /// Formato ISO 8601 UTC para timestamps del servidor
  static String toUtcIsoString(DateTime dateTime) {
    return dateTime.toUtc().toIso8601String();
  }
}
