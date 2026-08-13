import 'package:flutter/material.dart';
import '../domain/dish_model.dart';

class DishDetailDialog extends StatefulWidget {
  final DishModel? dish;
  final Function(String name, String? description, double price, String? imageUrl) onSave;

  const DishDetailDialog({
    super.key,
    this.dish,
    required this.onSave,
  });

  @override
  State<DishDetailDialog> createState() => _DishDetailDialogState();
}

class _DishDetailDialogState extends State<DishDetailDialog> {
  late TextEditingController _nameController;
  late TextEditingController _descController;
  late TextEditingController _priceController;
  late TextEditingController _imageUrlController;
  final _formKey = GlobalKey<FormState>();

  @override
  void initState() {
    super.initState();
    _nameController = TextEditingController(text: widget.dish?.name ?? '');
    _descController = TextEditingController(text: widget.dish?.description ?? '');
    _priceController = TextEditingController(text: widget.dish != null ? widget.dish!.price.toString() : '');
    _imageUrlController = TextEditingController(text: widget.dish?.imageUrl ?? '');
  }

  @override
  void dispose() {
    _nameController.dispose();
    _descController.dispose();
    _priceController.dispose();
    _imageUrlController.dispose();
    super.dispose();
  }

  void _submit() {
    if (_formKey.currentState?.validate() ?? false) {
      final name = _nameController.text.trim();
      final desc = _descController.text.trim().isEmpty ? null : _descController.text.trim();
      final price = double.parse(_priceController.text);
      final imageUrl = _imageUrlController.text.trim().isEmpty ? null : _imageUrlController.text.trim();

      widget.onSave(name, desc, price, imageUrl);
      Navigator.pop(context);
    }
  }

  @override
  Widget build(BuildContext context) {
    final isEditing = widget.dish != null;

    return AlertDialog(
      title: Text(isEditing ? 'Editar Plato' : 'Nuevo Plato Offline'),
      content: SingleChildScrollView(
        child: Form(
          key: _formKey,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextFormField(
                controller: _nameController,
                decoration: const InputDecoration(labelText: 'Nombre del Plato *', border: OutlineInputBorder()),
                validator: (val) => val == null || val.trim().isEmpty ? 'Ingrese un nombre' : null,
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: _descController,
                decoration: const InputDecoration(labelText: 'Descripción', border: OutlineInputBorder()),
                maxLines: 2,
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: _priceController,
                keyboardType: const TextInputType.numberWithOptions(decimal: true),
                decoration: const InputDecoration(labelText: 'Precio (BOB) *', border: OutlineInputBorder(), prefixText: 'Bs '),
                validator: (val) {
                  if (val == null || val.trim().isEmpty) return 'Ingrese un precio';
                  final parsed = double.tryParse(val);
                  if (parsed == null || parsed <= 0) return 'Precio debe ser mayor a 0';
                  return null;
                },
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: _imageUrlController,
                decoration: const InputDecoration(labelText: 'URL de Imagen (Opcional)', border: OutlineInputBorder()),
              ),
            ],
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Cancelar'),
        ),
        ElevatedButton(
          style: ElevatedButton.styleFrom(backgroundColor: Colors.deepOrange, foregroundColor: Colors.white),
          onPressed: _submit,
          child: Text(isEditing ? 'GUARDAR' : 'CREAR PLATO'),
        ),
      ],
    );
  }
}
