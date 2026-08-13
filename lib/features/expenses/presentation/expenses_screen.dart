import 'package:drift/drift.dart' hide Column;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:uuid/uuid.dart';
import '../../../core/database/app_database.dart';
import '../../../core/sync/sync_engine.dart';
import '../../../core/utils/timezone_utils.dart';

final expensesStreamProvider = StreamProvider<List<ExpensesTableData>>((ref) {
  final db = ref.watch(databaseProvider);
  return (db.select(db.expensesTable)
        ..orderBy([(t) => OrderingTerm(expression: t.createdAt, mode: OrderingMode.desc)]))
      .watch();
});

class ExpensesScreen extends ConsumerWidget {
  const ExpensesScreen({super.key});

  void _showNewExpenseDialog(BuildContext context, WidgetRef ref) {
    final descController = TextEditingController();
    final amountController = TextEditingController();
    String paymentMethod = 'CASH';
    final uuid = const Uuid();

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) {
        return StatefulBuilder(
          builder: (context, setState) {
            return Padding(
              padding: EdgeInsets.only(
                top: 20,
                left: 20,
                right: 20,
                bottom: MediaQuery.of(context).viewInsets.bottom + 20,
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('Registrar Gasto Offline', style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
                  const SizedBox(height: 16),
                  TextField(
                    controller: descController,
                    decoration: const InputDecoration(
                      labelText: 'Descripción del Gasto',
                      border: OutlineInputBorder(),
                      prefixIcon: Icon(Icons.description),
                    ),
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: amountController,
                    keyboardType: const TextInputType.numberWithOptions(decimal: true),
                    decoration: const InputDecoration(
                      labelText: 'Monto en BOB (Bs)',
                      border: OutlineInputBorder(),
                      prefixIcon: Icon(Icons.attach_money),
                    ),
                  ),
                  const SizedBox(height: 16),
                  SegmentedButton<String>(
                    segments: const [
                      ButtonSegment(value: 'CASH', label: Text('Efectivo')),
                      ButtonSegment(value: 'QR', label: Text('QR')),
                      ButtonSegment(value: 'OTHER', label: Text('Otro')),
                    ],
                    selected: {paymentMethod},
                    onSelectionChanged: (val) {
                      setState(() {
                        paymentMethod = val.first;
                      });
                    },
                  ),
                  const SizedBox(height: 24),
                  SizedBox(
                    width: double.infinity,
                    height: 50,
                    child: ElevatedButton.icon(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.amber.shade900,
                        foregroundColor: Colors.white,
                      ),
                      icon: const Icon(Icons.check),
                      label: const Text('GUARDAR GASTO', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                      onPressed: () async {
                        final desc = descController.text.trim();
                        final amount = double.tryParse(amountController.text) ?? 0.0;
                        if (desc.isEmpty || amount <= 0) return;

                        final expenseId = uuid.v4();
                        final db = ref.read(databaseProvider);
                        final queue = ref.read(syncQueueManagerProvider);
                        final now = DateTime.now().toUtc();
                        final expenseDate = TimezoneUtils.getTodayBusinessDate();

                        // 1. Guardar localmente en SQLite
                        await db.into(db.expensesTable).insert(
                              ExpensesTableCompanion.insert(
                                id: expenseId,
                                description: desc,
                                amount: amount,
                                categoryId: '00000000-0000-0000-0000-000000000000',
                                paymentMethod: paymentMethod,
                                expenseDate: expenseDate,
                                createdBy: 'local-user',
                                syncStatus: const Value('PENDING'),
                                createdAt: now,
                                updatedAt: now,
                              ),
                            );

                        // 2. Encolar mutación offline PUSH
                        await queue.enqueueOperation(
                          entityType: 'expense',
                          entityId: expenseId,
                          operation: 'CREATE',
                          payload: {
                            'id': expenseId,
                            'description': desc,
                            'amount': amount,
                            'category_id': '00000000-0000-0000-0000-000000000000',
                            'payment_method': paymentMethod,
                            'expense_date': expenseDate,
                          },
                        );

                        if (ctx.mounted) Navigator.pop(ctx);
                        ref.read(syncEngineProvider).syncAll();
                      },
                    ),
                  ),
                ],
              ),
            );
          },
        );
      },
    );
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final expensesAsync = ref.watch(expensesStreamProvider);

    return Scaffold(
      floatingActionButton: FloatingActionButton.extended(
        backgroundColor: Colors.amber.shade900,
        icon: const Icon(Icons.add, color: Colors.white),
        label: const Text('REGISTRAR GASTO', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
        onPressed: () => _showNewExpenseDialog(context, ref),
      ),
      body: expensesAsync.when(
        data: (expenses) {
          if (expenses.isEmpty) {
            return const Center(
              child: Text(
                'No hay gastos registrados localmente.\n¡Toca + REGISTRAR GASTO para guardar uno offline!',
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 16, color: Colors.grey),
              ),
            );
          }
          return ListView.builder(
            padding: const EdgeInsets.all(12),
            itemCount: expenses.length,
            itemBuilder: (context, index) {
              final exp = expenses[index];
              return Card(
                child: ListTile(
                  leading: const CircleAvatar(
                    backgroundColor: Colors.amber,
                    child: Icon(Icons.money_off, color: Colors.white),
                  ),
                  title: Text(exp.description, style: const TextStyle(fontWeight: FontWeight.bold)),
                  subtitle: Text('Fecha: ${exp.expenseDate} • Pago: ${exp.paymentMethod}\nSync: ${exp.syncStatus}'),
                  trailing: Text('Bs ${exp.amount.toStringAsFixed(2)}', style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.redAccent)),
                ),
              );
            },
          );
        },
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (err, _) => Center(child: Text('Error: $err')),
      ),
    );
  }
}
