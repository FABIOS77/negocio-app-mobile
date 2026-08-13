import 'package:flutter/material.dart';
import '../../../core/utils/timezone_utils.dart';
import '../domain/expense_category_model.dart';
import '../domain/expense_model.dart';

class ExpenseDetailDialog extends StatefulWidget {
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
  State<ExpenseDetailDialog> createState() => _ExpenseDetailDialogState();
}

class _ExpenseDetailDialogState extends State<ExpenseDetailDialog> {
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
      final amount = double.parse(_amountController.text);
      final date = _dateController.text.trim();

      widget.onSave(desc, amount, _selectedCategoryId, _paymentMethod, date);
      Navigator.pop(context);
    }
  }

  @override
  Widget build(BuildContext context) {
    final isEditing = widget.expense != null;

    return AlertDialog(
      title: Text(isEditing ? 'Editar Gasto' : 'Nuevo Gasto Offline'),
      content: SingleChildScrollView(
        child: Form(
          key: _formKey,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextFormField(
                controller: _descController,
                decoration: const InputDecoration(labelText: 'Descripción del Gasto *', border: OutlineInputBorder()),
                validator: (val) => val == null || val.trim().isEmpty ? 'Ingrese una descripción' : null,
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: _amountController,
                keyboardType: const TextInputType.numberWithOptions(decimal: true),
                decoration: const InputDecoration(labelText: 'Monto (BOB) *', border: OutlineInputBorder(), prefixText: 'Bs '),
                validator: (val) {
                  if (val == null || val.trim().isEmpty) return 'Ingrese un monto';
                  final parsed = double.tryParse(val);
                  if (parsed == null || parsed <= 0) return 'Monto debe ser mayor a 0';
                  return null;
                },
              ),
              const SizedBox(height: 12),
              DropdownButtonFormField<String>(
                initialValue: _selectedCategoryId.isNotEmpty ? _selectedCategoryId : null,
                decoration: const InputDecoration(labelText: 'Categoría *', border: OutlineInputBorder()),
                items: widget.categories.map((cat) {
                  return DropdownMenuItem(value: cat.id, child: Text(cat.name));
                }).toList(),
                onChanged: (val) {
                  if (val != null) setState(() => _selectedCategoryId = val);
                },
                validator: (val) => val == null || val.isEmpty ? 'Seleccione una categoría' : null,
              ),
              const SizedBox(height: 12),
              DropdownButtonFormField<String>(
                initialValue: _paymentMethod,
                decoration: const InputDecoration(labelText: 'Método de Pago', border: OutlineInputBorder()),
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
                decoration: const InputDecoration(labelText: 'Fecha (YYYY-MM-DD)', border: OutlineInputBorder(), prefixIcon: Icon(Icons.calendar_today)),
              ),
            ],
          ),
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
