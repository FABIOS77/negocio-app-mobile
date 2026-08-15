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

    // Precargar categoría de prueba activa
    await db.into(db.expenseCategoriesTable).insert(
          ExpenseCategoriesTableCompanion.insert(
            id: '550e8400-e29b-41d4-a716-446655440400',
            name: 'Insumos / Verduras y Carnes',
            createdAt: DateTime.now().toUtc(),
            updatedAt: DateTime.now().toUtc(),
          ),
        );
  });

  tearDown(() async {
    await db.close();
  });

  group('ExpensesRepository Unit Tests', () {
    test('Create, Read, Update, Filter and Soft Delete Expense offline', () async {
      // 1. Crear Gasto
      final exp = await repository.createExpense(
        description: 'Verduras del Mercado',
        amount: 150.75,
        categoryId: '550e8400-e29b-41d4-a716-446655440400',
        paymentMethod: 'CASH',
        expenseDate: '2026-08-14',
      );

      expect(exp.description, equals('Verduras del Mercado'));
      expect(exp.amount, equals(150.75));
      expect(exp.categoryId, equals('550e8400-e29b-41d4-a716-446655440400'));
      expect(exp.categoryName, equals('Insumos / Verduras y Carnes'));
      expect(exp.expenseDate, equals('2026-08-14'));

      // 2. Leer gasto por ID
      final fetched = await repository.getExpenseById(exp.id);
      expect(fetched, isNotNull);
      expect(fetched!.amount, equals(150.75));

      // 3. Actualizar Gasto
      final updated = await repository.updateExpense(
        id: exp.id,
        description: 'Verduras y Frutas del Mercado',
        amount: 175.50,
      );
      expect(updated.description, equals('Verduras y Frutas del Mercado'));
      expect(updated.amount, equals(175.50));
      expect(updated.version, equals(2));

      // 4. Filtrar por categoría
      final list = await repository.watchExpenses(categoryId: '550e8400-e29b-41d4-a716-446655440400').first;
      expect(list.length, equals(1));
      expect(list.first.categoryName, equals('Insumos / Verduras y Carnes'));

      // 5. Métricas de totales y conteo
      final total = await repository.getTotalExpenses(date: '2026-08-14');
      final count = await repository.getExpenseCount(date: '2026-08-14');
      expect(total, equals(175.50));
      expect(count, equals(1));

      // 6. Soft Delete (deletedAt != null)
      await repository.deleteExpense(exp.id);

      final activeList = await repository.watchExpenses().first;
      expect(activeList.isEmpty, isTrue);

      final totalAfterDelete = await repository.getTotalExpenses(date: '2026-08-14');
      expect(totalAfterDelete, equals(0.0));
    });

    test('Validates expense input rules and inactive category rejection', () async {
      // a) Monto <= 0
      expect(
        () => repository.createExpense(
          description: 'Carne',
          amount: 0.0,
          categoryId: '550e8400-e29b-41d4-a716-446655440400',
          paymentMethod: 'CASH',
        ),
        throwsArgumentError,
      );

      // b) Descripción vacía
      expect(
        () => repository.createExpense(
          description: '   ',
          amount: 50.0,
          categoryId: '550e8400-e29b-41d4-a716-446655440400',
          paymentMethod: 'CASH',
        ),
        throwsArgumentError,
      );

      // c) Categoría inexistente
      expect(
        () => repository.createExpense(
          description: 'Aceite',
          amount: 50.0,
          categoryId: 'cat-inexistente',
          paymentMethod: 'CASH',
        ),
        throwsStateError,
      );

      // d) Método de pago inválido
      expect(
        () => repository.createExpense(
          description: 'Gas',
          amount: 50.0,
          categoryId: '550e8400-e29b-41d4-a716-446655440400',
          paymentMethod: 'CREDIT_CARD',
        ),
        throwsArgumentError,
      );
    });
  });
}
