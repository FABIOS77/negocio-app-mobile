import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:katering_grecia_app/core/database/app_database.dart';
import 'package:katering_grecia_app/core/sync/sync_engine.dart';
import 'package:katering_grecia_app/core/sync/sync_queue_manager.dart';
import 'package:katering_grecia_app/features/daily_menu/data/daily_menu_repository.dart';

class _FakeSyncEngine implements SyncEngine {
  @override
  Future<SyncResult> syncAll() async => SyncResult(pushedCount: 0, pulledCount: 0, conflictCount: 0, errorCount: 0);
  @override
  noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

void main() {
  late AppDatabase db;
  late SyncQueueManager queueManager;
  late _FakeSyncEngine syncEngine;
  late DailyMenuRepository repo;

  setUp(() {
    db = AppDatabase(NativeDatabase.memory());
    queueManager = SyncQueueManager(db);
    syncEngine = _FakeSyncEngine();
    repo = DailyMenuRepository(db: db, queueManager: queueManager, syncEngine: syncEngine);
  });

  tearDown(() async {
    await db.close();
  });

  test('watchMenuByDate does not throw StateError when duplicate menus exist for the same date', () async {
    final now = DateTime.now().toUtc();
    const todayStr = '2026-08-13';

    // Insertar 2 menús con la misma fecha para simular duplicado
    await db.into(db.dailyMenusTable).insert(
          DailyMenusTableCompanion.insert(
            id: 'menu-dup-1',
            menuDate: todayStr,
            createdAt: now,
            updatedAt: now,
          ),
        );
    await db.into(db.dailyMenusTable).insert(
          DailyMenusTableCompanion.insert(
            id: 'menu-dup-2',
            menuDate: todayStr,
            createdAt: now.add(const Duration(seconds: 5)),
            updatedAt: now.add(const Duration(seconds: 5)),
          ),
        );

    // No debe lanzar StateError "expected exactly one element" y debe retornar el más reciente
    final menu = await repo.watchMenuByDate(todayStr).first;
    expect(menu, isNotNull);
    expect(menu!.id, equals('menu-dup-2'));
  });
}
