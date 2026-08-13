import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/sync/sync_engine.dart';
import '../data/production_repository.dart';
import '../domain/production_item_model.dart';

final productionRepositoryProvider = Provider<ProductionRepository>((ref) {
  final db = ref.watch(databaseProvider);
  return ProductionRepository(db: db);
});

final todayProductionStreamProvider = StreamProvider<List<ProductionItemModel>>((ref) {
  final repository = ref.watch(productionRepositoryProvider);
  return repository.watchProductionSummary();
});
