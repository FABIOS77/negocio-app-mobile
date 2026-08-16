import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/utils/currency_formatter.dart';
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

  // Desglose temporal en memoria
  List<double> _breakdownItems = [];

  @override
  void initState() {
    super.initState();
    _descController = TextEditingController(text: widget.expense?.description ?? '');
    _amountController = TextEditingController(text: widget.expense != null ? widget.expense!.amount.toStringAsFixed(2) : '');
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

  double get _breakdownTotal => _breakdownItems.fold(0.0, (sum, item) => sum + item);

  Future<void> _openBreakdownModal() async {
    final result = await showDialog<List<double>>(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => ExpenseBreakdownModal(initialItems: List<double>.from(_breakdownItems)),
    );

    if (result != null) {
      setState(() {
        _breakdownItems = result;
        if (_breakdownItems.isNotEmpty) {
          _amountController.text = _breakdownTotal.toStringAsFixed(2);
        }
      });
    }
  }

  void _clearBreakdown() {
    setState(() {
      _breakdownItems = [];
      _amountController.clear();
    });
  }

  void _submit() {
    if (_formKey.currentState?.validate() ?? false) {
      if (_selectedCategoryId.isEmpty) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Seleccione una categoría')));
        return;
      }

      final text = _amountController.text.trim().replaceAll(',', '.');
      final amount = double.tryParse(text) ?? 0.0;

      if (amount <= 0) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('El monto total debe ser mayor a 0')));
        return;
      }

      final desc = _descController.text.trim();
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
      builder: (ctx) => Dialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 400),
          child: Padding(
            padding: const EdgeInsets.all(20.0),
            child: Form(
              key: catFormKey,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('Nueva Categoría Offline', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                  const SizedBox(height: 16),
                  TextFormField(
                    controller: nameController,
                    autofocus: true,
                    decoration: const InputDecoration(
                      labelText: 'Nombre de la Categoría *',
                      border: OutlineInputBorder(),
                    ),
                    validator: (val) => val == null || val.trim().isEmpty ? 'Ingrese un nombre' : null,
                  ),
                  const SizedBox(height: 20),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.end,
                    children: [
                      TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancelar')),
                      const SizedBox(width: 8),
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
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final isEditing = widget.expense != null;
    final liveCategories = ref.watch(expenseCategoriesStreamProvider).asData?.value ?? widget.categories;
    final hasBreakdown = _breakdownItems.isNotEmpty;
    final mediaQuery = MediaQuery.of(context);

    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      insetPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 24),
      child: ConstrainedBox(
        constraints: BoxConstraints(
          maxWidth: 480,
          maxHeight: mediaQuery.size.height * 0.85,
        ),
        child: Padding(
          padding: const EdgeInsets.all(20.0),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Header
              Row(
                children: [
                  Expanded(
                    child: Text(
                      isEditing ? 'Editar Gasto' : 'Nuevo Gasto Offline',
                      style: const TextStyle(fontSize: 17, fontWeight: FontWeight.bold),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.close, size: 20),
                    visualDensity: VisualDensity.compact,
                    padding: EdgeInsets.zero,
                    constraints: const BoxConstraints(),
                    onPressed: () => Navigator.pop(context),
                  ),
                ],
              ),
              const Divider(),
              // Form Body Scrollable
              Flexible(
                child: SingleChildScrollView(
                  child: Form(
                    key: _formKey,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const SizedBox(height: 8),
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

                        // Fila de Monto + Botón de Desglose
                        Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Expanded(
                              flex: 3,
                              child: TextFormField(
                                controller: _amountController,
                                readOnly: hasBreakdown,
                                keyboardType: const TextInputType.numberWithOptions(decimal: true),
                                decoration: InputDecoration(
                                  labelText: hasBreakdown ? 'Monto Total Desglosado *' : 'Monto (BOB) *',
                                  border: const OutlineInputBorder(),
                                  prefixText: 'Bs ',
                                  fillColor: hasBreakdown ? Colors.red.shade50 : null,
                                  filled: hasBreakdown,
                                ),
                                validator: (val) {
                                  if (val == null || val.trim().isEmpty) return 'Ingrese un monto';
                                  final parsed = double.tryParse(val.trim().replaceAll(',', '.'));
                                  if (parsed == null || parsed <= 0) return 'Monto debe ser > 0';
                                  return null;
                                },
                              ),
                            ),
                            if (!isEditing) ...[
                              const SizedBox(width: 8),
                              Expanded(
                                flex: 2,
                                child: SizedBox(
                                  height: 56,
                                  child: OutlinedButton.icon(
                                    style: OutlinedButton.styleFrom(
                                      foregroundColor: Colors.red.shade700,
                                      side: BorderSide(color: Colors.red.shade300),
                                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                                    ),
                                    onPressed: _openBreakdownModal,
                                    icon: const Icon(Icons.calculate, size: 20),
                                    label: Text(hasBreakdown ? 'Editar' : 'Desglosar', style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold), overflow: TextOverflow.ellipsis),
                                  ),
                                ),
                              ),
                            ],
                          ],
                        ),

                        // Chip de estado de desglose activo
                        if (hasBreakdown) ...[
                          const SizedBox(height: 8),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                            decoration: BoxDecoration(
                              color: Colors.red.shade50,
                              borderRadius: BorderRadius.circular(8),
                              border: Border.all(color: Colors.red.shade200),
                            ),
                            child: Row(
                              children: [
                                const Icon(Icons.check_circle, color: Colors.red, size: 16),
                                const SizedBox(width: 6),
                                Expanded(
                                  child: Text(
                                    'Desglose: ${_breakdownItems.length} importes (Total: ${CurrencyFormatter.formatBOB(_breakdownTotal)})',
                                    style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: Colors.red),
                                  ),
                                ),
                                IconButton(
                                  icon: const Icon(Icons.clear, size: 16, color: Colors.red),
                                  tooltip: 'Quitar desglose',
                                  padding: EdgeInsets.zero,
                                  constraints: const BoxConstraints(),
                                  onPressed: _clearBreakdown,
                                ),
                              ],
                            ),
                          ),
                        ],
                        const SizedBox(height: 12),

                        // Selector de Categoría
                        Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Expanded(
                              child: Container(
                                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 2),
                                decoration: BoxDecoration(
                                  border: Border.all(color: Colors.grey.shade400),
                                  borderRadius: BorderRadius.circular(4),
                                ),
                                child: DropdownButtonHideUnderline(
                                  child: DropdownButton<String>(
                                    isExpanded: true,
                                    menuMaxHeight: 250,
                                    value: liveCategories.any((c) => c.id == _selectedCategoryId)
                                        ? _selectedCategoryId
                                        : (liveCategories.isNotEmpty ? liveCategories.first.id : null),
                                    hint: const Text('Categoría *'),
                                    items: liveCategories.map((cat) {
                                      return DropdownMenuItem(value: cat.id, child: Text(cat.name, overflow: TextOverflow.ellipsis));
                                    }).toList(),
                                    onChanged: (val) {
                                      if (val != null) setState(() => _selectedCategoryId = val);
                                    },
                                  ),
                                ),
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

                        // Selector de Método de Pago
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 2),
                          decoration: BoxDecoration(
                            border: Border.all(color: Colors.grey.shade400),
                            borderRadius: BorderRadius.circular(4),
                          ),
                          child: DropdownButtonHideUnderline(
                            child: DropdownButton<String>(
                              isExpanded: true,
                              menuMaxHeight: 250,
                              value: _paymentMethod,
                              items: const [
                                DropdownMenuItem(value: 'CASH', child: Text('Efectivo')),
                                DropdownMenuItem(value: 'QR', child: Text('QR')),
                                DropdownMenuItem(value: 'OTHER', child: Text('Otro')),
                              ],
                              onChanged: (val) {
                                if (val != null) setState(() => _paymentMethod = val);
                              },
                            ),
                          ),
                        ),
                        const SizedBox(height: 12),

                        // Selector de Fecha
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
                        const SizedBox(height: 8),
                      ],
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 16),
              // Action Buttons
              Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancelar')),
                  const SizedBox(width: 8),
                  ElevatedButton(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.red,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                    ),
                    onPressed: _submit,
                    child: Text(isEditing ? 'GUARDAR' : 'REGISTRAR GASTO', style: const TextStyle(fontWeight: FontWeight.bold)),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// MODAL ESPECIALIZADO Y ROBUSTO PARA EL DESGLOSE DE IMPORTES
// ─────────────────────────────────────────────────────────────────────────────
class ExpenseBreakdownModal extends StatefulWidget {
  final List<double> initialItems;

  const ExpenseBreakdownModal({super.key, required this.initialItems});

  @override
  State<ExpenseBreakdownModal> createState() => _ExpenseBreakdownModalState();
}

class _ExpenseBreakdownModalState extends State<ExpenseBreakdownModal> {
  late List<double> _items;
  final TextEditingController _inputController = TextEditingController();
  final FocusNode _inputFocus = FocusNode();
  int? _editingIndex;

  @override
  void initState() {
    super.initState();
    _items = List<double>.from(widget.initialItems);
  }

  @override
  void dispose() {
    _inputController.dispose();
    _inputFocus.dispose();
    super.dispose();
  }

  double get _total => _items.fold(0.0, (sum, val) => sum + val);

  void _addOrUpdateItem() {
    final text = _inputController.text.trim().replaceAll(',', '.');
    final val = double.tryParse(text);

    if (val == null || val <= 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Ingrese un importe numérico mayor a 0')),
      );
      return;
    }

    final rounded = double.parse(val.toStringAsFixed(2));

    setState(() {
      if (_editingIndex != null && _editingIndex! < _items.length) {
        _items[_editingIndex!] = rounded;
        _editingIndex = null;
      } else {
        _items.add(rounded);
      }
      _inputController.clear();
    });

    _inputFocus.requestFocus();
  }

  void _startEdit(int index) {
    setState(() {
      _editingIndex = index;
      _inputController.text = _items[index].toStringAsFixed(2);
    });
    _inputFocus.requestFocus();
  }

  void _removeItem(int index) {
    setState(() {
      if (_editingIndex == index) {
        _editingIndex = null;
        _inputController.clear();
      }
      _items.removeAt(index);
    });
  }

  @override
  Widget build(BuildContext context) {
    final mediaQuery = MediaQuery.of(context);

    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      insetPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 24),
      child: ConstrainedBox(
        constraints: BoxConstraints(
          maxWidth: 440,
          maxHeight: mediaQuery.size.height * 0.80,
        ),
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Header
              Row(
                children: [
                  const Icon(Icons.calculate, color: Colors.red, size: 22),
                  const SizedBox(width: 8),
                  const Expanded(
                    child: Text(
                      'Desglose de Importes',
                      style: TextStyle(fontSize: 17, fontWeight: FontWeight.bold),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.close, size: 20),
                    visualDensity: VisualDensity.compact,
                    padding: EdgeInsets.zero,
                    constraints: const BoxConstraints(),
                    onPressed: () => Navigator.pop(context),
                  ),
                ],
              ),
              const Divider(),
              const SizedBox(height: 8),

              // Fila de Entrada Rápida
              Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: _inputController,
                      focusNode: _inputFocus,
                      autofocus: true,
                      keyboardType: const TextInputType.numberWithOptions(decimal: true),
                      decoration: InputDecoration(
                        hintText: _editingIndex != null ? 'Editar importe...' : 'Ej. 45.50',
                        prefixText: 'Bs ',
                        isDense: true,
                        border: const OutlineInputBorder(),
                      ),
                      onSubmitted: (_) => _addOrUpdateItem(),
                    ),
                  ),
                  const SizedBox(width: 8),
                  ElevatedButton.icon(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.red,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                    ),
                    onPressed: _addOrUpdateItem,
                    icon: Icon(_editingIndex != null ? Icons.check : Icons.add, size: 18),
                    label: Text(_editingIndex != null ? 'Guardar' : 'Agregar'),
                  ),
                ],
              ),
              const SizedBox(height: 12),

              // Lista de Importes (ListView.builder en Expanded)
              Expanded(
                child: _items.isEmpty
                    ? Center(
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(Icons.format_list_numbered, size: 40, color: Colors.grey.shade300),
                            const SizedBox(height: 8),
                            Text(
                              'Agrega los importes de tus compras.\nSe sumarán automáticamente.',
                              textAlign: TextAlign.center,
                              style: TextStyle(color: Colors.grey.shade600, fontSize: 13),
                            ),
                          ],
                        ),
                      )
                    : Container(
                        decoration: BoxDecoration(
                          color: Colors.grey.shade50,
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(color: Colors.grey.shade300),
                        ),
                        child: ListView.separated(
                          itemCount: _items.length,
                          separatorBuilder: (_, __) => const Divider(height: 1),
                          itemBuilder: (ctx, idx) {
                            final val = _items[idx];
                            final isEditingThis = _editingIndex == idx;

                            return ListTile(
                              dense: true,
                              tileColor: isEditingThis ? Colors.red.shade50 : null,
                              leading: CircleAvatar(
                                radius: 12,
                                backgroundColor: isEditingThis ? Colors.red : Colors.grey.shade300,
                                child: Text(
                                  '${idx + 1}',
                                  style: TextStyle(
                                    fontSize: 11,
                                    fontWeight: FontWeight.bold,
                                    color: isEditingThis ? Colors.white : Colors.black87,
                                  ),
                                ),
                              ),
                              title: Text(
                                CurrencyFormatter.formatBOB(val),
                                style: TextStyle(
                                  fontWeight: FontWeight.w600,
                                  fontSize: 14,
                                  color: isEditingThis ? Colors.red : Colors.black87,
                                ),
                              ),
                              trailing: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  IconButton(
                                    icon: const Icon(Icons.edit, size: 18, color: Colors.blue),
                                    visualDensity: VisualDensity.compact,
                                    padding: const EdgeInsets.all(4),
                                    constraints: const BoxConstraints(),
                                    onPressed: () => _startEdit(idx),
                                  ),
                                  const SizedBox(width: 4),
                                  IconButton(
                                    icon: const Icon(Icons.delete_outline, size: 18, color: Colors.red),
                                    visualDensity: VisualDensity.compact,
                                    padding: const EdgeInsets.all(4),
                                    constraints: const BoxConstraints(),
                                    onPressed: () => _removeItem(idx),
                                  ),
                                ],
                              ),
                            );
                          },
                        ),
                      ),
              ),

              const SizedBox(height: 12),
              // Footer con Total Calculado
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.red.shade50,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: Colors.red.shade200),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Expanded(
                      child: Text(
                        'Total (${_items.length} ${(_items.length == 1) ? 'importe' : 'importes'}):',
                        style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    Text(
                      CurrencyFormatter.formatBOB(_total),
                      style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 18, color: Colors.red),
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 12),
              // Botones de Acción
              Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  TextButton(
                    onPressed: () => Navigator.pop(context),
                    child: const Text('Cancelar'),
                  ),
                  const SizedBox(width: 8),
                  ElevatedButton(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.red,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                    ),
                    onPressed: _items.isEmpty
                        ? null
                        : () {
                            Navigator.pop(context, _items);
                          },
                    child: const Text('APLICAR AL GASTO', style: TextStyle(fontWeight: FontWeight.bold)),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}
