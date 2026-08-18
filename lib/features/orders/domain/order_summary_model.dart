import '../../../core/utils/parse_utils.dart';

class OrderSummaryModel {
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
  final int itemsCount;
  final DateTime createdAt;
  final DateTime updatedAt;

  OrderSummaryModel({
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
    this.itemsCount = 0,
    required this.createdAt,
    required this.updatedAt,
  });

  factory OrderSummaryModel.fromJson(Map<String, dynamic> json) {
    final isDeleted = json['deleted'] == true ||
        json['deleted_at'] != null ||
        json['deletedAt'] != null ||
        json['status'] == 'CANCELLED';

    final status = isDeleted ? 'CANCELLED' : (json['status'] as String? ?? 'PENDING');

    return OrderSummaryModel(
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
      itemsCount: ParseUtils.toInt(json['itemsCount'] ?? json['items_count'], 0),
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
      'items_count': itemsCount,
      'created_at': createdAt.toIso8601String(),
      'updated_at': updatedAt.toIso8601String(),
    };
  }
}
