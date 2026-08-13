class UserModel {
  final String id;
  final String name;
  final String email;
  final bool active;
  final int version;
  final DateTime? createdAt;

  UserModel({
    required this.id,
    required this.name,
    required this.email,
    this.active = true,
    this.version = 1,
    this.createdAt,
  });

  factory UserModel.fromJson(Map<String, dynamic> json) {
    return UserModel(
      id: json['id'] as String,
      name: json['name'] as String,
      email: json['email'] as String,
      active: json['active'] as bool? ?? true,
      version: (json['version'] as num?)?.toInt() ?? 1,
      createdAt: json['createdAt'] != null
          ? DateTime.tryParse(json['createdAt'] as String)
          : (json['created_at'] != null ? DateTime.tryParse(json['created_at'] as String) : null),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name': name,
      'email': email,
      'active': active,
      'version': version,
      if (createdAt != null) 'createdAt': createdAt!.toIso8601String(),
    };
  }
}
