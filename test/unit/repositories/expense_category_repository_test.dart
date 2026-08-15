import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

import 'package:katering_grecia_app/core/database/app_database.dart';
import 'package:katering_grecia_app/core/sync/sync_engine.dart';
import 'package:katering_grecia_app/core/sync/sync_queue_manager.dart';
import 'package:katering_grecia_app/features/expenses/data/expenses_repository.dart';

class MockSyncEngine extends Mock implements SyncEngine {}

void main() {
  late AppDatabase db;
  late SyncQueueManager queueManager;
  late MockSyncEngine mockSyncEngine;
  late ExpensesRepository repository;

  setUp(() async {
    db = AppDatabase(NativeDatabase.memory());
    queueManager = SyncQueueManager(db);
    mockSyncEngine = MockSyncEngine();

    repository = ExpensesRepository(
      db: db,
      queueManager: queueManager,
      syncEngine: mockSyncEngine,
    );

    when(() => mockSyncEngine.syncAll()).thenAnswer((_) async => SyncResult(
          pushedCount: 0,
          pulledCount: 0,
          conflictCount: 0,
          errorCount: 0,
        ));
  });

  tearDown(() async {
    await db.close();
  });

  group('Expense Category Repository Unit Tests', () {
    test('Create, Read, Update and Deactivate Category offline', () async {
      // 1. Crear categoría
      final cat = await repository.createCategory(name: 'Transporte y Logística');
      expect(cat.name, equals('Transporte y Logística'));
      expect(cat.active, isTrue);
      expect(cat.version, equals(1));

      // 2. Verificar que se encoló la operación
      final pendingOps = await queueManager.getPendingOperations();
      expect(pendingOps.length, equals(1));
      expect(pendingOps.first.entityType, equals('expense_category'));
      expect(pendingOps.first.operation, equals('CREATE'));

      // 3. Listar categorías activas
      final activeList = await repository.watchCategories().first;
      expect(activeList.length, equals(1));
      expect(activeList.first.name, equals('Transporte y Logística'));

      // 4. Actualizar categoría
      final updatedCat = await repository.updateCategory(id: cat.id, name: 'Fletes y Transporte');
      expect(updatedCat.name, equals('Fletes y Transporte'));
      expect(updatedCat.version, equals(2));

      // 5. Desactivar categoría (Soft delete)
      await repository.deleteCategory(cat.id);

      final activeAfterDelete = await repository.watchCategories().first;
      expect(activeAfterDelete.isEmpty, isTrue);

      final allCategories = await repository.watchAllCategories().first;
      expect(allCategories.length, equals(1));
      expect(allCategories.first.active, isFalse);
    });

    test('Validates category name length and emptiness', () async {
      expect(
        () => repository.createCategory(name: ''),
        throwsArgumentError,
      );

      expect(
        () => repository.createCategory(name: 'A' * 101),
        throwsArgumentError,
      );
    });
  });
}
