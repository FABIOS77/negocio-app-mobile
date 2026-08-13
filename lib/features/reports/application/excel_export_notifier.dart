import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/network/dio_client.dart';
import '../../../core/network/network_info.dart';
import '../data/excel_export_service.dart';

final networkInfoProvider = Provider<NetworkInfo>((ref) {
  return NetworkInfo();
});

final excelExportServiceProvider = Provider<ExcelExportService>((ref) {
  final dio = ref.watch(dioProvider);
  final networkInfo = ref.watch(networkInfoProvider);
  return ExcelExportService(dio: dio, networkInfo: networkInfo);
});

final isExportingExcelProvider = StateProvider<bool>((ref) => false);
