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
    final rawImageUrl = (json['imageUrl'] ?? json['image_url']) as String?;
    final cleanImageUrl = (rawImageUrl != null && rawImageUrl.trim().isNotEmpty) ? rawImageUrl.trim() : null;
    final rawDescription = json['description'] as String?;
    final cleanDescription = (rawDescription != null && rawDescription.trim().isNotEmpty) ? rawDescription.trim() : null;

    return DishModel(
      id: json['id'] as String,
      name: json['name'] as String,
      description: cleanDescription,
      price: (json['price'] as num).toDouble(),
      imageUrl: cleanImageUrl,
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
    final cleanImageUrl = (imageUrl != null && imageUrl!.trim().isNotEmpty) ? imageUrl!.trim() : null;
    final cleanDescription = (description != null && description!.trim().isNotEmpty) ? description!.trim() : null;

    return {
      'id': id,
      'name': name.trim(),
      'description': cleanDescription,
      'price': price,
      'imageUrl': cleanImageUrl,
      'image_url': cleanImageUrl,
      'active': active,
      'version': version,
      'created_at': createdAt.toIso8601String(),
      'updated_at': updatedAt.toIso8601String(),
    };
  }
}
