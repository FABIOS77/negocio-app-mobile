import 'package:flutter/material.dart';

class SyncStatusBannerWidget extends StatelessWidget {
  final int pendingCount;
  final VoidCallback? onSyncTap;

  const SyncStatusBannerWidget({
    super.key,
    required this.pendingCount,
    this.onSyncTap,
  });

  @override
  Widget build(BuildContext context) {
    final isSynced = pendingCount == 0;

    return InkWell(
      onTap: onSyncTap,
      borderRadius: BorderRadius.circular(20),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        decoration: BoxDecoration(
          color: isSynced ? Colors.green.shade100 : Colors.orange.shade100,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: isSynced ? Colors.green : Colors.orange,
            width: 1,
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              isSynced ? Icons.cloud_done : Icons.cloud_upload,
              size: 16,
              color: isSynced ? Colors.green.shade800 : Colors.orange.shade800,
            ),
            const SizedBox(width: 6),
            Text(
              isSynced ? 'Sincronizado' : 'Pendientes ($pendingCount)',
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.bold,
                color: isSynced ? Colors.green.shade800 : Colors.orange.shade800,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
