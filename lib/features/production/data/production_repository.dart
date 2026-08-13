import 'package:drift/drift.dart';
import '../../../core/database/app_database.dart';
import '../../../core/utils/timezone_utils.dart';
import '../domain/production_item_model.dart';

class ProductionRepository {
  final AppDatabase _db;

  ProductionRepository({required AppDatabase db}) : _db = db;

  /// Observa reactivamente el resumen de producción de cocina mediante agregación SQL nativa de SQLite (SUM + GROUP BY)
  Stream<List<ProductionItemModel>> watchProductionSummary({String? date}) {
    final businessDate = date ?? TimezoneUtils.getTodayBusinessDate();

    final dateStart = DateTime.parse('${businessDate}T00:00:00.000Z').add(const Duration(hours: 4));
    final dateEnd = dateStart.add(const Duration(days: 1));

    return _db.customSelect(
      '''
      SELECT oi.dish_id, oi.dish_name_snapshot, SUM(oi.quantity) as total_quantity
      FROM order_items_table oi
      INNER JOIN orders_table o ON o.id = oi.order_id
      WHERE o.ordered_at >= ? AND o.ordered_at < ? AND o.status != 'CANCELLED'
      GROUP BY oi.dish_id, oi.dish_name_snapshot
      ORDER BY total_quantity DESC
      ''',
      variables: [
        Variable.withDateTime(dateStart),
        Variable.withDateTime(dateEnd),
      ],
      readsFrom: {_db.ordersTable, _db.orderItemsTable},
    ).watch().map((rows) {
      return rows.map((r) {
        return ProductionItemModel(
          dishId: r.read<String>('dish_id'),
          dishName: r.read<String>('dish_name_snapshot'),
          totalQuantity: r.read<int>('total_quantity'),
        );
      }).toList();
    });
  }
}
