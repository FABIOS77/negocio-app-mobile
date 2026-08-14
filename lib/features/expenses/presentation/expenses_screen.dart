import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/utils/currency_formatter.dart';
import '../../common/presentation/widgets/confirm_dialog.dart';
import '../../common/presentation/widgets/empty_state_widget.dart';
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
                if (context.mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Gasto registrado offline exitosamente')),
                  );
                }
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
                    Wrap(
                      runSpacing: 10.0,
                      spacing: 8.0,
                      children: [
                        SizedBox(
                          width: 170,
                          child: DropdownButtonFormField<String?>(
                            initialValue: selectedCategory,
                            decoration: const InputDecoration(
                              labelText: 'Categoría',
                              border: OutlineInputBorder(),
                              contentPadding: EdgeInsets.symmetric(horizontal: 10, vertical: 12),
                            ),
                            items: [
                              const DropdownMenuItem(value: null, child: Text('Todas')),
                              ...(categoriesAsync.asData?.value ?? []).map(
                                (c) => DropdownMenuItem(value: c.id, child: Text(c.name, overflow: TextOverflow.ellipsis)),
                              ),
                            ],
                            onChanged: (val) {
                              ref.read(expensesFilterCategoryProvider.notifier).state = val;
                            },
                          ),
                        ),
                        SizedBox(
                          width: 150,
                          child: DropdownButtonFormField<String?>(
                            initialValue: selectedPayment,
                            decoration: const InputDecoration(
                              labelText: 'Pago',
                              border: OutlineInputBorder(),
                              contentPadding: EdgeInsets.symmetric(horizontal: 10, vertical: 12),
                            ),
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
              skipLoadingOnReload: true,
              skipLoadingOnRefresh: true,
              data: (expenses) {
                if (expenses.isEmpty) {
                  return const Card(
                    child: Padding(
                      padding: EdgeInsets.all(16.0),
                      child: EmptyStateWidget(
                        icon: Icons.money_off,
                        title: 'No hay gastos registrados',
                        subtitle: '¡Toca el botón + NUEVO GASTO para registrar egresos offline!',
                      ),
                    ),
                  );
                }
                return Column(
                  children: [
                    if (expensesAsync.isRefreshing || expensesAsync.isReloading)
                      const Padding(
                        padding: EdgeInsets.only(bottom: 8.0),
                        child: LinearProgressIndicator(minHeight: 2),
                      ),
                    ListView.builder(
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
                                  if (context.mounted) {
                                    ScaffoldMessenger.of(context).showSnackBar(
                                      const SnackBar(content: Text('Gasto actualizado')),
                                    );
                                  }
                                },
                              ),
                            );
                          },
                          onDelete: () async {
                            final confirm = await ConfirmDialog.show(
                              context,
                              title: 'Eliminar Gasto',
                              content: '¿Desea eliminar el gasto "${expense.description}" por ${CurrencyFormatter.formatBOB(expense.amount)}?',
                              confirmLabel: 'SÍ, ELIMINAR',
                              confirmColor: Colors.red,
                            );
                            if (confirm) {
                              await repository.deleteExpense(expense.id);
                              if (context.mounted) {
                                ScaffoldMessenger.of(context).showSnackBar(
                                  const SnackBar(content: Text('Gasto eliminado')),
                                );
                              }
                            }
                          },
                        );
                      },
                    ),
                  ],
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
