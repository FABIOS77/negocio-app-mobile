import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

import 'package:katering_grecia_app/core/network/network_info.dart';
import 'package:katering_grecia_app/core/utils/network_error_parser.dart';
import 'package:katering_grecia_app/features/reports/data/excel_export_service.dart';

class MockDio extends Mock implements Dio {}
class MockNetworkInfo extends Mock implements NetworkInfo {}

void main() {
  late MockDio mockDio;
  late MockNetworkInfo mockNetworkInfo;
  late ExcelExportService service;

  setUp(() {
    mockDio = MockDio();
    mockNetworkInfo = MockNetworkInfo();
    service = ExcelExportService(dio: mockDio, networkInfo: mockNetworkInfo);
  });

  group('ExcelExportService Unit & Validation Tests', () {
    test('Throws ArgumentError when date_from is posterior to date_to', () async {
      when(() => mockNetworkInfo.isConnected).thenAnswer((_) async => true);

      expect(
        () => service.fetchExcelBytes(dateFrom: '2026-08-20', dateTo: '2026-08-10'),
        throwsA(isA<ArgumentError>()),
      );

      verifyNever(() => mockDio.get<List<int>>(any(), queryParameters: any(named: 'queryParameters'), options: any(named: 'options')));
    });

    test('Throws ArgumentError when date format is not YYYY-MM-DD', () async {
      when(() => mockNetworkInfo.isConnected).thenAnswer((_) async => true);

      expect(
        () => service.fetchExcelBytes(dateFrom: '14/08/2026', dateTo: '14/08/2026'),
        throwsA(isA<ArgumentError>()),
      );
    });

    test('Throws StateError when device is offline without making HTTP request', () async {
      when(() => mockNetworkInfo.isConnected).thenAnswer((_) async => false);

      expect(
        () => service.fetchExcelBytes(dateFrom: '2026-08-13', dateTo: '2026-08-13'),
        throwsA(isA<StateError>()),
      );

      verifyNever(() => mockDio.get<List<int>>(any(), queryParameters: any(named: 'queryParameters'), options: any(named: 'options')));
    });

    test('Request parameters strictly use snake_case date_from and date_to', () async {
      when(() => mockNetworkInfo.isConnected).thenAnswer((_) async => true);

      Map<String, dynamic>? capturedParams;
      when(() => mockDio.get<List<int>>(
            '/reports/export',
            queryParameters: any(named: 'queryParameters'),
            options: any(named: 'options'),
          )).thenAnswer((invocation) async {
        capturedParams = invocation.namedArguments[#queryParameters] as Map<String, dynamic>;
        return Response<List<int>>(
          requestOptions: RequestOptions(path: '/reports/export'),
          statusCode: 200,
          data: [80, 75, 3, 4], // PK header signature
        );
      });

      final bytes = await service.fetchExcelBytes(dateFrom: '2026-08-10', dateTo: '2026-08-14');

      expect(bytes, equals([80, 75, 3, 4]));
      expect(capturedParams, isNotNull);
      expect(capturedParams!['date_from'], equals('2026-08-10'));
      expect(capturedParams!['date_to'], equals('2026-08-14'));
      expect(capturedParams!.containsKey('dateFrom'), isFalse);
      expect(capturedParams!.containsKey('dateTo'), isFalse);
    });

    test('NetworkErrorParser parses 400, 401 and 5xx errors gracefully', () {
      final error400 = DioException(
        requestOptions: RequestOptions(path: '/reports/export'),
        response: Response(
          requestOptions: RequestOptions(path: '/reports/export'),
          statusCode: 400,
          data: {'error': {'message': 'Rango de fechas inválido'}},
        ),
      );
      expect(NetworkErrorParser.parse(error400), equals('Rango de fechas inválido'));

      final error401 = DioException(
        requestOptions: RequestOptions(path: '/reports/export'),
        response: Response(
          requestOptions: RequestOptions(path: '/reports/export'),
          statusCode: 401,
        ),
      );
      expect(NetworkErrorParser.parse(error401), contains('sesión expirada'));

      final error502 = DioException(
        requestOptions: RequestOptions(path: '/reports/export'),
        response: Response(
          requestOptions: RequestOptions(path: '/reports/export'),
          statusCode: 502,
        ),
      );
      expect(NetworkErrorParser.parse(error502), equals(NetworkErrorParser.serverUnavailableMessage));
    });
  });
}
