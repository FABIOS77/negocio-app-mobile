import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/database/app_database.dart';
import '../../../core/sync/sync_engine.dart';

final syncQueueStreamProvider = StreamProvider<List<SyncQueueTableData>>((ref) {
  final db = ref.watch(databaseProvider);
  return db.select(db.syncQueueTable).watch();
});

class SyncStatusScreen extends ConsumerWidget {
  const SyncStatusScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final queueAsync = ref.watch(syncQueueStreamProvider);

    return Scaffold(
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text('Cola de Sincronización Local', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                ElevatedButton.icon(
                  icon: const Icon(Icons.sync),
                  label: const Text('FORZAR SYNC'),
                  onPressed: () async {
                    final res = await ref.read(syncEngineProvider).syncAll();
                    if (context.mounted) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(content: Text(res.message ?? 'Sync: ${res.pushedCount} enviados, ${res.pulledCount} recibidos.')),
                      );
                    }
                  },
                ),
              ],
            ),
            const SizedBox(height: 16),
            Expanded(
              child: queueAsync.when(
                data: (queueItems) {
                  if (queueItems.isEmpty) {
                    return const Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(Icons.check_circle_outline, size: 64, color: Colors.green),
                          SizedBox(height: 12),
                          Text('¡Todo sincronizado con el servidor!', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                          Text('No hay operaciones pendientes en la cola local.', style: TextStyle(color: Colors.grey)),
                        ],
                      ),
                    );
                  }
                  return ListView.builder(
                    itemCount: queueItems.length,
                    itemBuilder: (context, index) {
                      final item = queueItems[index];
                      Color statusColor = Colors.orange;
                      if (item.status == 'SYNCED') statusColor = Colors.green;
                      if (item.status == 'FAILED') statusColor = Colors.red;
                      if (item.status == 'CONFLICT') statusColor = Colors.purple;

                      return Card(
                        child: ListTile(
                          leading: CircleAvatar(
                            backgroundColor: statusColor.withValues(alpha: 0.2),
                            child: Icon(Icons.sync_problem, color: statusColor),
                          ),
                          title: Text('${item.operation} -> ${item.entityType.toUpperCase()}', style: const TextStyle(fontWeight: FontWeight.bold)),
                          subtitle: Text('ID: ${item.entityId}\nEstado: ${item.status} • Reintentos: ${item.retryCount}\nError: ${item.lastError ?? "Ninguno"}'),
                          isThreeLine: true,
                        ),
                      );
                    },
                  );
                },
                loading: () => const Center(child: CircularProgressIndicator()),
                error: (err, _) => Center(child: Text('Error: $err')),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
