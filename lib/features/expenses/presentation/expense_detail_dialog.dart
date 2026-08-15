import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/utils/timezone_utils.dart';
import '../application/expenses_notifier.dart';
import '../domain/expense_category_model.dart';
import '../domain/expense_model.dart';

class ExpenseDetailDialog extends ConsumerStatefulWidget {
  final ExpenseModel? expense;
  final List<ExpenseCategoryModel> categories;
  final Function(String description, double amount, String categoryId, String paymentMethod, String expenseDate) onSave;

  const ExpenseDetailDialog({
    super.key,
    this.expense,
    required this.categories,
    required this.onSave,
  });

  @override
  ConsumerState<ExpenseDetailDialog> createState() => _ExpenseDetailDialogState();
}

class _ExpenseDetailDialogState extends ConsumerState<ExpenseDetailDialog> {
  late TextEditingController _descController;
  late TextEditingController _amountController;
  late TextEditingController _dateController;
  late String _selectedCategoryId;
  String _paymentMethod = 'CASH';
  final _formKey = GlobalKey<FormState>();

  @override
  void initState() {
    super.initState();
    _descController = TextEditingController(text: widget.expense?.description ?? '');
    _amountController = TextEditingController(text: widget.expense != null ? widget.expense!.amount.toString() : '');
    _dateController = TextEditingController(text: widget.expense?.expenseDate ?? TimezoneUtils.getTodayBusinessDate());
    _selectedCategoryId = widget.expense?.categoryId ?? (widget.categories.isNotEmpty ? widget.categories.first.id : '');
    _paymentMethod = widget.expense?.paymentMethod ?? 'CASH';
  }

  @override
  void dispose() {
    _descController.dispose();
    _amountController.dispose();
    _dateController.dispose();
    super.dispose();
  }

  void _submit() {
    if (_formKey.currentState?.validate() ?? false) {
      if (_selectedCategoryId.isEmpty) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Seleccione una categoría')));
        return;
      }
      final desc = _descController.text.trim();
      final amount = double.parse(_amountController.text.replaceAll(',', '.'));
      final date = _dateController.text.trim();

      widget.onSave(desc, amount, _selectedCategoryId, _paymentMethod, date);
      Navigator.pop(context);
    }
  }

  void _showQuickAddCategory() {
    final nameController = TextEditingController();
    final catFormKey = GlobalKey<FormState>();

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        scrollable: true,
        title: const Text('Nueva Categoría Offline'),
        content: Form(
          key: catFormKey,
          child: TextFormField(
            controller: nameController,
            autofocus: true,
            decoration: const InputDecoration(
              labelText: 'Nombre de la Categoría *',
              border: OutlineInputBorder(),
            ),
            validator: (val) => val == null || val.trim().isEmpty ? 'Ingrese un nombre' : null,
          ),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancelar')),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red, foregroundColor: Colors.white),
            onPressed: () async {
              if (catFormKey.currentState?.validate() ?? false) {
                final repo = ref.read(expensesRepositoryProvider);
                final newCat = await repo.createCategory(name: nameController.text.trim());
                setState(() {
                  _selectedCategoryId = newCat.id;
                });
                if (ctx.mounted) Navigator.pop(ctx);
              }
            },
            child: const Text('CREAR'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final isEditing = widget.expense != null;
    final liveCategories = ref.watch(expenseCategoriesStreamProvider).asData?.value ?? widget.categories;

    return AlertDialog(
      scrollable: true,
      title: Text(isEditing ? 'Editar Gasto' : 'Nuevo Gasto Offline'),
      content: Form(
        key: _formKey,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextFormField(
              controller: _descController,
              maxLength: 500,
              decoration: const InputDecoration(
                labelText: 'Descripción del Gasto *',
                border: OutlineInputBorder(),
              ),
              validator: (val) {
                if (val == null || val.trim().isEmpty) return 'Ingrese una descripción';
                if (val.trim().length > 500) return 'Máximo 500 caracteres';
                return null;
              },
            ),
            const SizedBox(height: 12),
            TextFormField(
              controller: _amountController,
              keyboardType: const TextInputType.numberWithOptions(decimal: true),
              decoration: const InputDecoration(
                labelText: 'Monto (BOB) *',
                border: OutlineInputBorder(),
                prefixText: 'Bs ',
              ),
              validator: (val) {
                if (val == null || val.trim().isEmpty) return 'Ingrese un monto';
                final parsed = double.tryParse(val.trim().replaceAll(',', '.'));
                if (parsed == null || parsed <= 0) return 'Monto debe ser mayor a 0';
                return null;
              },
            ),
            const SizedBox(height: 12),
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: DropdownButtonFormField<String>(
                    isExpanded: true,
                    menuMaxHeight: 250,
                    initialValue: liveCategories.any((c) => c.id == _selectedCategoryId)
                        ? _selectedCategoryId
                        : (liveCategories.isNotEmpty ? liveCategories.first.id : null),
                    decoration: const InputDecoration(
                      labelText: 'Categoría *',
                      border: OutlineInputBorder(),
                      contentPadding: EdgeInsets.symmetric(horizontal: 10, vertical: 12),
                    ),
                    items: liveCategories.map((cat) {
                      return DropdownMenuItem(value: cat.id, child: Text(cat.name, overflow: TextOverflow.ellipsis));
                    }).toList(),
                    onChanged: (val) {
                      if (val != null) setState(() => _selectedCategoryId = val);
                    },
                    validator: (val) => val == null || val.isEmpty ? 'Seleccione una categoría' : null,
                  ),
                ),
                const SizedBox(width: 8),
                IconButton(
                  icon: const Icon(Icons.add_circle, color: Colors.red),
                  tooltip: 'Crear categoría rápida',
                  onPressed: _showQuickAddCategory,
                ),
              ],
            ),
            const SizedBox(height: 12),
            DropdownButtonFormField<String>(
              isExpanded: true,
              menuMaxHeight: 250,
              initialValue: _paymentMethod,
              decoration: const InputDecoration(
                labelText: 'Método de Pago',
                border: OutlineInputBorder(),
                contentPadding: EdgeInsets.symmetric(horizontal: 10, vertical: 12),
              ),
              items: const [
                DropdownMenuItem(value: 'CASH', child: Text('Efectivo')),
                DropdownMenuItem(value: 'QR', child: Text('QR')),
                DropdownMenuItem(value: 'OTHER', child: Text('Otro')),
              ],
              onChanged: (val) {
                if (val != null) setState(() => _paymentMethod = val);
              },
            ),
            const SizedBox(height: 12),
            TextFormField(
              controller: _dateController,
              decoration: const InputDecoration(
                labelText: 'Fecha (YYYY-MM-DD)',
                border: OutlineInputBorder(),
                prefixIcon: Icon(Icons.calendar_today),
              ),
              validator: (val) {
                if (val == null || !RegExp(r'^\d{4}-\d{2}-\d{2}$').hasMatch(val.trim())) {
                  return 'Formato inválido (debe ser YYYY-MM-DD)';
                }
                return null;
              },
            ),
          ],
        ),
      ),
      actions: [
        TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancelar')),
        ElevatedButton(
          style: ElevatedButton.styleFrom(backgroundColor: Colors.red, foregroundColor: Colors.white),
          onPressed: _submit,
          child: Text(isEditing ? 'GUARDAR' : 'REGISTRAR GASTO'),
        ),
      ],
    );
  }
}
