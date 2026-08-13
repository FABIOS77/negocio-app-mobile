import 'package:flutter/material.dart';
import '../../../../core/utils/currency_formatter.dart';
import '../../domain/expense_model.dart';

class ExpenseTile extends StatelessWidget {
  final ExpenseModel expense;
  final VoidCallback onTap;
  final VoidCallback onDelete;

  const ExpenseTile({
    super.key,
    required this.expense,
    required this.onTap,
    required this.onDelete,
  });

  @override
  Widget build(BuildContext context) {
    final isPending = expense.syncStatus == 'PENDING';

    return Card(
      elevation: 2,
      margin: const EdgeInsets.only(bottom: 10),
      child: ListTile(
        onTap: onTap,
        leading: CircleAvatar(
          backgroundColor: Colors.red.shade100,
          child: const Icon(Icons.receipt_long, color: Colors.red),
        ),
        title: Text(
          expense.description,
          style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
        ),
        subtitle: Text(
          'Cat: ${expense.categoryName ?? 'General'} • ${expense.paymentMethod} • ${expense.expenseDate}\nSync: ${isPending ? 'Pendiente' : 'Sincronizado'}',
          style: const TextStyle(fontSize: 12),
        ),
        trailing: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              '-${CurrencyFormatter.formatBOB(expense.amount)}',
              style: const TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.bold,
                color: Colors.red,
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
}
