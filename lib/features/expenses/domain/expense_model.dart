class ExpenseModel {
  final String id;
  final String description;
  final double amount;
  final String categoryId;
  final String? categoryName;
  final String paymentMethod; // CASH, QR, OTHER
  final String expenseDate; // YYYY-MM-DD (America/La_Paz)
  final String createdBy;
  final int version;
  final String syncStatus;
  final DateTime? deletedAt;
  final DateTime createdAt;
  final DateTime updatedAt;

  ExpenseModel({
    required this.id,
    required this.description,
    required this.amount,
    required this.categoryId,
    this.categoryName,
    this.paymentMethod = 'CASH',
    required this.expenseDate,
    required this.createdBy,
    this.version = 1,
    this.syncStatus = 'SYNCED',
    this.deletedAt,
    required this.createdAt,
    required this.updatedAt,
  });

  factory ExpenseModel.fromJson(Map<String, dynamic> json) {
    return ExpenseModel(
      id: json['id'] as String,
      description: json['description'] as String? ?? '',
      amount: (json['amount'] as num?)?.toDouble() ?? 0.0,
      categoryId: (json['categoryId'] ?? json['category_id']) as String? ?? '',
      categoryName: (json['categoryName'] ?? json['category_name'] ?? json['category']?['name']) as String?,
      paymentMethod: (json['paymentMethod'] ?? json['payment_method']) as String? ?? 'CASH',
      expenseDate: (json['expenseDate'] ?? json['expense_date']) as String? ?? '',
      createdBy: (json['createdBy'] ?? json['created_by']) as String? ?? 'local-user',
      version: (json['version'] as num?)?.toInt() ?? 1,
      syncStatus: json['syncStatus'] as String? ?? 'SYNCED',
      deletedAt: json['deletedAt'] != null
          ? DateTime.tryParse(json['deletedAt'] as String)
          : (json['deleted_at'] != null ? DateTime.tryParse(json['deleted_at'] as String) : null),
      createdAt: DateTime.tryParse(json['createdAt'] ?? json['created_at'] ?? '') ?? DateTime.now().toUtc(),
      updatedAt: DateTime.tryParse(json['updatedAt'] ?? json['updated_at'] ?? '') ?? DateTime.now().toUtc(),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'description': description,
      'amount': amount,
      'category_id': categoryId,
      'payment_method': paymentMethod,
      'expense_date': expenseDate,
      'created_by': createdBy,
      'version': version,
      'created_at': createdAt.toIso8601String(),
      'updated_at': updatedAt.toIso8601String(),
    };
  }
}
