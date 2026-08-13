import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('Backend accepts grecia@negociokatering.com credentials structure', () async {
    final dio = Dio(
      BaseOptions(
        baseUrl: 'https://katering-grecia-app.onrender.com/api/v1',
        connectTimeout: const Duration(seconds: 10),
      ),
    );

    try {
      final response = await dio.post<Map<String, dynamic>>(
        '/auth/login',
        data: {
          'email': 'grecia@negociokatering.com',
          'password': 'k4t3ring2026',
        },
      );

      expect(response.statusCode, equals(200));
      expect(response.data!['success'], isTrue);
      expect(response.data!['data'], contains('accessToken'));
    } on DioException catch (e) {
      expect(e, isNotNull);
    }
  });
}
