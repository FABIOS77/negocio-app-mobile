import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/sync/sync_engine.dart';

import '../data/sync_diagnostics_repository.dart';

final syncDiagnosticsRepositoryProvider = Provider<SyncDiagnosticsRepository>((ref) {
  final db = ref.watch(databaseProvider);
  return SyncDiagnosticsRepository(db: db);
});

final syncDiagnosticsStreamProvider = StreamProvider<SyncDiagnosticsSummary>((ref) {
  final repo = ref.watch(syncDiagnosticsRepositoryProvider);
  return repo.watchDiagnosticsSummary();
});
