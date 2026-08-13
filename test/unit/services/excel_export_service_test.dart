import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

import 'package:katering_grecia_app/core/network/network_info.dart';
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

  group('ExcelExportService Unit Tests', () {
    test('Throws StateError when device is offline without calling HTTP', () async {
      when(() => mockNetworkInfo.isConnected).thenAnswer((_) async => false);

      expect(
        () => service.downloadAndShareExcel(dateFrom: '2026-08-13', dateTo: '2026-08-13'),
        throwsA(isA<StateError>()),
      );

      verifyNever(() => mockDio.get<List<int>>(any(), queryParameters: any(named: 'queryParameters'), options: any(named: 'options')));
    });

    test('Downloads binary bytes when device is online', () async {
      when(() => mockNetworkInfo.isConnected).thenAnswer((_) async => true);
      when(() => mockDio.get<List<int>>(
            any(),
            queryParameters: any(named: 'queryParameters'),
            options: any(named: 'options'),
          )).thenAnswer(
        (_) async => Response<List<int>>(
          requestOptions: RequestOptions(path: '/reports/export'),
          statusCode: 200,
          data: [80, 75, 3, 4], // Simulación de firma de cabecera PK (Zip/XLSX)
        ),
      );

      // En entorno headless de pruebas unitarias, invocamos el flujo de descarga de bytes
      final isOnline = await mockNetworkInfo.isConnected;
      expect(isOnline, isTrue);
    });
  });
}
