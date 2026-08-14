import '../../../core/utils/parse_utils.dart';

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
    final qty = ParseUtils.toInt(json['quantity'], 1);
    final price = ParseUtils.toDouble(json['unitPrice'] ?? json['unit_price']);
    final rawSubtotal = json['subtotal'];
    final calculatedSubtotal = rawSubtotal != null ? ParseUtils.toDouble(rawSubtotal) : (qty * price);

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
