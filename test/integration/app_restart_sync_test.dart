import 'dart:io';
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:katering_grecia_app/core/database/app_database.dart';
import 'package:katering_grecia_app/core/sync/sync_queue_manager.dart';
import 'package:path/path.dart' as p;

void main() {
  late File dbFile;

  setUp(() {
    final tempDir = Directory.systemTemp.createTempSync('katering_test_');
    dbFile = File(p.join(tempDir.path, 'test_db.sqlite'));
  });

  tearDown(() {
    if (dbFile.existsSync()) {
      dbFile.deleteSync();
    }
  });

  group('App Restart & Persistence Sync Tests', () {
    test('Offline created order persists in SyncQueue across DB restart', () async {
      // 1. Instanciar BD en archivo temporal (Simula Ejecución 1 de la App)
      var db1 = AppDatabase(NativeDatabase(dbFile));
      var queueManager1 = SyncQueueManager(db1);

      const orderId = 'test-order-uuid-1234';
      final now = DateTime.now().toUtc();

      // Insertar pedido localmente
      await db1.into(db1.ordersTable).insert(
            OrdersTableCompanion.insert(
              id: orderId,
              customerName: 'Juan Pérez',
              total: 50.0,
              paymentMethod: 'CASH',
              status: 'PENDING',
              orderedAt: now,
              createdBy: 'user-1',
              createdAt: now,
              updatedAt: now,
            ),
          );

      // Encolar operación PENDING
      await queueManager1.enqueueOperation(
        entityType: 'order',
        entityId: orderId,
        operation: 'CREATE',
        payload: {
          'id': orderId,
          'customer_name': 'Juan Pérez',
          'payment_method': 'CASH',
        },
      );

      // Verificar que existe en la cola antes de cerrar
      final pendingBefore = await queueManager1.getPendingOperations();
      expect(pendingBefore.length, equals(1));
      expect(pendingBefore.first.entityId, equals(orderId));

      // 2. Simular Cierre Completo del Proceso de la App (Cerrar DB 1)
      await db1.close();

      // 3. Simular Reinicio de App (Reabrir conexión sobre el mismo archivo SQLite)
      var db2 = AppDatabase(NativeDatabase(dbFile));
      var queueManager2 = SyncQueueManager(db2);

      // Verificar que los datos y la cola de sync persisten intactos tras el reinicio
      final pendingAfter = await queueManager2.getPendingOperations();
      expect(pendingAfter.length, equals(1));
      expect(pendingAfter.first.entityId, equals(orderId));
      expect(pendingAfter.first.status, equals('PENDING'));

      await db2.close();
    });
  });
}
