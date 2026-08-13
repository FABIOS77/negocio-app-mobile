class ExpenseCategoryModel {
  final String id;
  final String name;
  final bool active;
  final int version;
  final DateTime createdAt;
  final DateTime updatedAt;

  ExpenseCategoryModel({
    required this.id,
    required this.name,
    this.active = true,
    this.version = 1,
    required this.createdAt,
    required this.updatedAt,
  });

  factory ExpenseCategoryModel.fromJson(Map<String, dynamic> json) {
    return ExpenseCategoryModel(
      id: json['id'] as String,
      name: json['name'] as String,
      active: json['active'] as bool? ?? true,
      version: (json['version'] as num?)?.toInt() ?? 1,
      createdAt: DateTime.tryParse(json['createdAt'] ?? json['created_at'] ?? '') ?? DateTime.now().toUtc(),
      updatedAt: DateTime.tryParse(json['updatedAt'] ?? json['updated_at'] ?? '') ?? DateTime.now().toUtc(),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name': name,
      'active': active,
      'version': version,
      'created_at': createdAt.toIso8601String(),
      'updated_at': updatedAt.toIso8601String(),
    };
  }
}
