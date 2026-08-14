import 'package:dio/dio.dart';

class NetworkErrorParser {
  static const String serverUnavailableMessage =
      'El servidor está iniciando o la conexión es inestable. Por favor, espera unos segundos e intenta de nuevo.';

  /// Convierte cualquier error de red o excepción técnica en un mensaje amigable en español
  static String parse(Object error, {String fallback = 'Ha ocurrido un error de conexión.'}) {
    if (error is DioException) {
      // 1. Timeouts & Errores de conexión (Cold starts de Render / Dispositivo offline)
      if (error.type == DioExceptionType.connectionTimeout ||
          error.type == DioExceptionType.receiveTimeout ||
          error.type == DioExceptionType.sendTimeout ||
          error.type == DioExceptionType.connectionError) {
        return serverUnavailableMessage;
      }

      final statusCode = error.response?.statusCode;

      // 2. Errores 5xx del Servidor (500, 502 Bad Gateway, 503 Service Unavailable, 504 Gateway Timeout)
      if (statusCode != null && statusCode >= 500) {
        return serverUnavailableMessage;
      }

      // 3. Respuesta estructurada JSON desde backend de NestJS
      final data = error.response?.data;
      if (data is Map) {
        final errorMap = data['error'];
        if (errorMap is Map && errorMap['message'] != null) {
          return errorMap['message'].toString();
        }
        if (data['message'] != null) {
          if (data['message'] is List) {
            return (data['message'] as List).join(', ');
          }
          return data['message'].toString();
        }
      }

      // 4. Si la respuesta contiene HTML crudo (ej. página 502 de Nginx o Render)
      if (data is String && (data.contains('<!DOCTYPE html') || data.contains('<html'))) {
        return serverUnavailableMessage;
      }

      // 5. Códigos de error estándar HTTP
      if (statusCode != null) {
        if (statusCode == 401) return 'Credenciales incorrectas o sesión expirada.';
        if (statusCode == 403) return 'No tienes permisos para realizar esta acción.';
        if (statusCode == 404) return 'Recurso no encontrado en el servidor.';
        if (statusCode == 409) return 'Conflicto de versión o registro duplicado en el servidor.';
        if (statusCode == 400) return 'Datos de solicitud inválidos.';
      }

      if (error.message != null && error.message!.isNotEmpty && !error.message!.contains('<html')) {
        return error.message!;
      }
    }

    final str = error.toString();
    if (str.contains('SocketException') ||
        str.contains('TimeoutException') ||
        str.contains('HandshakeException') ||
        str.contains('HttpException')) {
      return serverUnavailableMessage;
    }

    return fallback;
  }
}
