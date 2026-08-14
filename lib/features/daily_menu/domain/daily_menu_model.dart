import '../../../core/utils/parse_utils.dart';
import '../../dishes/domain/dish_model.dart';

class DailyMenuModel {
  final String id;
  final String menuDate; // YYYY-MM-DD (America/La_Paz)
  final bool active;
  final int version;
  final String syncStatus;
  final List<DishModel> dishes;
  final DateTime createdAt;
  final DateTime updatedAt;

  DailyMenuModel({
    required this.id,
    required this.menuDate,
    this.active = true,
    this.version = 1,
    this.syncStatus = 'SYNCED',
    this.dishes = const [],
    required this.createdAt,
    required this.updatedAt,
  });

  factory DailyMenuModel.fromJson(Map<String, dynamic> json) {
    final rawDishes = (json['dishes'] as List? ?? []);
    final dishesList = rawDishes.map((d) {
      if (d is Map<String, dynamic>) {
        return DishModel.fromJson(d);
      }
      return DishModel(
        id: d as String,
        name: 'Plato',
        price: 0.0,
        createdAt: DateTime.now().toUtc(),
        updatedAt: DateTime.now().toUtc(),
      );
    }).toList();

    return DailyMenuModel(
      id: json['id'] as String,
      menuDate: (json['menuDate'] ?? json['menu_date']) as String,
      active: json['active'] as bool? ?? true,
      version: ParseUtils.toInt(json['version'], 1),
      syncStatus: json['syncStatus'] as String? ?? 'SYNCED',
      dishes: dishesList,
      createdAt: DateTime.tryParse(json['createdAt'] ?? json['created_at'] ?? '') ?? DateTime.now().toUtc(),
      updatedAt: DateTime.tryParse(json['updatedAt'] ?? json['updated_at'] ?? '') ?? DateTime.now().toUtc(),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'menu_date': menuDate,
      'active': active,
      'version': version,
      'dish_ids': dishes.map((d) => d.id).toList(),
      'created_at': createdAt.toIso8601String(),
      'updated_at': updatedAt.toIso8601String(),
    };
  }
}
