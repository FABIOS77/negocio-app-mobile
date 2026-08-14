import '../../../core/utils/parse_utils.dart';

class ProductionItemModel {
  final String dishId;
  final String dishName;
  final int totalQuantity;

  ProductionItemModel({
    required this.dishId,
    required this.dishName,
    required this.totalQuantity,
  });

  factory ProductionItemModel.fromJson(Map<String, dynamic> json) {
    return ProductionItemModel(
      dishId: (json['dish_id'] ?? json['dishId']) as String? ?? '',
      dishName: (json['dish_name'] ?? json['dishName'] ?? json['name']) as String? ?? 'Plato',
      totalQuantity: ParseUtils.toInt(json['total_quantity'] ?? json['quantity'] ?? json['totalQuantity']),
    );
  }
}
