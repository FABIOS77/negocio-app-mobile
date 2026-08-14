import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:katering_grecia_app/core/utils/network_error_parser.dart';

void main() {
  group('NetworkErrorParser Tests', () {
    test('Converts connection timeout to friendly cold-start message', () {
      final dioException = DioException(
        requestOptions: RequestOptions(path: '/test'),
        type: DioExceptionType.connectionTimeout,
      );

      final msg = NetworkErrorParser.parse(dioException);
      expect(msg, equals(NetworkErrorParser.serverUnavailableMessage));
    });

    test('Converts 502 Bad Gateway to friendly cold-start message', () {
      final dioException = DioException(
        requestOptions: RequestOptions(path: '/test'),
        response: Response(
          requestOptions: RequestOptions(path: '/test'),
          statusCode: 502,
          data: '<html><body>502 Bad Gateway</body></html>',
        ),
      );

      final msg = NetworkErrorParser.parse(dioException);
      expect(msg, equals(NetworkErrorParser.serverUnavailableMessage));
    });

    test('Converts 500 Internal Server Error to friendly message', () {
      final dioException = DioException(
        requestOptions: RequestOptions(path: '/test'),
        response: Response(
          requestOptions: RequestOptions(path: '/test'),
          statusCode: 500,
          data: 'Internal Error',
        ),
      );

      final msg = NetworkErrorParser.parse(dioException);
      expect(msg, equals(NetworkErrorParser.serverUnavailableMessage));
    });

    test('Extracts custom backend JSON message on 400', () {
      final dioException = DioException(
        requestOptions: RequestOptions(path: '/test'),
        response: Response(
          requestOptions: RequestOptions(path: '/test'),
          statusCode: 400,
          data: {
            'error': {'message': 'El correo ya está en uso.'}
          },
        ),
      );

      final msg = NetworkErrorParser.parse(dioException);
      expect(msg, equals('El correo ya está en uso.'));
    });

    test('Extracts 401 Unauthorized friendly message', () {
      final dioException = DioException(
        requestOptions: RequestOptions(path: '/test'),
        response: Response(
          requestOptions: RequestOptions(path: '/test'),
          statusCode: 401,
        ),
      );

      final msg = NetworkErrorParser.parse(dioException);
      expect(msg, equals('Credenciales incorrectas o sesión expirada.'));
    });
  });
}
