import '../../../core/utils/parse_utils.dart';

class TopDishModel {
  final String dishId;
  final String dishName;
  final int totalQuantity;
  final double totalRevenue;

  TopDishModel({
    required this.dishId,
    required this.dishName,
    required this.totalQuantity,
    required this.totalRevenue,
  });

  factory TopDishModel.fromJson(Map<String, dynamic> json) {
    return TopDishModel(
      dishId: (json['dish_id'] ?? json['dishId']) as String? ?? '',
      dishName: (json['dish_name_snapshot'] ?? json['dish_name'] ?? json['dishName']) as String? ?? 'Plato',
      totalQuantity: ParseUtils.toInt(json['total_quantity'] ?? json['totalQuantity']),
      totalRevenue: ParseUtils.toDouble(json['total_revenue'] ?? json['totalRevenue']),
    );
  }
}
