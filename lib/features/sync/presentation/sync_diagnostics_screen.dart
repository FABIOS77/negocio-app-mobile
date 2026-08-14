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
                final failedOrConflictOps = [
                  ...summary.failedOperations,
                  ...summary.conflicts,
                ];

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
                    const SizedBox(height: 12),
                    OutlinedButton.icon(
                      key: const Key('clear_sync_queue_button'),
                      style: OutlinedButton.styleFrom(
                        foregroundColor: Colors.deepOrange.shade800,
                        side: BorderSide(color: Colors.deepOrange.shade800),
                        minimumSize: const Size(double.infinity, 48),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      ),
                      icon: const Icon(Icons.delete_sweep),
                      label: const Text('VACIAR COLA DE SINCRONIZACIÓN (FORZAR LIMPIEZA)', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
                      onPressed: () async {
                        final confirm = await ConfirmDialog.show(
                          context,
                          title: 'Vaciar Cola de Sincronización',
                          content: '¿Está seguro de vaciar la cola de sincronización? Esto desatascará los intentos fallidos acumulados. Los datos reales en SQLite NO se eliminarán.',
                          confirmLabel: 'SÍ, VACIAR COLA',
                          confirmColor: Colors.red,
                        );

                        if (confirm) {
                          final count = await repository.clearSyncQueue();
                          if (context.mounted) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(
                                content: Text('Cola de sincronización vaciada. $count operaciones removidas.'),
                                backgroundColor: Colors.green,
                              ),
                            );
                          }
                        }
                      },
                    ),
                    if (isDevMode) ...[
                      const SizedBox(height: 12),
                      ElevatedButton.icon(
                        key: const Key('retry_failed_button'),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.amber.shade800,
                          foregroundColor: Colors.white,
                          minimumSize: const Size(double.infinity, 48),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                        ),
                        icon: const Icon(Icons.replay),
                        label: const Text('REINTENTAR OPERACIONES FALLIDAS', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
                        onPressed: () async {
                          final count = await repository.retryFailedOperations();
                          if (context.mounted) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(content: Text('$count operaciones rescatadas. Reintentando sincronización...')),
                            );
                          }
                          final result = await syncEngine.syncAll();
                          if (context.mounted) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(
                                content: Text(
                                  result.message ??
                                      'Reintento completado: ${result.pushedCount} enviados, ${result.pulledCount} recibidos.',
                                ),
                              ),
                            );
                          }
                        },
                      ),
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
                    const Text('Registro de Errores y Excepciones PUSH', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                    const SizedBox(height: 8),
                    if (failedOrConflictOps.isEmpty)
                      const Card(
                        child: Padding(
                          padding: EdgeInsets.all(16.0),
                          child: Center(
                            child: Text(
                              'No hay errores ni conflictos registrados en la cola.',
                              style: TextStyle(color: Colors.grey),
                            ),
                          ),
                        ),
                      )
                    else
                      ListView.builder(
                        shrinkWrap: true,
                        physics: const NeverScrollableScrollPhysics(),
                        itemCount: failedOrConflictOps.length,
                        itemBuilder: (context, index) {
                          final op = failedOrConflictOps[index];
                          final isFailed = op.status == 'FAILED';

                          return Card(
                            color: isFailed ? Colors.red.shade50 : Colors.amber.shade50,
                            elevation: 2,
                            margin: const EdgeInsets.only(bottom: 8),
                            child: Padding(
                              padding: const EdgeInsets.all(12.0),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Row(
                                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                    children: [
                                      Row(
                                        children: [
                                          Icon(
                                            isFailed ? Icons.error_outline : Icons.warning_amber_rounded,
                                            color: isFailed ? Colors.red : Colors.amber.shade900,
                                          ),
                                          const SizedBox(width: 8),
                                          Text(
                                            '${op.entityType.toUpperCase()} (${op.operation})',
                                            style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
                                          ),
                                        ],
                                      ),
                                      Container(
                                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                                        decoration: BoxDecoration(
                                          color: isFailed ? Colors.red : Colors.amber.shade800,
                                          borderRadius: BorderRadius.circular(8),
                                        ),
                                        child: Text(
                                          op.status,
                                          style: const TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.bold),
                                        ),
                                      ),
                                    ],
                                  ),
                                  const SizedBox(height: 6),
                                  Text(
                                    'ID Entidad: ${op.entityId}',
                                    style: const TextStyle(fontSize: 12, color: Colors.grey),
                                  ),
                                  if (op.lastError != null && op.lastError!.isNotEmpty) ...[
                                    const SizedBox(height: 6),
                                    Container(
                                      width: double.infinity,
                                      padding: const EdgeInsets.all(8),
                                      decoration: BoxDecoration(
                                        color: Colors.white,
                                        borderRadius: BorderRadius.circular(6),
                                        border: Border.all(color: isFailed ? Colors.red.shade200 : Colors.amber.shade300),
                                      ),
                                      child: SelectableText(
                                        'Error: ${op.lastError}',
                                        style: TextStyle(
                                          fontSize: 12,
                                          fontFamily: 'monospace',
                                          color: isFailed ? Colors.red.shade900 : Colors.amber.shade900,
                                        ),
                                      ),
                                    ),
                                  ],
                                  const SizedBox(height: 4),
                                  Text(
                                    'Intentos: ${op.retryCount} • Fecha: ${op.clientTimestamp.toLocal()}',
                                    style: const TextStyle(fontSize: 11, color: Colors.grey),
                                  ),
                                ],
                              ),
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
