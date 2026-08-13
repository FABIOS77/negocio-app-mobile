import 'dart:io';
import 'package:dio/dio.dart';
import 'package:path_provider/path_provider.dart';
import 'package:path/path.dart' as p;
import 'package:share_plus/share_plus.dart';

import '../../../core/network/network_info.dart';
import '../../../core/utils/timezone_utils.dart';

class ExcelExportService {
  final Dio _dio;
  final NetworkInfo _networkInfo;

  ExcelExportService({
    required Dio dio,
    required NetworkInfo networkInfo,
  })  : _dio = dio,
        _networkInfo = networkInfo;

  /// Descarga el reporte Excel (.xlsx) generado por el backend y lo comparte mediante la hoja nativa del sistema
  Future<File> downloadAndShareExcel({
    String? dateFrom,
    String? dateTo,
  }) async {
    // 1. Verificar conectividad a Internet obligatoria
    final isConnected = await _networkInfo.isConnected;
    if (!isConnected) {
      throw StateError('Necesitas conexión a Internet para generar y descargar el reporte en Excel.');
    }

    final fromStr = dateFrom ?? TimezoneUtils.getTodayBusinessDate();
    final toStr = dateTo ?? TimezoneUtils.getTodayBusinessDate();

    // 2. Petición GET al backend con ResponseType.bytes para recibir el Buffer binario .xlsx
    final response = await _dio.get<List<int>>(
      '/reports/export',
      queryParameters: {
        'date_from': fromStr,
        'date_to': toStr,
      },
      options: Options(
        responseType: ResponseType.bytes,
      ),
    );

    if (response.statusCode != 200 || response.data == null) {
      throw StateError('El servidor no pudo generar el archivo Excel.');
    }

    // 3. Guardar el archivo temporalmente en el dispositivo con path_provider
    final tempDir = await getTemporaryDirectory();
    final fileName = 'Reporte_Katering_Grecia_$fromStr.xlsx';
    final filePath = p.join(tempDir.path, fileName);
    final file = File(filePath);

    await file.writeAsBytes(response.data!);

    // 4. Compartir mediante la hoja nativa del SO (share_plus)
    await Share.shareXFiles(
      [XFile(file.path)],
      text: 'Reporte Financiero Katering Grecia ($fromStr - $toStr)',
    );

    return file;
  }
}
