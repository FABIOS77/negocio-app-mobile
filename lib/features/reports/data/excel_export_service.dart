import 'dart:io';
import 'package:dio/dio.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
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

  /// Obtiene los bytes binarios del Excel generado por el backend validando parámetros y conectividad
  Future<List<int>> fetchExcelBytes({
    required String dateFrom,
    required String dateTo,
  }) async {
    // 1. Validar formato estricto YYYY-MM-DD
    final dateRegex = RegExp(r'^\d{4}-\d{2}-\d{2}$');
    if (!dateRegex.hasMatch(dateFrom) || !dateRegex.hasMatch(dateTo)) {
      throw ArgumentError('Las fechas deben tener el formato estricto YYYY-MM-DD.');
    }

    // 2. Validar que date_from <= date_to
    if (dateFrom.compareTo(dateTo) > 0) {
      throw ArgumentError('La fecha inicial no puede ser posterior a la fecha final.');
    }

    // 3. Verificar conectividad a Internet obligatoria
    final isConnected = await _networkInfo.isConnected;
    if (!isConnected) {
      throw StateError('Necesitas conexión a Internet para generar y descargar el reporte en Excel.');
    }

    // 4. Petición GET al backend con ResponseType.bytes para recibir el Buffer binario .xlsx
    final response = await _dio.get<List<int>>(
      '/reports/export',
      queryParameters: {
        'date_from': dateFrom,
        'date_to': dateTo,
      },
      options: Options(
        responseType: ResponseType.bytes,
      ),
    );

    if (response.statusCode != 200 || response.data == null) {
      throw StateError('El servidor no pudo generar el archivo Excel.');
    }

    return response.data!;
  }

  /// Descarga el reporte Excel (.xlsx) generado por el backend y lo comparte mediante la hoja nativa del sistema
  Future<File> downloadAndShareExcel({
    String? dateFrom,
    String? dateTo,
  }) async {
    final fromStr = dateFrom ?? TimezoneUtils.getTodayBusinessDate();
    final toStr = dateTo ?? TimezoneUtils.getTodayBusinessDate();

    final bytes = await fetchExcelBytes(dateFrom: fromStr, dateTo: toStr);

    // Guardar el archivo temporalmente en el dispositivo
    final tempDir = await getTemporaryDirectory();
    final fileName = 'Reporte_Katering_Grecia_${fromStr}_$toStr.xlsx';
    final filePath = p.join(tempDir.path, fileName);
    final file = File(filePath);

    await file.writeAsBytes(bytes);

    // Compartir mediante la hoja nativa del SO (share_plus)
    await Share.shareXFiles(
      [XFile(file.path)],
      text: 'Reporte Financiero Katering Grecia ($fromStr a $toStr)',
    );

    return file;
  }
}
