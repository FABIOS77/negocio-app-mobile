import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../financial_metrics/presentation/widgets/financial_summary_card.dart';
import '../application/expenses_notifier.dart';
import 'expense_detail_dialog.dart';
import 'widgets/expense_tile.dart';

class ExpensesScreen extends ConsumerWidget {
  const ExpensesScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final expensesAsync = ref.watch(expensesStreamProvider);
    final categoriesAsync = ref.watch(expenseCategoriesStreamProvider);
    final selectedCategory = ref.watch(expensesFilterCategoryProvider);
    final selectedPayment = ref.watch(expensesFilterPaymentProvider);
    final repository = ref.read(expensesRepositoryProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Control de Gastos', style: TextStyle(fontWeight: FontWeight.bold)),
      ),
      floatingActionButton: FloatingActionButton.extended(
        backgroundColor: Colors.red,
        icon: const Icon(Icons.add, color: Colors.white),
        label: const Text('NUEVO GASTO', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
        onPressed: () {
          final categories = categoriesAsync.asData?.value ?? [];
          showDialog(
            context: context,
            builder: (ctx) => ExpenseDetailDialog(
              categories: categories,
              onSave: (description, amount, categoryId, paymentMethod, expenseDate) async {
                await repository.createExpense(
                  description: description,
                  amount: amount,
                  categoryId: categoryId,
                  paymentMethod: paymentMethod,
                  expenseDate: expenseDate,
                );
              },
            ),
          );
        },
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const FinancialSummaryCard(),
            const SizedBox(height: 16),
            Card(
              child: Padding(
                padding: const EdgeInsets.all(12.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text('Filtros de Gastos:', style: TextStyle(fontWeight: FontWeight.bold)),
                    const SizedBox(height: 8),
                    Row(
                      children: [
                        Expanded(
                          child: DropdownButtonFormField<String?>(
                            initialValue: selectedCategory,
                            decoration: const InputDecoration(labelText: 'Categoría', border: OutlineInputBorder()),
                            items: [
                              const DropdownMenuItem(value: null, child: Text('Todas')),
                              ...(categoriesAsync.asData?.value ?? []).map(
                                (c) => DropdownMenuItem(value: c.id, child: Text(c.name)),
                              ),
                            ],
                            onChanged: (val) {
                              ref.read(expensesFilterCategoryProvider.notifier).state = val;
                            },
                          ),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: DropdownButtonFormField<String?>(
                            initialValue: selectedPayment,
                            decoration: const InputDecoration(labelText: 'Pago', border: OutlineInputBorder()),
                            items: const [
                              DropdownMenuItem(value: null, child: Text('Todos')),
                              DropdownMenuItem(value: 'CASH', child: Text('Efectivo')),
                              DropdownMenuItem(value: 'QR', child: Text('QR')),
                              DropdownMenuItem(value: 'OTHER', child: Text('Otro')),
                            ],
                            onChanged: (val) {
                              ref.read(expensesFilterPaymentProvider.notifier).state = val;
                            },
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 16),
            const Text('Historial de Gastos:', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
            const SizedBox(height: 8),
            expensesAsync.when(
              data: (expenses) {
                if (expenses.isEmpty) {
                  return const Card(
                    child: Padding(
                      padding: EdgeInsets.all(24.0),
                      child: Center(
                        child: Text(
                          'No hay gastos registrados para los filtros seleccionados.\n¡Toca + NUEVO GASTO para agregar uno offline!',
                          textAlign: TextAlign.center,
                          style: TextStyle(color: Colors.grey),
                        ),
                      ),
                    ),
                  );
                }
                return ListView.builder(
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  itemCount: expenses.length,
                  itemBuilder: (context, index) {
                    final expense = expenses[index];
                    return ExpenseTile(
                      expense: expense,
                      onTap: () {
                        final categories = categoriesAsync.asData?.value ?? [];
                        showDialog(
                          context: context,
                          builder: (ctx) => ExpenseDetailDialog(
                            expense: expense,
                            categories: categories,
                            onSave: (description, amount, categoryId, paymentMethod, expenseDate) async {
                              await repository.updateExpense(
                                id: expense.id,
                                description: description,
                                amount: amount,
                                categoryId: categoryId,
                                paymentMethod: paymentMethod,
                                expenseDate: expenseDate,
                              );
                            },
                          ),
                        );
                      },
                      onDelete: () async {
                        final confirm = await showDialog<bool>(
                          context: context,
                          builder: (ctx) => AlertDialog(
                            title: const Text('Eliminar Gasto'),
                            content: Text('¿Desea eliminar el gasto "${expense.description}" por Bs ${expense.amount}?'),
                            actions: [
                              TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancelar')),
                              ElevatedButton(
                                style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
                                onPressed: () => Navigator.pop(ctx, true),
                                child: const Text('ELIMINAR'),
                              ),
                            ],
                          ),
                        );
                        if (confirm ?? false) {
                          await repository.deleteExpense(expense.id);
                        }
                      },
                    );
                  },
                );
              },
              loading: () => const Center(child: CircularProgressIndicator()),
              error: (err, _) => Center(child: Text('Error: $err')),
            ),
          ],
        ),
      ),
    );
  }
}
