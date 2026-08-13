import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/sync/sync_engine.dart';
import '../data/daily_menu_repository.dart';
import '../domain/daily_menu_model.dart';

final dailyMenuRepositoryProvider = Provider<DailyMenuRepository>((ref) {
  final db = ref.watch(databaseProvider);
  final queueManager = ref.watch(syncQueueManagerProvider);
  final syncEngine = ref.watch(syncEngineProvider);
  return DailyMenuRepository(db: db, queueManager: queueManager, syncEngine: syncEngine);
});

final todayMenuStreamProvider = StreamProvider<DailyMenuModel?>((ref) {
  final repository = ref.watch(dailyMenuRepositoryProvider);
  return repository.watchTodayMenu();
});
