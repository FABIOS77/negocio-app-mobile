import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
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

  Future<void> _pickCustomRange(BuildContext context, WidgetRef ref) async {
    final nowLaPaz = TimezoneUtils.getNowLaPaz();
    final currentFrom = ref.read(expensesFilterDateFromProvider);
    final currentTo = ref.read(expensesFilterDateToProvider);

    DateTime initialStartDate = currentFrom != null ? DateTime.parse(currentFrom) : nowLaPaz;
    DateTime initialEndDate = currentTo != null ? DateTime.parse(currentTo) : nowLaPaz;

    if (initialStartDate.isAfter(initialEndDate)) {
      initialStartDate = initialEndDate;
    }

    final picked = await showDateRangePicker(
      context: context,
      initialDateRange: DateTimeRange(start: initialStartDate, end: initialEndDate),
      firstDate: DateTime(2020),
      lastDate: DateTime(2035),
      helpText: 'SELECCIONAR RANGO DE GASTOS',
      cancelText: 'CANCELAR',
      confirmText: 'CONFIRMAR',
      builder: (context, child) {
        return Theme(
          data: Theme.of(context).copyWith(
            colorScheme: Theme.of(context).colorScheme.copyWith(
                  primary: Colors.red,
                  onPrimary: Colors.white,
                ),
          ),
          child: child!,
        );
      },
    );

    if (picked != null) {
      final fromStr = DateFormat('yyyy-MM-dd').format(picked.start);
      final toStr = DateFormat('yyyy-MM-dd').format(picked.end);

      ref.read(expensesFilterDateProvider.notifier).state = null;
      ref.read(expensesFilterDateFromProvider.notifier).state = fromStr;
      ref.read(expensesFilterDateToProvider.notifier).state = toStr;
    }
  }

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

    final todayStr = TimezoneUtils.getTodayBusinessDate();
    final yesterdayStr = TimezoneUtils.getYesterdayBusinessDate();
    final weekRange = TimezoneUtils.getThisWeekBusinessDateRange();
    final monthRange = TimezoneUtils.getThisMonthBusinessDateRange();
    final prevMonthRange = TimezoneUtils.getPreviousMonthBusinessDateRange();

    final isAllDates = selectedDate == null && selectedDateFrom == null && selectedDateTo == null;
    final isToday = selectedDate == todayStr;
    final isYesterday = selectedDate == yesterdayStr;
    final isThisWeek = selectedDateFrom == weekRange.from && selectedDateTo == weekRange.to;
    final isThisMonth = selectedDateFrom == monthRange.from && selectedDateTo == monthRange.to;
    final isPrevMonth = selectedDateFrom == prevMonthRange.from && selectedDateTo == prevMonthRange.to;
    final isCustomRange = selectedDateFrom != null && selectedDateTo != null && !isThisWeek && !isThisMonth && !isPrevMonth;

    final hasActiveFilters = selectedCategory != null || selectedPayment != null || !isAllDates;

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
                        if (hasActiveFilters)
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
                            selected: isAllDates,
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
                            selected: isToday,
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
                            label: const Text('Ayer'),
                            selected: isYesterday,
                            onSelected: (selected) {
                              if (selected) {
                                ref.read(expensesFilterDateProvider.notifier).state = yesterdayStr;
                                ref.read(expensesFilterDateFromProvider.notifier).state = null;
                                ref.read(expensesFilterDateToProvider.notifier).state = null;
                              }
                            },
                          ),
                          const SizedBox(width: 6),
                          ChoiceChip(
                            label: const Text('Esta Semana'),
                            selected: isThisWeek,
                            onSelected: (selected) {
                              if (selected) {
                                ref.read(expensesFilterDateProvider.notifier).state = null;
                                ref.read(expensesFilterDateFromProvider.notifier).state = weekRange.from;
                                ref.read(expensesFilterDateToProvider.notifier).state = weekRange.to;
                              }
                            },
                          ),
                          const SizedBox(width: 6),
                          ChoiceChip(
                            label: const Text('Este Mes'),
                            selected: isThisMonth,
                            onSelected: (selected) {
                              if (selected) {
                                ref.read(expensesFilterDateProvider.notifier).state = null;
                                ref.read(expensesFilterDateFromProvider.notifier).state = monthRange.from;
                                ref.read(expensesFilterDateToProvider.notifier).state = monthRange.to;
                              }
                            },
                          ),
                          const SizedBox(width: 6),
                          ChoiceChip(
                            label: const Text('Mes Anterior'),
                            selected: isPrevMonth,
                            onSelected: (selected) {
                              if (selected) {
                                ref.read(expensesFilterDateProvider.notifier).state = null;
                                ref.read(expensesFilterDateFromProvider.notifier).state = prevMonthRange.from;
                                ref.read(expensesFilterDateToProvider.notifier).state = prevMonthRange.to;
                              }
                            },
                          ),
                          const SizedBox(width: 6),
                          ChoiceChip(
                            avatar: const Icon(Icons.date_range, size: 14),
                            label: Text(isCustomRange ? '${TimezoneUtils.formatDisplayDate(selectedDateFrom)} - ${TimezoneUtils.formatDisplayDate(selectedDateTo)}' : 'Personalizado'),
                            selected: isCustomRange,
                            onSelected: (selected) {
                              _pickCustomRange(context, ref);
                            },
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 10),
                    Row(
                      children: [
                        // Category Dropdown
                        Expanded(
                          flex: 3,
                          child: categoriesAsync.when(
                            data: (cats) => Container(
                              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 2),
                              decoration: BoxDecoration(
                                border: Border.all(color: Colors.grey.shade400),
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: DropdownButtonHideUnderline(
                                child: DropdownButton<String?>(
                                  isExpanded: true,
                                  menuMaxHeight: 250,
                                  value: selectedCategory,
                                  hint: const Text('Todas las Categorías', overflow: TextOverflow.ellipsis),
                                  items: [
                                    const DropdownMenuItem(value: null, child: Text('Todas las Categorías', overflow: TextOverflow.ellipsis)),
                                    ...cats.map((c) => DropdownMenuItem(value: c.id, child: Text(c.name, overflow: TextOverflow.ellipsis))),
                                  ],
                                  onChanged: (val) {
                                    ref.read(expensesFilterCategoryProvider.notifier).state = val;
                                  },
                                ),
                              ),
                            ),
                            loading: () => const SizedBox.shrink(),
                            error: (_, __) => const SizedBox.shrink(),
                          ),
                        ),
                        const SizedBox(width: 8),
                        // Payment Method Dropdown
                        Expanded(
                          flex: 2,
                          child: Container(
                            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 2),
                            decoration: BoxDecoration(
                              border: Border.all(color: Colors.grey.shade400),
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: DropdownButtonHideUnderline(
                              child: DropdownButton<String?>(
                                isExpanded: true,
                                menuMaxHeight: 250,
                                value: selectedPayment,
                                hint: const Text('Todos los Pagos', overflow: TextOverflow.ellipsis),
                                items: const [
                                  DropdownMenuItem(value: null, child: Text('Todos los Pagos', overflow: TextOverflow.ellipsis)),
                                  DropdownMenuItem(value: 'CASH', child: Text('Efectivo', overflow: TextOverflow.ellipsis)),
                                  DropdownMenuItem(value: 'QR', child: Text('QR', overflow: TextOverflow.ellipsis)),
                                  DropdownMenuItem(value: 'OTHER', child: Text('Otro', overflow: TextOverflow.ellipsis)),
                                ],
                                onChanged: (val) {
                                  ref.read(expensesFilterPaymentProvider.notifier).state = val;
                                },
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 16),
            expensesAsync.when(
              skipLoadingOnReload: true,
              skipLoadingOnRefresh: true,
              data: (expenses) {
                if (expenses.isEmpty) {
                  return const EmptyStateWidget(
                    icon: Icons.money_off,
                    title: 'No hay gastos registrados',
                    subtitle: 'Los gastos registrados aparecerán aquí y se sincronizarán cuando estés en línea.',
                  );
                }

                final totalExpenses = expenses.fold<double>(0.0, (sum, item) => sum + item.amount);

                return Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text('Listado de Gastos (${expenses.length}):', style: const TextStyle(fontWeight: FontWeight.bold)),
                        Text('Total: ${CurrencyFormatter.formatBOB(totalExpenses)}', style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.red)),
                      ],
                    ),
                    const SizedBox(height: 8),
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
                                      const SnackBar(content: Text('Gasto actualizado offline'), backgroundColor: Colors.green),
                                    );
                                  }
                                },
                              ),
                            );
                          },
                          onDelete: () async {
                            final confirm = await showDialog<bool>(
                              context: context,
                              builder: (ctx) => const ConfirmDialog(
                                title: 'Eliminar Gasto',
                                content: '¿Estás seguro de eliminar este gasto? El registro se marcará para borrado y sincronización.',
                                confirmLabel: 'ELIMINAR',
                              ),
                            );
                            if (confirm == true) {
                              await repository.deleteExpense(expense.id);
                              if (context.mounted) {
                                ScaffoldMessenger.of(context).showSnackBar(
                                  const SnackBar(content: Text('Gasto eliminado offline'), backgroundColor: Colors.orange),
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
