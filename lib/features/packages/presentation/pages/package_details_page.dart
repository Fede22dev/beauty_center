import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:material_symbols_icons/symbols.dart';

import '../../providers/packages_providers.dart';

class PackageDetailsPage extends ConsumerWidget {
  const PackageDetailsPage({
    required this.packageId,
    this.isOffline = false,
    super.key,
  });

  final String packageId;
  final bool isOffline;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final packageAsync = ref.watch(packageStreamProvider(packageId));
    final itemsAsync = ref.watch(packageItemsStreamProvider(packageId));
    final colorScheme = Theme.of(context).colorScheme;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Dettagli Pacchetto'),
        centerTitle: true,
      ),
      body: packageAsync.when(
        data: (package) {
          if (package == null) {
            return const Center(
              child: Text('Pacchetto non trovato'),
            );
          }

          return SingleChildScrollView(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Header Card
                Card(
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Icon(
                              Symbols.inventory_2_rounded,
                              color: colorScheme.primary,
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Text(
                                package.name,
                                style: Theme.of(context).textTheme.headlineSmall,
                              ),
                            ),
                            _StatusChip(status: package.status),
                          ],
                        ),
                        const SizedBox(height: 16),
                        _InfoRow(
                          icon: Symbols.payments_rounded,
                          label: 'Prezzo Totale',
                          value: '€${package.totalPrice.toStringAsFixed(2)}',
                        ),
                        if (package.expiresAt != null)
                          _InfoRow(
                            icon: Symbols.event_rounded,
                            label: 'Scadenza',
                            value: DateFormat('dd/MM/yyyy').format(package.expiresAt!),
                            valueColor: package.expiresAt!.isBefore(DateTime.now())
                                ? colorScheme.error
                                : null,
                          ),
                        if (package.notes?.isNotEmpty == true)
                          _InfoRow(
                            icon: Symbols.notes_rounded,
                            label: 'Note',
                            value: package.notes!,
                          ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 24),
                // Items Section
                Text(
                  'Servizi Inclusi',
                  style: Theme.of(context).textTheme.titleLarge?.copyWith(
                        fontWeight: FontWeight.bold,
                      ),
                ),
                const SizedBox(height: 12),
                itemsAsync.when(
                  data: (items) {
                    if (items.isEmpty) {
                      return const Card(
                        child: Padding(
                          padding: EdgeInsets.all(24),
                          child: Center(
                            child: Text('Nessun servizio incluso'),
                          ),
                        ),
                      );
                    }

                    return Column(
                      children: items.map((item) {
                        final progress = item.totalSessions > 0
                            ? item.usedSessions / item.totalSessions
                            : 0.0;

                        return Card(
                          margin: const EdgeInsets.only(bottom: 8),
                          child: Padding(
                            padding: const EdgeInsets.all(16),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  item.lockedServiceName,
                                  style: const TextStyle(
                                    fontWeight: FontWeight.bold,
                                    fontSize: 16,
                                  ),
                                ),
                                const SizedBox(height: 8),
                                LinearProgressIndicator(
                                  value: progress,
                                  backgroundColor:
                                      colorScheme.surfaceContainerHighest,
                                ),
                                const SizedBox(height: 8),
                                Row(
                                  mainAxisAlignment:
                                      MainAxisAlignment.spaceBetween,
                                  children: [
                                    Text(
                                      '${item.usedSessions} / ${item.totalSessions} sedute usate',
                                    ),
                                    Text(
                                      '${(progress * 100).toStringAsFixed(0)}%',
                                      style: TextStyle(
                                        color: colorScheme.primary,
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),
                                  ],
                                ),
                                Builder(
                                  builder: (context) {
                                    final remainingSessions = item.totalSessions - item.usedSessions;
                                    if (remainingSessions > 0) {
                                      return Text(
                                        '$remainingSessions sedute rimanenti',
                                        style: TextStyle(
                                          color: colorScheme.primary,
                                          fontSize: 12,
                                        ),
                                      );
                                    }
                                    return const SizedBox.shrink();
                                  },
                                ),
                              ],
                            ),
                          ),
                        );
                      }).toList(),
                    );
                  },
                  loading: () => const Center(
                    child: CircularProgressIndicator(),
                  ),
                  error: (error, _) => Center(
                    child: Text('Errore: $error'),
                  ),
                ),
              ],
            ),
          );
        },
        loading: () => const Center(
          child: CircularProgressIndicator(),
        ),
        error: (error, _) => Center(
          child: Text('Errore: $error'),
        ),
      ),
    );
  }
}

class _StatusChip extends StatelessWidget {
  const _StatusChip({required this.status});

  final String status;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    Color backgroundColor;
    Color foregroundColor;
    String label;

    switch (status) {
      case 'active':
        backgroundColor = colorScheme.primaryContainer;
        foregroundColor = colorScheme.onPrimaryContainer;
        label = 'Attivo';
        break;
      case 'completed':
        backgroundColor = colorScheme.tertiaryContainer;
        foregroundColor = colorScheme.onTertiaryContainer;
        label = 'Completato';
        break;
      case 'expired':
        backgroundColor = colorScheme.errorContainer;
        foregroundColor = colorScheme.onErrorContainer;
        label = 'Scaduto';
        break;
      default:
        backgroundColor = colorScheme.surfaceContainerHighest;
        foregroundColor = colorScheme.onSurfaceVariant;
        label = status;
    }

    return Chip(
      label: Text(label),
      backgroundColor: backgroundColor,
      labelStyle: TextStyle(
        color: foregroundColor,
        fontSize: 12,
        fontWeight: FontWeight.bold,
      ),
      padding: EdgeInsets.zero,
    );
  }
}

class _InfoRow extends StatelessWidget {
  const _InfoRow({
    required this.icon,
    required this.label,
    required this.value,
    this.valueColor,
  });

  final IconData icon;
  final String label;
  final String value;
  final Color? valueColor;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        children: [
          Icon(icon, size: 20, color: Theme.of(context).colorScheme.outline),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              label,
              style: TextStyle(
                color: Theme.of(context).colorScheme.onSurfaceVariant,
              ),
            ),
          ),
          Text(
            value,
            style: TextStyle(
              fontWeight: FontWeight.bold,
              color: valueColor,
            ),
          ),
        ],
      ),
    );
  }
}
