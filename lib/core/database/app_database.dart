import 'dart:io';
import 'package:drift/drift.dart';
import 'package:drift/native.dart';
import 'package:path_provider/path_provider.dart';
import 'package:path/path.dart' as p;

part 'app_database.g.dart';

// ─── TABLAS DE NEGOCIO ────────────────────────────────────────────────────────

class UsersSessionTable extends Table {
  TextColumn get id => text()();
  TextColumn get name => text()();
  TextColumn get email => text()();
  BoolColumn get active => boolean().withDefault(const Constant(true))();
  IntColumn get version => integer().withDefault(const Constant(1))();
  DateTimeColumn get createdAt => dateTime()();

  @override
  Set<Column> get primaryKey => {id};
}

class DishesTable extends Table {
  TextColumn get id => text()();
  TextColumn get name => text()();
  TextColumn get description => text().nullable()();
  RealColumn get price => real()();
  TextColumn get imageUrl => text().nullable()();
  BoolColumn get active => boolean().withDefault(const Constant(true))();
  IntColumn get version => integer().withDefault(const Constant(1))();
  TextColumn get syncStatus => text().withDefault(const Constant('SYNCED'))();
  DateTimeColumn get deletedAt => dateTime().nullable()();
  DateTimeColumn get createdAt => dateTime()();
  DateTimeColumn get updatedAt => dateTime()();

  @override
  Set<Column> get primaryKey => {id};

  List<Index> get indexes => [
        Index('idx_dishes_active', 'CREATE INDEX idx_dishes_active ON dishes_table (active);'),
      ];
}

class DailyMenusTable extends Table {
  TextColumn get id => text()();
  TextColumn get menuDate => text()(); // YYYY-MM-DD (America/La_Paz)
  BoolColumn get active => boolean().withDefault(const Constant(true))();
  IntColumn get version => integer().withDefault(const Constant(1))();
  TextColumn get syncStatus => text().withDefault(const Constant('SYNCED'))();
  DateTimeColumn get createdAt => dateTime()();
  DateTimeColumn get updatedAt => dateTime()();

  @override
  Set<Column> get primaryKey => {id};

  List<Index> get indexes => [
        Index('idx_daily_menus_date', 'CREATE INDEX idx_daily_menus_date ON daily_menus_table (menu_date);'),
      ];
}

class DailyMenuDishesTable extends Table {
  TextColumn get id => text()();
  TextColumn get dailyMenuId => text()();
  TextColumn get dishId => text()();

  @override
  Set<Column> get primaryKey => {id};
}

class OrdersTable extends Table {
  TextColumn get id => text()();
  TextColumn get orderNumber => text().nullable()();
  TextColumn get customerName => text()();
  TextColumn get locationText => text().nullable()();
  RealColumn get total => real()();
  TextColumn get paymentMethod => text()(); // CASH, QR, OTHER
  TextColumn get status => text()(); // PENDING, DELIVERED, CANCELLED
  DateTimeColumn get orderedAt => dateTime()();
  TextColumn get createdBy => text()();
  IntColumn get version => integer().withDefault(const Constant(1))();
  TextColumn get syncStatus => text().withDefault(const Constant('PENDING'))(); // PENDING, PROCESSING, SYNCED, FAILED, CONFLICT
  DateTimeColumn get createdAt => dateTime()();
  DateTimeColumn get updatedAt => dateTime()();

  @override
  Set<Column> get primaryKey => {id};

  List<Index> get indexes => [
        Index('idx_orders_ordered_at_status', 'CREATE INDEX idx_orders_ordered_at_status ON orders_table (ordered_at, status);'),
        Index('idx_orders_sync_status', 'CREATE INDEX idx_orders_sync_status ON orders_table (sync_status);'),
      ];
}

class OrderItemsTable extends Table {
  TextColumn get id => text()();
  TextColumn get orderId => text()();
  TextColumn get dishId => text()();
  TextColumn get dishNameSnapshot => text()();
  IntColumn get quantity => integer()();
  RealColumn get unitPrice => real()();
  RealColumn get subtotal => real()();

  @override
  Set<Column> get primaryKey => {id};

  List<Index> get indexes => [
        Index('idx_order_items_order_id', 'CREATE INDEX idx_order_items_order_id ON order_items_table (order_id);'),
      ];
}

class ExpenseCategoriesTable extends Table {
  TextColumn get id => text()();
  TextColumn get name => text()();
  BoolColumn get active => boolean().withDefault(const Constant(true))();
  IntColumn get version => integer().withDefault(const Constant(1))();
  TextColumn get syncStatus => text().withDefault(const Constant('SYNCED'))();
  DateTimeColumn get createdAt => dateTime()();
  DateTimeColumn get updatedAt => dateTime()();

  @override
  Set<Column> get primaryKey => {id};
}

class ExpensesTable extends Table {
  TextColumn get id => text()();
  TextColumn get description => text()();
  RealColumn get amount => real()();
  TextColumn get categoryId => text()();
  TextColumn get paymentMethod => text()(); // CASH, QR, OTHER
  TextColumn get expenseDate => text()(); // YYYY-MM-DD
  TextColumn get createdBy => text()();
  IntColumn get version => integer().withDefault(const Constant(1))();
  TextColumn get syncStatus => text().withDefault(const Constant('PENDING'))();
  DateTimeColumn get deletedAt => dateTime().nullable()();
  DateTimeColumn get createdAt => dateTime()();
  DateTimeColumn get updatedAt => dateTime()();

  @override
  Set<Column> get primaryKey => {id};

  List<Index> get indexes => [
        Index('idx_expenses_date_category', 'CREATE INDEX idx_expenses_date_category ON expenses_table (expense_date, category_id);'),
        Index('idx_expenses_sync_status', 'CREATE INDEX idx_expenses_sync_status ON expenses_table (sync_status);'),
      ];
}

// ─── TABLAS DE SINCRONIZACIÓN ──────────────────────────────────────────────────

class SyncQueueTable extends Table {
  TextColumn get id => text()();
  TextColumn get operationId => text()(); // UUID PK (idempotency key)
  TextColumn get entityType => text()(); // user, dish, daily_menu, order, expense_category, expense
  TextColumn get entityId => text()();
  TextColumn get operation => text()(); // CREATE, UPDATE, DELETE
  TextColumn get payload => text()(); // JSON string
  DateTimeColumn get clientTimestamp => dateTime()();
  IntColumn get baseVersion => integer().nullable()();
  TextColumn get status => text().withDefault(const Constant('PENDING'))(); // PENDING, PROCESSING, SYNCED, FAILED, CONFLICT
  IntColumn get retryCount => integer().withDefault(const Constant(0))();
  TextColumn get lastError => text().nullable()();
  DateTimeColumn get createdAt => dateTime()();

  @override
  Set<Column> get primaryKey => {operationId};

  List<Index> get indexes => [
        Index('idx_sync_queue_status_created', 'CREATE INDEX idx_sync_queue_status_created ON sync_queue_table (status, created_at);'),
      ];
}

class SyncMetadataTable extends Table {
  TextColumn get key => text()(); // ej. 'last_cursor'
  TextColumn get value => text()();
  DateTimeColumn get updatedAt => dateTime()();

  @override
  Set<Column> get primaryKey => {key};
}

// ─── DATABASE INSTANCE ─────────────────────────────────────────────────────────

@DriftDatabase(tables: [
  UsersSessionTable,
  DishesTable,
  DailyMenusTable,
  DailyMenuDishesTable,
  OrdersTable,
  OrderItemsTable,
  ExpenseCategoriesTable,
  ExpensesTable,
  SyncQueueTable,
  SyncMetadataTable,
])
class AppDatabase extends _$AppDatabase {
  AppDatabase([QueryExecutor? e]) : super(e ?? _openConnection());

  @override
  int get schemaVersion => 1;
}

LazyDatabase _openConnection() {
  return LazyDatabase(() async {
    final dbFolder = await getApplicationDocumentsDirectory();
    final file = File(p.join(dbFolder.path, 'katering_grecia.sqlite'));
    return NativeDatabase.createInBackground(file);
  });
}
