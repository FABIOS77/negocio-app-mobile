import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/config/env_config.dart';
import '../../../core/sync/sync_engine.dart';
import '../../common/presentation/widgets/confirm_dialog.dart';
import '../application/sync_diagnostics_notifier.dart';

class SyncDiagnosticsScreen extends ConsumerWidget {
  const SyncDiagnosticsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final diagnosticsAsync = ref.watch(syncDiagnosticsStreamProvider);
    final syncEngine = ref.read(syncEngineProvider);
    final repository = ref.read(syncDiagnosticsRepositoryProvider);
    final isDevMode = kDebugMode || EnvConfig.fromEnvironment().isDev;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Diagnóstico de Sincronización', style: TextStyle(fontWeight: FontWeight.bold)),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Card(
              color: Colors.green.shade50,
              elevation: 2,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              child: Padding(
                padding: const EdgeInsets.all(16.0),
                child: Row(
                  children: [
                    Icon(
                      Icons.wifi,
                      color: Colors.green.shade800,
                      size: 32,
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Motor Offline-First Activo',
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                              color: Colors.green.shade900,
                            ),
                          ),
                          const SizedBox(height: 4),
                          const Text(
                            'Los datos operan 100% en SQLite local y se sincronizan al reconectar.',
                            style: TextStyle(fontSize: 12, color: Colors.grey),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 16),
            diagnosticsAsync.when(
              data: (summary) {
                return Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Card(
                      elevation: 2,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      child: Padding(
                        padding: const EdgeInsets.all(16.0),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text('Estado de la Cola de Sincronización', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                            const SizedBox(height: 12),
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceAround,
                              children: [
                                _buildBadgeCol('NUEVOS (CREATE)', '${summary.pendingCreateCount}', Colors.blue),
                                _buildBadgeCol('EDICIONES (UPDATE)', '${summary.pendingUpdateCount}', Colors.orange),
                                _buildBadgeCol('BAJAS (DELETE)', '${summary.pendingDeleteCount}', Colors.red),
                              ],
                            ),
                            const Divider(height: 24),
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                const Text('Último Cursor de Servidor:', style: TextStyle(color: Colors.grey, fontSize: 13)),
                                Text(
                                  summary.lastCursor,
                                  style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(height: 16),
                    ElevatedButton.icon(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.deepOrange,
                        foregroundColor: Colors.white,
                        minimumSize: const Size(double.infinity, 50),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      ),
                      icon: const Icon(Icons.sync),
                      label: const Text('FORZAR SINCRONIZACIÓN MANUAL', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
                      onPressed: () async {
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(content: Text('Sincronizando con el servidor...')),
                        );
                        final result = await syncEngine.syncAll();
                        if (context.mounted) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(
                              content: Text(
                                result.message ??
                                    'Sync completado: ${result.pushedCount} enviados, ${result.pulledCount} recibidos.',
                              ),
                            ),
                          );
                        }
                      },
                    ),
                    if (isDevMode) ...[
                      const SizedBox(height: 12),
                      OutlinedButton.icon(
                        style: OutlinedButton.styleFrom(
                          foregroundColor: Colors.red,
                          side: const BorderSide(color: Colors.red),
                          minimumSize: const Size(double.infinity, 48),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                        ),
                        icon: const Icon(Icons.cleaning_services),
                        label: const Text('LIMPIAR DATOS DE PRUEBA LOCALES (DEV ONLY)', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
                        onPressed: () async {
                          final confirm = await ConfirmDialog.show(
                            context,
                            title: 'Limpiar Datos de Prueba',
                            content: '¿Desea purgar pedidos de prueba y menús duplicados manteniendo su sesión activa y el catálogo de platos?',
                            confirmLabel: 'SÍ, PURGAR',
                            confirmColor: Colors.red,
                          );

                          if (confirm) {
                            await repository.purgeTestData();
                            if (context.mounted) {
                              ScaffoldMessenger.of(context).showSnackBar(
                                const SnackBar(
                                  content: Text('Base de datos local depurada exitosamente. Se conservó el menú actual.'),
                                  backgroundColor: Colors.green,
                                ),
                              );
                            }
                          }
                        },
                      ),
                    ],
                    const SizedBox(height: 20),
                    const Text('Registro de Conflictos y Excepciones', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                    const SizedBox(height: 8),
                    if (summary.conflicts.isEmpty)
                      const Card(
                        child: Padding(
                          padding: EdgeInsets.all(16.0),
                          child: Center(
                            child: Text(
                              'No hay conflictos detectados. Todos los datos están en orden.',
                              style: TextStyle(color: Colors.grey),
                            ),
                          ),
                        ),
                      )
                    else
                      ListView.builder(
                        shrinkWrap: true,
                        physics: const NeverScrollableScrollPhysics(),
                        itemCount: summary.conflicts.length,
                        itemBuilder: (context, index) {
                          final c = summary.conflicts[index];
                          return Card(
                            color: Colors.red.shade50,
                            child: ListTile(
                              leading: const Icon(Icons.warning, color: Colors.red),
                              title: Text('${c.entityType} (${c.operation})', style: const TextStyle(fontWeight: FontWeight.bold)),
                              subtitle: Text('Error: ${c.lastError ?? "Conflicto detectado"}\nIntentos: ${c.retryCount}'),
                            ),
                          );
                        },
                      ),
                  ],
                );
              },
              loading: () => const Center(child: CircularProgressIndicator()),
              error: (err, _) => Text('Error al cargar diagnóstico: $err'),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildBadgeCol(String label, String count, Color color) {
    return Column(
      children: [
        Text(label, style: const TextStyle(fontSize: 10, color: Colors.grey, fontWeight: FontWeight.bold)),
        const SizedBox(height: 4),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
          decoration: BoxDecoration(
            color: color.withAlpha(38),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Text(
            count,
            style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: color),
          ),
        ),
      ],
    );
  }
}
