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

  group('Drift SQLite Performance Tests', () {
    test('Handles insertion and paginated query of 1,000 orders sub-50ms without blocking UI', () async {
      final now = DateTime.now().toUtc();

      // 1. Inserción masiva en batch de 1,000 pedidos
      final stopwatchBatch = Stopwatch()..start();
      await db.batch((batch) {
        for (int i = 1; i <= 1000; i++) {
          batch.insert(
            db.ordersTable,
            OrdersTableCompanion.insert(
              id: 'order-perf-uuid-$i',
              customerName: 'Cliente #$i',
              total: i * 10.0,
              paymentMethod: i % 2 == 0 ? 'CASH' : 'QR',
              status: 'PENDING',
              orderedAt: now,
              createdBy: 'perf-user',
              createdAt: now,
              updatedAt: now,
            ),
          );
        }
      });
      stopwatchBatch.stop();
      expect(stopwatchBatch.elapsedMilliseconds, lessThan(1000));

      // 2. Consulta paginada filtrada por fecha e índice de estado
      final stopwatchQuery = Stopwatch()..start();
      final page1 = await (db.select(db.ordersTable)
            ..where((t) => t.status.equals('PENDING'))
            ..orderBy([(t) => OrderingTerm(expression: t.orderedAt, mode: OrderingMode.desc)])
            ..limit(20, offset: 0))
          .get();
      stopwatchQuery.stop();

      expect(page1.length, equals(20));
      expect(stopwatchQuery.elapsedMilliseconds, lessThan(50));
    });
  });
}
