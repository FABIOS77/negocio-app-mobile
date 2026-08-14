import 'package:flutter/material.dart';
import '../../domain/dish_model.dart';

class DishImageAvatar extends StatelessWidget {
  final DishModel dish;
  final double size;

  const DishImageAvatar({
    super.key,
    required this.dish,
    this.size = 50.0,
  });

  @override
  Widget build(BuildContext context) {
    final url = dish.imageUrl?.trim();
    final hasValidUrl = url != null && url.isNotEmpty && (url.startsWith('http://') || url.startsWith('https://'));

    final fallback = CircleAvatar(
      radius: size / 2,
      backgroundColor: dish.active ? Colors.deepOrange.shade100 : Colors.grey.shade300,
      child: Icon(
        dish.active ? Icons.restaurant : Icons.block,
        color: dish.active ? Colors.deepOrange : Colors.grey,
        size: size * 0.5,
      ),
    );

    if (!hasValidUrl) {
      return fallback;
    }

    return SizedBox(
      width: size,
      height: size,
      child: ClipRRect(
        borderRadius: BorderRadius.circular(8),
        child: Image.network(
          url,
          width: size,
          height: size,
          fit: BoxFit.cover,
          errorBuilder: (context, error, stackTrace) => fallback,
        ),
      ),
    );
  }
}
