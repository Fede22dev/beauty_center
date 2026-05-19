import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../connectivity/connectivity_providers.dart';
import '../sync/sync_queue_manager.dart';

/// Offline and sync status indicator
/// Shows at the top of the app when offline or sync operations pending
class OfflineSyncIndicator extends ConsumerWidget {
  const OfflineSyncIndicator({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final isOffline = ref.watch(isConnectionUnusableProvider);
    final syncStats = ref.watch(syncQueueStatsProvider);

    // Don't show anything if everything is normal
    if (!isOffline && !syncStats.showIndicator) {
      return const SizedBox.shrink();
    }

    final colorScheme = Theme.of(context).colorScheme;

    // Offline takes precedence
    if (isOffline) {
      return _buildOfflineBanner(colorScheme);
    }

    // Show sync status
    return _buildSyncBanner(context, colorScheme, syncStats);
  }

  Widget _buildOfflineBanner(ColorScheme colorScheme) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [Colors.orange.shade700, Colors.orange.shade600],
        ),
      ),
      child: SafeArea(
        bottom: false,
        child: Row(
          children: [
            const Icon(Icons.cloud_off, color: Colors.white, size: 18),
            const SizedBox(width: 8),
            const Expanded(
              child: Text(
                'Modalità offline - I dati verranno sincronizzati quando tornerai online',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 13,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ),
            _buildOfflineBadge(),
          ],
        ),
      ),
    );
  }

  Widget _buildOfflineBadge() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.2),
        borderRadius: BorderRadius.circular(12),
      ),
      child: const Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.schedule, color: Colors.white, size: 12),
          SizedBox(width: 4),
          Text(
            'OFFLINE',
            style: TextStyle(
              color: Colors.white,
              fontSize: 10,
              fontWeight: FontWeight.bold,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSyncBanner(
    BuildContext context,
    ColorScheme colorScheme,
    SyncQueueStats stats,
  ) {
    final hasErrors = stats.failedCount > 0;
    final primaryColor = hasErrors ? colorScheme.error : colorScheme.primary;

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      decoration: BoxDecoration(
        color: primaryColor.withValues(alpha: 0.1),
        border: Border(
          bottom: BorderSide(
            color: primaryColor.withValues(alpha: 0.3),
            width: 1,
          ),
        ),
      ),
      child: SafeArea(
        bottom: false,
        child: InkWell(
          onTap: () => _showSyncDetails(context),
          borderRadius: BorderRadius.circular(8),
          child: Padding(
            padding: const EdgeInsets.all(4),
            child: Row(
              children: [
                SizedBox(
                  width: 16,
                  height: 16,
                  child: hasErrors
                      ? Icon(Icons.error_outline, color: primaryColor, size: 16)
                      : CircularProgressIndicator(
                          strokeWidth: 2,
                          color: primaryColor,
                        ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    stats.statusText,
                    style: TextStyle(
                      color: primaryColor,
                      fontSize: 13,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ),
                if (hasErrors)
                  TextButton(
                    onPressed: () => _retryFailed(context),
                    style: TextButton.styleFrom(
                      foregroundColor: primaryColor,
                      padding: const EdgeInsets.symmetric(horizontal: 8),
                      minimumSize: const Size(0, 32),
                      tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                    ),
                    child: const Text('RIPROVA'),
                  ),
                const Icon(Icons.chevron_right, size: 18),
              ],
            ),
          ),
        ),
      ),
    );
  }

  void _showSyncDetails(BuildContext context) {
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => const SyncQueueBottomSheet(),
    );
  }

  void _retryFailed(BuildContext context) {
    // Trigger retry - this would be implemented in the sync manager
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Nuovo tentativo di sincronizzazione...'),
        duration: Duration(seconds: 2),
      ),
    );
  }
}

/// Bottom sheet showing sync queue details
class SyncQueueBottomSheet extends ConsumerWidget {
  const SyncQueueBottomSheet({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final queue = ref.watch(syncQueueProvider);
    final colorScheme = Theme.of(context).colorScheme;

    return Container(
      decoration: BoxDecoration(
        color: colorScheme.surface,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
      ),
      constraints: BoxConstraints(
        maxHeight: MediaQuery.of(context).size.height * 0.7,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Handle
          Container(
            margin: const EdgeInsets.only(top: 8),
            width: 40,
            height: 4,
            decoration: BoxDecoration(
              color: colorScheme.outline.withValues(alpha: 0.3),
              borderRadius: BorderRadius.circular(2),
            ),
          ),

          // Header
          Padding(
            padding: const EdgeInsets.all(16),
            child: Row(
              children: [
                Icon(Icons.sync, color: colorScheme.primary),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Coda di Sincronizzazione',
                        style: Theme.of(context).textTheme.titleMedium
                            ?.copyWith(fontWeight: FontWeight.bold),
                      ),
                      Text(
                        '${queue.operations.length} operazioni',
                        style: TextStyle(
                          color: colorScheme.onSurfaceVariant,
                          fontSize: 13,
                        ),
                      ),
                    ],
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.close),
                  onPressed: () => Navigator.pop(context),
                ),
              ],
            ),
          ),

          Divider(height: 1, color: colorScheme.outline.withValues(alpha: 0.2)),

          // Operations list
          Flexible(
            child: queue.operations.isEmpty
                ? _buildEmptyState(colorScheme)
                : ListView.builder(
                    itemCount: queue.operations.length,
                    itemBuilder: (context, index) {
                      final op = queue.operations[index];
                      return _OperationListTile(operation: op);
                    },
                  ),
          ),

          // Footer actions
          if (queue.failedCount > 0)
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                border: Border(
                  top: BorderSide(
                    color: colorScheme.outline.withValues(alpha: 0.2),
                  ),
                ),
              ),
              child: Row(
                children: [
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: () {
                        // Retry all failed
                      },
                      icon: const Icon(Icons.refresh),
                      label: Text('Riprova ${queue.failedCount} falliti'),
                    ),
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildEmptyState(ColorScheme colorScheme) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            Icons.cloud_done,
            size: 64,
            color: colorScheme.outline.withValues(alpha: 0.5),
          ),
          const SizedBox(height: 16),
          Text(
            'Tutto sincronizzato!',
            style: TextStyle(color: colorScheme.onSurfaceVariant, fontSize: 16),
          ),
        ],
      ),
    );
  }
}

class _OperationListTile extends StatelessWidget {
  final SyncOperation operation;

  const _OperationListTile({required this.operation});

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return ListTile(
      leading: Container(
        width: 40,
        height: 40,
        decoration: BoxDecoration(
          color: operation.statusColor(colorScheme).withValues(alpha: 0.1),
          shape: BoxShape.circle,
        ),
        child: Icon(
          operation.statusIcon,
          color: operation.statusColor(colorScheme),
          size: 20,
        ),
      ),
      title: Text(
        operation.displayName,
        style: const TextStyle(fontWeight: FontWeight.w500),
      ),
      subtitle: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            '${operation.entityType} • ${operation.statusText}',
            style: TextStyle(fontSize: 12, color: colorScheme.onSurfaceVariant),
          ),
          if (operation.errorMessage != null)
            Text(
              operation.errorMessage!,
              style: TextStyle(fontSize: 11, color: colorScheme.error),
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
            ),
        ],
      ),
      trailing: operation.status == SyncOperationStatus.failed
          ? IconButton(
              icon: const Icon(Icons.refresh),
              onPressed: () {
                // Retry this operation
              },
            )
          : Text(
              _formatTime(operation.createdAt),
              style: TextStyle(fontSize: 11, color: colorScheme.outline),
            ),
    );
  }

  String _formatTime(DateTime time) {
    final now = DateTime.now();
    final diff = now.difference(time);

    if (diff.inMinutes < 1) return 'Adesso';
    if (diff.inHours < 1) return '${diff.inMinutes}m fa';
    if (diff.inDays < 1) return '${diff.inHours}h fa';
    return '${diff.inDays}g fa';
  }
}

/// Compact sync indicator for app bars
class SyncStatusDot extends ConsumerWidget {
  const SyncStatusDot({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final isOffline = ref.watch(isConnectionUnusableProvider);
    final syncStats = ref.watch(syncQueueStatsProvider);

    if (!isOffline && !syncStats.showIndicator) {
      return const SizedBox.shrink();
    }

    final colorScheme = Theme.of(context).colorScheme;

    return Tooltip(
      message: isOffline
          ? 'Offline - Dati salvati localmente'
          : syncStats.statusText,
      child: Container(
        width: 8,
        height: 8,
        margin: const EdgeInsets.only(left: 8),
        decoration: BoxDecoration(
          color: isOffline
              ? Colors.orange
              : syncStats.failedCount > 0
              ? colorScheme.error
              : colorScheme.primary,
          shape: BoxShape.circle,
        ),
      ),
    );
  }
}
