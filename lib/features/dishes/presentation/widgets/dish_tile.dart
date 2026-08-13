import 'package:flutter/material.dart';
import '../../../../core/utils/currency_formatter.dart';
import '../../domain/dish_model.dart';

class DishTile extends StatelessWidget {
  final DishModel dish;
  final VoidCallback onTap;
  final VoidCallback onDelete;

  const DishTile({
    super.key,
    required this.dish,
    required this.onTap,
    required this.onDelete,
  });

  @override
  Widget build(BuildContext context) {
    final isPending = dish.syncStatus == 'PENDING';
    final isConflict = dish.syncStatus == 'CONFLICT';

    return Card(
      elevation: 2,
      margin: const EdgeInsets.only(bottom: 10),
      child: ListTile(
        onTap: onTap,
        leading: ClipRRect(
          borderRadius: BorderRadius.circular(8),
          child: dish.imageUrl != null && dish.imageUrl!.isNotEmpty
              ? Image.network(
                  dish.imageUrl!,
                  width: 50,
                  height: 50,
                  fit: BoxFit.cover,
                  errorBuilder: (context, error, stackTrace) => _buildPlaceholder(),
                )
              : _buildPlaceholder(),
        ),
        title: Text(
          dish.name,
          style: TextStyle(
            fontWeight: FontWeight.bold,
            fontSize: 16,
            decoration: dish.active ? null : TextDecoration.lineThrough,
          ),
        ),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (dish.description != null && dish.description!.isNotEmpty)
              Text(dish.description!, maxLines: 1, overflow: TextOverflow.ellipsis),
            Row(
              children: [
                Icon(
                  isPending ? Icons.cloud_upload : (isConflict ? Icons.warning : Icons.cloud_done),
                  size: 14,
                  color: isPending ? Colors.orange : (isConflict ? Colors.purple : Colors.green),
                ),
                const SizedBox(width: 4),
                Text(
                  isPending ? 'Pendiente' : (isConflict ? 'Conflicto' : 'Sincronizado'),
                  style: TextStyle(
                    fontSize: 11,
                    color: isPending ? Colors.orange : (isConflict ? Colors.purple : Colors.green),
                  ),
                ),
              ],
            ),
          ],
        ),
        trailing: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              CurrencyFormatter.formatBOB(dish.price),
              style: const TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.bold,
                color: Colors.deepOrange,
              ),
            ),
            IconButton(
              icon: const Icon(Icons.delete_outline, color: Colors.redAccent),
              onPressed: onDelete,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildPlaceholder() {
    return Container(
      width: 50,
      height: 50,
      color: Colors.deepOrange.shade100,
      child: const Icon(Icons.restaurant, color: Colors.deepOrange),
    );
  }
}
