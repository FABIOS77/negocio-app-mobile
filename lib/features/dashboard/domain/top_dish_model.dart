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
      totalQuantity: (json['total_quantity'] ?? json['totalQuantity'] as num?)?.toInt() ?? 0,
      totalRevenue: (json['total_revenue'] ?? json['totalRevenue'] as num?)?.toDouble() ?? 0.0,
    );
  }
}
