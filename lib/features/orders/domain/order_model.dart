import '../../../core/utils/parse_utils.dart';
import 'order_item_model.dart';

class OrderModel {
  final String id;
  final String? orderNumber;
  final String customerName;
  final String? locationText;
  final double total;
  final String paymentMethod; // CASH, QR, OTHER
  final String status; // PENDING, DELIVERED, CANCELLED
  final DateTime orderedAt;
  final String createdBy;
  final int version;
  final String syncStatus;
  final List<OrderItemModel> items;
  final DateTime createdAt;
  final DateTime updatedAt;

  OrderModel({
    required this.id,
    this.orderNumber,
    required this.customerName,
    this.locationText,
    required this.total,
    this.paymentMethod = 'CASH',
    this.status = 'PENDING',
    required this.orderedAt,
    required this.createdBy,
    this.version = 1,
    this.syncStatus = 'SYNCED',
    this.items = const [],
    required this.createdAt,
    required this.updatedAt,
  });

  factory OrderModel.fromJson(Map<String, dynamic> json) {
    final rawItems = (json['items'] as List? ?? []);
    final itemsList = rawItems.map((i) => OrderItemModel.fromJson(i as Map<String, dynamic>)).toList();

    final isDeleted = json['deleted'] == true ||
        json['deleted_at'] != null ||
        json['deletedAt'] != null ||
        json['status'] == 'CANCELLED';

    final status = isDeleted ? 'CANCELLED' : (json['status'] as String? ?? 'PENDING');

    return OrderModel(
      id: json['id'] as String,
      orderNumber: (json['orderNumber'] ?? json['order_number'])?.toString(),
      customerName: (json['customerName'] ?? json['customer_name']) as String? ?? 'Cliente',
      locationText: (json['locationText'] ?? json['location_text']) as String?,
      total: ParseUtils.toDouble(json['total']),
      paymentMethod: (json['paymentMethod'] ?? json['payment_method']) as String? ?? 'CASH',
      status: status,
      orderedAt: DateTime.tryParse(json['orderedAt'] ?? json['ordered_at'] ?? '') ?? DateTime.now().toUtc(),
      createdBy: (json['createdBy'] ?? json['created_by']) as String? ?? 'local-user',
      version: ParseUtils.toInt(json['version'], 1),
      syncStatus: json['syncStatus'] as String? ?? 'SYNCED',
      items: itemsList,
      createdAt: DateTime.tryParse(json['createdAt'] ?? json['created_at'] ?? '') ?? DateTime.now().toUtc(),
      updatedAt: DateTime.tryParse(json['updatedAt'] ?? json['updated_at'] ?? '') ?? DateTime.now().toUtc(),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      if (orderNumber != null) 'order_number': orderNumber,
      'customer_name': customerName,
      if (locationText != null) 'location_text': locationText,
      'total': total,
      'payment_method': paymentMethod,
      'status': status,
      'ordered_at': orderedAt.toIso8601String(),
      'created_by': createdBy,
      'version': version,
      'items': items.map((i) => {'dish_id': i.dishId, 'quantity': i.quantity}).toList(),
      'created_at': createdAt.toIso8601String(),
      'updated_at': updatedAt.toIso8601String(),
    };
  }
}
