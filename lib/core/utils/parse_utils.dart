class ParseUtils {
  /// Convierte con seguridad cualquier valor (num, String, int, double o null) a double
  static double toDouble(dynamic value, [double defaultValue = 0.0]) {
    if (value == null) return defaultValue;
    if (value is num) return value.toDouble();
    if (value is String) {
      final clean = value.trim();
      if (clean.isEmpty) return defaultValue;
      return double.tryParse(clean) ?? defaultValue;
    }
    return defaultValue;
  }

  /// Convierte con seguridad cualquier valor (num, String, int, double o null) a int
  static int toInt(dynamic value, [int defaultValue = 0]) {
    if (value == null) return defaultValue;
    if (value is num) return value.toInt();
    if (value is String) {
      final clean = value.trim();
      if (clean.isEmpty) return defaultValue;
      final parsedInt = int.tryParse(clean);
      if (parsedInt != null) return parsedInt;
      final parsedDouble = double.tryParse(clean);
      if (parsedDouble != null) return parsedDouble.toInt();
      return defaultValue;
    }
    return defaultValue;
  }
}
