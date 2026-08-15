import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../application/expenses_notifier.dart';
import '../../domain/expense_category_model.dart';

class ManageCategoriesDialog extends ConsumerWidget {
  const ManageCategoriesDialog({super.key});

  static Future<void> show(BuildContext context) {
    return showDialog(
      context: context,
      builder: (ctx) => const ManageCategoriesDialog(),
    );
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final categoriesAsync = ref.watch(allExpenseCategoriesStreamProvider);
    final repository = ref.read(expensesRepositoryProvider);

    return AlertDialog(
      title: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          const Text('Categorías de Gastos', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18)),
          IconButton(
            icon: const Icon(Icons.add_circle, color: Colors.red),
            tooltip: 'Nueva Categoría',
            onPressed: () => _showCategoryEditor(context, repository),
          ),
        ],
      ),
      content: SizedBox(
        width: double.maxFinite,
        child: categoriesAsync.when(
          data: (categories) {
            if (categories.isEmpty) {
              return const Padding(
                padding: EdgeInsets.all(24.0),
                child: Text('No hay categorías registradas. Presione + para crear una.', textAlign: TextAlign.center),
              );
            }

            return ListView.separated(
              shrinkWrap: true,
              itemCount: categories.length,
              separatorBuilder: (_, __) => const Divider(height: 1),
              itemBuilder: (context, index) {
                final cat = categories[index];
                return ListTile(
                  contentPadding: EdgeInsets.zero,
                  title: Text(
                    cat.name,
                    style: TextStyle(
                      fontWeight: FontWeight.w600,
                      decoration: cat.active ? null : TextDecoration.lineThrough,
                      color: cat.active ? null : Colors.grey,
                    ),
                  ),
                  subtitle: Text(
                    cat.active ? 'Activa' : 'Inactiva',
                    style: TextStyle(fontSize: 12, color: cat.active ? Colors.green : Colors.red),
                  ),
                  trailing: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      IconButton(
                        icon: const Icon(Icons.edit, size: 20, color: Colors.blue),
                        tooltip: 'Editar nombre',
                        onPressed: () => _showCategoryEditor(context, repository, category: cat),
                      ),
                      IconButton(
                        icon: Icon(cat.active ? Icons.visibility_off : Icons.visibility, size: 20, color: cat.active ? Colors.orange : Colors.green),
                        tooltip: cat.active ? 'Desactivar' : 'Activar',
                        onPressed: () async {
                          await repository.updateCategory(id: cat.id, active: !cat.active);
                        },
                      ),
                    ],
                  ),
                );
              },
            );
          },
          loading: () => const Center(child: CircularProgressIndicator()),
          error: (err, _) => Center(child: Text('Error: $err')),
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Cerrar'),
        ),
      ],
    );
  }

  void _showCategoryEditor(BuildContext context, dynamic repository, {ExpenseCategoryModel? category}) {
    final isEditing = category != null;
    final controller = TextEditingController(text: category?.name ?? '');
    final formKey = GlobalKey<FormState>();

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(isEditing ? 'Editar Categoría' : 'Nueva Categoría'),
        content: Form(
          key: formKey,
          child: TextFormField(
            controller: controller,
            decoration: const InputDecoration(
              labelText: 'Nombre de la Categoría *',
              border: OutlineInputBorder(),
            ),
            validator: (val) {
              if (val == null || val.trim().isEmpty) return 'El nombre es obligatorio';
              if (val.trim().length > 100) return 'Máximo 100 caracteres';
              return null;
            },
          ),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancelar')),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red, foregroundColor: Colors.white),
            onPressed: () async {
              if (formKey.currentState?.validate() ?? false) {
                final name = controller.text.trim();
                if (isEditing) {
                  await repository.updateCategory(id: category.id, name: name);
                } else {
                  await repository.createCategory(name: name);
                }
                if (ctx.mounted) Navigator.pop(ctx);
              }
            },
            child: Text(isEditing ? 'GUARDAR' : 'CREAR'),
          ),
        ],
      ),
    );
  }
}
