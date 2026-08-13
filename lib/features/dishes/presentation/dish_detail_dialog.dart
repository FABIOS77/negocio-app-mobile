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

    _imageUrlController.addListener(() {
      setState(() {});
    });
  }

  @override
  void dispose() {
    _nameController.dispose();
    _descController.dispose();
    _priceController.dispose();
    _imageUrlController.dispose();
    super.dispose();
  }

  bool _isValidImageUrl(String url) {
    if (url.trim().isEmpty) return false;
    final uri = Uri.tryParse(url.trim());
    return uri != null && uri.hasAbsolutePath && (uri.scheme == 'http' || uri.scheme == 'https');
  }

  void _submit() {
    if (_formKey.currentState?.validate() ?? false) {
      final name = _nameController.text.trim();
      final desc = _descController.text.trim().isEmpty ? null : _descController.text.trim();
      final price = double.parse(_priceController.text.trim().replaceAll(',', '.'));
      final imageUrl = _imageUrlController.text.trim().isEmpty ? null : _imageUrlController.text.trim();

      widget.onSave(name, desc, price, imageUrl);
      Navigator.pop(context);
    }
  }

  @override
  Widget build(BuildContext context) {
    final isEditing = widget.dish != null;
    final currentUrl = _imageUrlController.text.trim();
    final hasValidUrl = _isValidImageUrl(currentUrl);

    return AlertDialog(
      title: Text(isEditing ? 'Editar Plato' : 'Nuevo Plato Offline'),
      content: SingleChildScrollView(
        child: Form(
          key: _formKey,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              TextFormField(
                key: const Key('dishNameField'),
                controller: _nameController,
                decoration: const InputDecoration(
                  labelText: 'Nombre del Plato *',
                  border: OutlineInputBorder(),
                ),
                validator: (val) {
                  if (val == null || val.trim().isEmpty) {
                    return 'El nombre del plato es obligatorio';
                  }
                  if (val.trim().length > 200) {
                    return 'El nombre no puede exceder 200 caracteres';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 12),
              TextFormField(
                key: const Key('dishDescriptionField'),
                controller: _descController,
                decoration: const InputDecoration(
                  labelText: 'Descripción (Opcional)',
                  border: OutlineInputBorder(),
                ),
                maxLines: 2,
                validator: (val) {
                  if (val != null && val.trim().length > 2000) {
                    return 'La descripción no puede exceder 2000 caracteres';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 12),
              TextFormField(
                key: const Key('dishPriceField'),
                controller: _priceController,
                keyboardType: const TextInputType.numberWithOptions(decimal: true),
                decoration: const InputDecoration(
                  labelText: 'Precio (BOB) *',
                  border: OutlineInputBorder(),
                  prefixText: 'Bs ',
                ),
                validator: (val) {
                  if (val == null || val.trim().isEmpty) {
                    return 'El precio es obligatorio';
                  }
                  final parsed = double.tryParse(val.trim().replaceAll(',', '.'));
                  if (parsed == null) {
                    return 'Ingrese un precio numérico válido';
                  }
                  if (parsed <= 0) {
                    return 'El precio debe ser estrictamente mayor a 0';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 12),
              TextFormField(
                key: const Key('dishImageUrlField'),
                controller: _imageUrlController,
                keyboardType: TextInputType.url,
                decoration: const InputDecoration(
                  labelText: 'URL de Imagen (http/https)',
                  border: OutlineInputBorder(),
                  hintText: 'https://ejemplo.com/imagen.jpg',
                ),
                validator: (val) {
                  if (val != null && val.trim().isNotEmpty) {
                    final trimmed = val.trim();
                    if (trimmed.length > 500) {
                      return 'La URL no puede exceder 500 caracteres';
                    }
                    final uri = Uri.tryParse(trimmed);
                    if (uri == null || !uri.hasAbsolutePath || (uri.scheme != 'http' && uri.scheme != 'https')) {
                      return 'URL inválida. Debe comenzar con http:// o https://';
                    }
                  }
                  return null;
                },
              ),
              if (hasValidUrl) ...[
                const SizedBox(height: 12),
                Center(
                  child: Column(
                    children: [
                      const Text(
                        'Vista previa de imagen:',
                        style: TextStyle(fontSize: 12, color: Colors.grey),
                      ),
                      const SizedBox(height: 4),
                      ClipRRect(
                        borderRadius: BorderRadius.circular(8),
                        child: Image.network(
                          currentUrl,
                          height: 80,
                          width: 80,
                          fit: BoxFit.cover,
                          errorBuilder: (context, error, stackTrace) {
                            return Container(
                              height: 80,
                              width: 80,
                              color: Colors.grey.shade200,
                              child: const Column(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  Icon(Icons.broken_image, color: Colors.grey),
                                  Text('Sin imagen', style: TextStyle(fontSize: 10, color: Colors.grey)),
                                ],
                              ),
                            );
                          },
                        ),
                      ),
                    ],
                  ),
                ),
              ],
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
          style: ElevatedButton.styleFrom(
            backgroundColor: Colors.deepOrange,
            foregroundColor: Colors.white,
          ),
          onPressed: _submit,
          child: Text(isEditing ? 'GUARDAR' : 'CREAR PLATO'),
        ),
      ],
    );
  }
}
