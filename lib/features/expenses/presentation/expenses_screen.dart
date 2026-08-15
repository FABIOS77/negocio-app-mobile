import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/utils/currency_formatter.dart';
import '../../../core/utils/timezone_utils.dart';
import '../../common/presentation/widgets/confirm_dialog.dart';
import '../../common/presentation/widgets/empty_state_widget.dart';
import '../../financial_metrics/presentation/widgets/financial_summary_card.dart';
import '../application/expenses_notifier.dart';
import 'expense_detail_dialog.dart';
import 'widgets/expense_tile.dart';
import 'widgets/manage_categories_dialog.dart';

class ExpensesScreen extends ConsumerWidget {
  const ExpensesScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final expensesAsync = ref.watch(expensesStreamProvider);
    final categoriesAsync = ref.watch(expenseCategoriesStreamProvider);
    final selectedCategory = ref.watch(expensesFilterCategoryProvider);
    final selectedPayment = ref.watch(expensesFilterPaymentProvider);
    final selectedDate = ref.watch(expensesFilterDateProvider);
    final selectedDateFrom = ref.watch(expensesFilterDateFromProvider);
    final selectedDateTo = ref.watch(expensesFilterDateToProvider);
    final repository = ref.read(expensesRepositoryProvider);

    final isCustomRange = selectedDateFrom != null && selectedDateTo != null;
    final todayStr = TimezoneUtils.getTodayBusinessDate();

    return Scaffold(
      appBar: AppBar(
        title: const Text('Control de Gastos', style: TextStyle(fontWeight: FontWeight.bold)),
        actions: [
          IconButton(
            icon: const Icon(Icons.category),
            tooltip: 'Administrar Categorías',
            onPressed: () => ManageCategoriesDialog.show(context),
          ),
        ],
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
                    const SnackBar(content: Text('Gasto registrado offline exitosamente'), backgroundColor: Colors.green),
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
              elevation: 2,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              child: Padding(
                padding: const EdgeInsets.all(12.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Text('Filtros de Gastos:', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
                        if (selectedCategory != null || selectedPayment != null || selectedDate != null || isCustomRange)
                          TextButton(
                            onPressed: () {
                              ref.read(expensesFilterCategoryProvider.notifier).state = null;
                              ref.read(expensesFilterPaymentProvider.notifier).state = null;
                              ref.read(expensesFilterDateProvider.notifier).state = null;
                              ref.read(expensesFilterDateFromProvider.notifier).state = null;
                              ref.read(expensesFilterDateToProvider.notifier).state = null;
                            },
                            child: const Text('Limpiar Filtros', style: TextStyle(fontSize: 12, color: Colors.red)),
                          ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    // Quick Date Chips
                    SingleChildScrollView(
                      scrollDirection: Axis.horizontal,
                      child: Row(
                        children: [
                          ChoiceChip(
                            label: const Text('Todos'),
                            selected: selectedDate == null && !isCustomRange,
                            onSelected: (selected) {
                              if (selected) {
                                ref.read(expensesFilterDateProvider.notifier).state = null;
                                ref.read(expensesFilterDateFromProvider.notifier).state = null;
                                ref.read(expensesFilterDateToProvider.notifier).state = null;
                              }
                            },
                          ),
                          const SizedBox(width: 6),
                          ChoiceChip(
                            label: const Text('Hoy'),
                            selected: selectedDate == todayStr,
                            onSelected: (selected) {
                              if (selected) {
                                ref.read(expensesFilterDateProvider.notifier).state = todayStr;
                                ref.read(expensesFilterDateFromProvider.notifier).state = null;
                                ref.read(expensesFilterDateToProvider.notifier).state = null;
                              }
                            },
                          ),
                          const SizedBox(width: 6),
                          ChoiceChip(
                            label: const Text('Esta Semana'),
                            selected: isCustomRange,
                            onSelected: (selected) {
                              if (selected) {
                                final now = DateTime.now();
                                final startOfWeek = now.subtract(Duration(days: now.weekday - 1));
                                final fromStr = TimezoneUtils.toBusinessDateString(startOfWeek);
                                ref.read(expensesFilterDateProvider.notifier).state = null;
                                ref.read(expensesFilterDateFromProvider.notifier).state = fromStr;
                                ref.read(expensesFilterDateToProvider.notifier).state = todayStr;
                              }
                            },
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 10),
                    Row(
                      children: [
                        Expanded(
                          flex: 3,
                          child: DropdownButtonFormField<String?>(
                            isExpanded: true,
                            menuMaxHeight: 250,
                            initialValue: selectedCategory,
                            decoration: const InputDecoration(
                              labelText: 'Categoría',
                              border: OutlineInputBorder(),
                              contentPadding: EdgeInsets.symmetric(horizontal: 10, vertical: 10),
                            ),
                            items: [
                              const DropdownMenuItem(value: null, child: Text('Todas', overflow: TextOverflow.ellipsis)),
                              ...(categoriesAsync.asData?.value ?? []).map(
                                (c) => DropdownMenuItem(value: c.id, child: Text(c.name, overflow: TextOverflow.ellipsis)),
                              ),
                            ],
                            onChanged: (val) {
                              ref.read(expensesFilterCategoryProvider.notifier).state = val;
                            },
                          ),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          flex: 2,
                          child: DropdownButtonFormField<String?>(
                            isExpanded: true,
                            menuMaxHeight: 250,
                            initialValue: selectedPayment,
                            decoration: const InputDecoration(
                              labelText: 'Pago',
                              border: OutlineInputBorder(),
                              contentPadding: EdgeInsets.symmetric(horizontal: 10, vertical: 10),
                            ),
                            items: const [
                              DropdownMenuItem(value: null, child: Text('Todos', overflow: TextOverflow.ellipsis)),
                              DropdownMenuItem(value: 'CASH', child: Text('Efectivo', overflow: TextOverflow.ellipsis)),
                              DropdownMenuItem(value: 'QR', child: Text('QR', overflow: TextOverflow.ellipsis)),
                              DropdownMenuItem(value: 'OTHER', child: Text('Otro', overflow: TextOverflow.ellipsis)),
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
                        title: 'No hay gastos registrados para este filtro',
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
                                      const SnackBar(content: Text('Gasto actualizado exitosamente'), backgroundColor: Colors.green),
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
                                  const SnackBar(content: Text('Gasto eliminado exitosamente'), backgroundColor: Colors.green),
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
