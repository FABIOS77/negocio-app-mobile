class OrderItemModel {
  final String id;
  final String orderId;
  final String dishId;
  final String dishNameSnapshot;
  final int quantity;
  final double unitPrice;
  final double subtotal;

  OrderItemModel({
    required this.id,
    required this.orderId,
    required this.dishId,
    required this.dishNameSnapshot,
    required this.quantity,
    required this.unitPrice,
    required this.subtotal,
  });

  factory OrderItemModel.fromJson(Map<String, dynamic> json) {
    final qty = (json['quantity'] as num?)?.toInt() ?? 1;
    final price = (json['unitPrice'] as num?)?.toDouble() ?? (json['unit_price'] as num?)?.toDouble() ?? 0.0;
    final calculatedSubtotal = (json['subtotal'] as num?)?.toDouble() ?? (qty * price);

    return OrderItemModel(
      id: json['id'] as String? ?? '',
      orderId: (json['orderId'] ?? json['order_id']) as String? ?? '',
      dishId: (json['dishId'] ?? json['dish_id']) as String? ?? '',
      dishNameSnapshot: (json['dishNameSnapshot'] ?? json['dish_name_snapshot'] ?? json['dish']?['name']) as String? ?? 'Plato',
      quantity: qty,
      unitPrice: price,
      subtotal: calculatedSubtotal,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'order_id': orderId,
      'dish_id': dishId,
      'dish_name_snapshot': dishNameSnapshot,
      'quantity': quantity,
      'unit_price': unitPrice,
      'subtotal': subtotal,
    };
  }
}
