import 'package:beauty_center/core/connectivity/connectivity_provider.dart';
import 'package:beauty_center/core/tabs/app_tabs.dart';
import 'package:beauty_center/core/widgets/custom_snackbar.dart';
import 'package:beauty_center/features/clients/presentation/providers/clients_providers.dart';
import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:intl/intl.dart';
import 'package:material_symbols_icons/symbols.dart';

import '../../../../core/constants/app_constants.dart';
import '../../../../core/logging/app_logger.dart';
import '../../../../core/providers/supabase_auth_provider.dart';
import '../../../../core/widgets/contact_actions_dialogs.dart';
import '../widgets/add_edit_client_dialog.dart';

const animationDelay = 50;

class ClientDetailsPage extends ConsumerStatefulWidget {
  const ClientDetailsPage({required this.clientId, super.key});

  final String clientId;

  @override
  ConsumerState<ClientDetailsPage> createState() => _ClientDetailPageState();
}

class _ClientDetailPageState extends ConsumerState<ClientDetailsPage> {
  static final log = AppLogger.getLogger(name: 'ClientDetailsPage');
  late ScrollController _scrollController;

  @override
  void initState() {
    super.initState();
    _scrollController = ScrollController();
  }

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  Future<void> _showDeleteDialog() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (final context) => AlertDialog(
        title: const Text('Elimina cliente'),
        content: const Text(
          'Sei sicuro di voler eliminare questo cliente? '
          'Questa azione non può essere annullata.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Annulla'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            style: FilledButton.styleFrom(
              backgroundColor: Theme.of(context).colorScheme.error,
            ),
            child: const Text('Elimina'),
          ),
        ],
      ),
    );

    if (confirmed != true || !mounted) return;

    try {
      await ref.read(clientsActionsProvider).deleteClient(widget.clientId);

      if (!mounted) return;

      Navigator.pop(context, true);
      showCustomSnackBar(
        context: context,
        message: 'Cliente eliminato con successo',
        okColor: AppTabs.clients.color,
      );
    } catch (e) {
      log.severe('Error deleting client', e);
      if (mounted) {
        showCustomSnackBar(
          context: context,
          message: "Errore durante l'eliminazione: $e",
          okColor: AppTabs.clients.color,
        );
      }
    }
  }

  Future<void> _editClient() async {
    log.fine('Edit client: ${widget.clientId}');

    final client = await ref
        .read(clientsActionsProvider)
        .getClientById(widget.clientId);
    if (client == null) {
      log.warning('Client ${widget.clientId} not found');
      return;
    }

    if (!mounted) return;

    final result = await showDialog<bool>(
      context: context,
      builder: (_) => AddEditClientDialog(client: client, mode: Mode.edit),
    );

    if (result == true) {
      log.fine('Client updated successfully');
    }
  }

  @override
  Widget build(final BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final isOffline = ref.watch(isConnectionUnusableProvider);
    final isDisconnectedSup = ref.watch(supabaseAuthProvider).isDisconnected;
    final clientAsync = ref.watch(clientStreamProvider(widget.clientId));

    // Handle loading/error gracefully in the Scaffold structure
    return Scaffold(
      appBar: AppBar(
        title: clientAsync.when(
          data: (final client) =>
              Text('${client?.firstName} ${client?.lastName}'),
          loading: () => const SizedBox.shrink(),
          error: (_, _) => const Text('Errore'),
        ),
        titleTextStyle: TextStyle(
          fontSize: kIsWindows ? 26 : 26.sp,
          fontWeight: FontWeight.bold,
          color: colorScheme.onSurface,
        ),
        centerTitle: false,
        actions: [
          if (clientAsync.hasValue && clientAsync.value != null)
            IconButton(
              icon: const Icon(Symbols.edit_rounded),
              color: colorScheme.onSurface,
              onPressed: (isOffline || isDisconnectedSup) ? null : _editClient,
              tooltip: 'Modifica',
            )
          else
            const SizedBox.shrink(),

          if (clientAsync.hasValue && clientAsync.value != null)
            IconButton(
              icon: const Icon(Symbols.delete_rounded),
              color: colorScheme.onSurface,
              onPressed: (isOffline || isDisconnectedSup)
                  ? null
                  : _showDeleteDialog,
              tooltip: 'Elimina',
            )
          else
            const SizedBox.shrink(),

          SizedBox(width: kIsWindows ? 8 : 8.w),
        ],
      ),
      body: clientAsync.when(
        data: (final client) {
          if (client == null) {
            return const Center(child: Text('Cliente non trovato'));
          }

          return Scrollbar(
            controller: _scrollController,
            thickness: kIsWindows ? 8 : 0,
            thumbVisibility: kIsWindows,
            interactive: kIsWindows,
            child: SingleChildScrollView(
              controller: _scrollController,
              physics: const BouncingScrollPhysics(),
              padding: EdgeInsets.all(kIsWindows ? 16 : 16.sp),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Contact Info
                  _InfoSection(
                    title: 'Contatti',
                    icon: Symbols.contact_phone_rounded,
                    children: [
                      _InfoRow(
                        icon: Symbols.phone_rounded,
                        label: 'Telefono',
                        value: client.phoneNumber,
                        onTap: () => ContactActions.showPhoneActionDialog(
                          context,
                          client.phoneNumber,
                        ),
                      ),
                      if (client.email != null)
                        _InfoRow(
                          icon: Symbols.email_rounded,
                          label: 'Email',
                          value: client.email!,
                          onTap: () =>
                              ContactActions.openEmail(context, client.email!),
                        ),
                      if (client.address != null)
                        _InfoRow(
                          icon: Symbols.location_on_rounded,
                          label: 'Indirizzo',
                          value: client.address!,
                        ),
                    ],
                  ),
                  SizedBox(height: kIsWindows ? 16 : 12.h),

                  // Consent Info
                  _InfoSection(
                    title: 'Informazioni personali',
                    icon: Symbols.person_rounded,
                    index: 2,
                    children: [
                      if (client.birthDate != null) ...[
                        SizedBox(height: kIsWindows ? 8 : 8.h),
                        _InfoRow(
                          icon: Symbols.cake_rounded,
                          label: 'Data di nascita',
                          value: DateFormat(
                            'dd/MM/yyyy',
                            'it',
                          ).format(client.birthDate!),
                        ),
                      ],
                      SizedBox(height: kIsWindows ? 8 : 8.h),
                      _InfoRow(
                        icon: Symbols.event_available_rounded,
                        label: 'Cliente dal',
                        value: DateFormat(
                          'dd/MM/yyyy',
                          'it',
                        ).format(client.createdAt),
                      ),
                    ],
                  ),

                  // Notes
                  if (client.notes != null && client.notes!.isNotEmpty) ...[
                    SizedBox(height: kIsWindows ? 16 : 12.h),
                    _InfoSection(
                      title: 'Note',
                      icon: Symbols.note_rounded,
                      index: 3,
                      children: [
                        Text(
                          client.notes!,
                          style: TextStyle(
                            color: colorScheme.onSurface,
                            fontSize: kIsWindows ? 16 : 16.sp,
                          ),
                        ),
                      ],
                    ),
                  ],

                  // Placeholder for History
                  SizedBox(height: kIsWindows ? 16 : 12.h),
                  _InfoSection(
                    title: 'Cronologia appuntamenti',
                    icon: Symbols.history_rounded,
                    index: 5,
                    children: [
                      Center(
                        child: Padding(
                          padding: EdgeInsets.all(kIsWindows ? 24 : 24.sp),
                          child: Column(
                            children: [
                              Icon(
                                Symbols.event_note_rounded,
                                size: kIsWindows ? 48 : 48.sp,
                                color: colorScheme.outline,
                              ),
                              SizedBox(height: kIsWindows ? 12 : 12.h),
                              Text(
                                'Funzionalità in arrivo',
                                style: TextStyle(
                                  color: colorScheme.outline,
                                  fontSize: kIsWindows ? 16 : 16.sp,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          );
        },
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (final error, _) => Center(child: Text('Errore: $error')),
      ),
    );
  }
}

class _InfoSection extends StatelessWidget {
  const _InfoSection({
    required this.title,
    required this.icon,
    required this.children,
    this.index = 1,
  });

  final String title;
  final IconData icon;
  final List<Widget> children;
  final int index;

  @override
  Widget build(final BuildContext context) =>
      Card(
            margin: EdgeInsets.zero,
            child: Padding(
              padding: EdgeInsets.all(kIsWindows ? 16 : 16.sp),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Icon(icon, size: kIsWindows ? 24 : 24.sp),
                      SizedBox(width: kIsWindows ? 12 : 12.w),
                      Text(
                        title,
                        style: TextStyle(
                          fontSize: kIsWindows ? 20 : 20.sp,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],
                  ),
                  SizedBox(height: kIsWindows ? 16 : 16.h),
                  ...children,
                ],
              ),
            ),
          )
          .animate()
          .fadeIn(
            duration: kDefaultAppAnimationsDuration,
            delay: (animationDelay * index).ms,
          )
          .slideX(
            begin: 0.25,
            end: 0,
            duration: kDefaultAppAnimationsDuration,
            delay: (animationDelay * index).ms,
            curve: Curves.easeOutCubic,
          );
}

class _InfoRow extends StatelessWidget {
  const _InfoRow({
    required this.icon,
    required this.label,
    required this.value,
    this.onTap,
  });

  final IconData icon;
  final String label;
  final String value;
  final VoidCallback? onTap;

  @override
  Widget build(final BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    final content = Row(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(
          icon,
          size: kIsWindows ? 20 : 20.sp,
          color: onTap != null
              ? colorScheme.primary
              : colorScheme.onSurfaceVariant,
        ),
        SizedBox(width: kIsWindows ? 12 : 12.w),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                label,
                style: TextStyle(
                  fontSize: kIsWindows ? 16 : 16.sp,
                  fontWeight: FontWeight.bold,
                  color: onTap != null
                      ? colorScheme.primary
                      : colorScheme.onSurfaceVariant,
                ),
              ),
              SizedBox(height: kIsWindows ? 2 : 2.h),
              Text(
                value,
                style: TextStyle(
                  fontSize: kIsWindows ? 16 : 16.sp,
                  color: onTap != null
                      ? colorScheme.primary
                      : colorScheme.onSurfaceVariant,
                ),
              ),
            ],
          ),
        ),
        if (onTap != null)
          Icon(
            Symbols.chevron_right_rounded,
            size: kIsWindows ? 20 : 20.sp,
            color: colorScheme.outline,
          ),
      ],
    );

    if (onTap != null) {
      return Padding(
        padding: EdgeInsets.only(bottom: kIsWindows ? 12 : 12.h),
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(kIsWindows ? 8 : 8.r),
          child: Padding(
            padding: EdgeInsets.all(kIsWindows ? 4 : 4.sp),
            child: content,
          ),
        ),
      );
    }

    return Padding(
      padding: EdgeInsets.only(
        bottom: kIsWindows ? 12 : 12.h,
        left: kIsWindows ? 4 : 4.sp,
      ),
      child: content,
    );
  }
}
