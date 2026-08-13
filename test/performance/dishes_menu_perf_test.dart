import 'package:drift/drift.dart';
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:katering_grecia_app/core/database/app_database.dart';

void main() {
  late AppDatabase db;

  setUp(() {
    db = AppDatabase(NativeDatabase.memory());
  });

  tearDown(() async {
    await db.close();
  });

  group('Dishes & Daily Menu Performance Tests', () {
    test('Handles 1,000 dishes & 100 daily menus search and paginated queries sub-50ms', () async {
      final now = DateTime.now().toUtc();

      // 1. Inserción masiva de 1,000 platos
      await db.batch((batch) {
        for (int i = 1; i <= 1000; i++) {
          batch.insert(
            db.dishesTable,
            DishesTableCompanion.insert(
              id: 'dish-perf-uuid-$i',
              name: 'Plato Tradicional #$i',
              description: Value('Descripción deliciosa del plato #$i'),
              price: 15.0 + (i % 20),
              active: Value(i % 5 != 0), // 80% activos
              version: const Value(1),
              createdAt: now,
              updatedAt: now,
            ),
          );
        }
      });

      // 2. Inserción masiva de 100 menús diarios
      await db.batch((batch) {
        for (int i = 1; i <= 100; i++) {
          batch.insert(
            db.dailyMenusTable,
            DailyMenusTableCompanion.insert(
              id: 'menu-perf-uuid-$i',
              menuDate: '2026-08-${i < 10 ? '0$i' : '$i'}',
              active: const Value(true),
              version: const Value(1),
              createdAt: now,
              updatedAt: now,
            ),
          );
        }
      });

      // 3. Medir tiempo de búsqueda insensible a mayúsculas con 1,000 platos
      final stopwatchSearch = Stopwatch()..start();
      final searchResult = await (db.select(db.dishesTable)
            ..where((t) => t.active.equals(true) & t.name.lower().like('%50%'))
            ..limit(20, offset: 0))
          .get();
      stopwatchSearch.stop();

      expect(searchResult.isNotEmpty, isTrue);
      expect(stopwatchSearch.elapsedMilliseconds, lessThan(50));

      // 4. Medir tiempo de consulta paginada de catálogo
      final stopwatchPage = Stopwatch()..start();
      final page = await (db.select(db.dishesTable)
            ..where((t) => t.active.equals(true))
            ..orderBy([(t) => OrderingTerm(expression: t.name, mode: OrderingMode.asc)])
            ..limit(20, offset: 0))
          .get();
      stopwatchPage.stop();

      expect(page.length, equals(20));
      expect(stopwatchPage.elapsedMilliseconds, lessThan(50));
    });
  });
}
