class DishModel {
  final String id;
  final String name;
  final String? description;
  final double price;
  final String? imageUrl;
  final bool active;
  final int version;
  final String syncStatus;
  final DateTime? deletedAt;
  final DateTime createdAt;
  final DateTime updatedAt;

  DishModel({
    required this.id,
    required this.name,
    this.description,
    required this.price,
    this.imageUrl,
    this.active = true,
    this.version = 1,
    this.syncStatus = 'SYNCED',
    this.deletedAt,
    required this.createdAt,
    required this.updatedAt,
  });

  factory DishModel.fromJson(Map<String, dynamic> json) {
    return DishModel(
      id: json['id'] as String,
      name: json['name'] as String,
      description: json['description'] as String?,
      price: (json['price'] as num).toDouble(),
      imageUrl: (json['imageUrl'] ?? json['image_url']) as String?,
      active: json['active'] as bool? ?? true,
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
      'name': name,
      if (description != null) 'description': description,
      'price': price,
      if (imageUrl != null) 'image_url': imageUrl,
      'active': active,
      'version': version,
      'created_at': createdAt.toIso8601String(),
      'updated_at': updatedAt.toIso8601String(),
    };
  }
}
