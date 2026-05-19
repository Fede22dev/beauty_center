import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:intl/intl.dart';
import 'package:material_symbols_icons/symbols.dart';

import '../../../../core/connectivity/connectivity_providers.dart';
import '../../../../core/constants/app_constants.dart';
import '../../../../core/database/app_database.dart';
import '../../../../core/logging/app_logger.dart';
import '../../../../core/providers/supabase_auth_provider.dart';
import '../../../../core/tabs/app_tabs.dart';
import '../../../../core/widgets/contact_actions_dialogs.dart';
import '../../../../core/widgets/custom_snackbar.dart';
import '../../../appointments/providers/appointments_providers.dart';
import '../../../fidelity/presentation/widgets/dialogs/fidelity_topup_dialog.dart';
import '../../../fidelity/providers/fidelity_providers.dart';
import '../../../packages/presentation/pages/package_details_page.dart';
import '../../../packages/providers/packages_providers.dart';
import '../../../payments/providers/payments_providers.dart';
import '../../../product_sales/presentation/widgets/dialogs/product_sale_dialog.dart';
import '../../../product_sales/providers/product_sales_providers.dart';
import '../../../products/providers/products_providers.dart';
import '../../../quotes/presentation/widgets/dialogs/quote_acceptance_dialog.dart';
import '../../../quotes/presentation/widgets/dialogs/quote_details_dialog.dart';
import '../../../quotes/presentation/widgets/dialogs/quote_dialog.dart';
import '../../../quotes/providers/quotes_providers.dart';
import '../../../treatments/providers/treatments_providers.dart';
import '../../providers/client_analytics_providers.dart';
import '../../providers/clients_providers.dart';
import '../widgets/add_edit_client_dialog.dart';
import '../widgets/ml_insights_card.dart';

const animationDelay = 50;

/// Extension per capitalizzare la prima lettera di una stringa
extension StringCapitalize on String {
  String capitalize() {
    if (isEmpty) return this;
    return '${this[0].toUpperCase()}${substring(1)}';
  }
}

class ClientDetailsPage extends ConsumerStatefulWidget {
  const ClientDetailsPage({required this.clientId, super.key});

  final String clientId;

  @override
  ConsumerState<ClientDetailsPage> createState() => _ClientDetailPageState();
}

class _ClientDetailPageState extends ConsumerState<ClientDetailsPage>
    with TickerProviderStateMixin {
  static final _log = AppLogger.getLogger(name: 'ClientDetailsPage');
  late TabController _tabController;
  late ScrollController _scrollController;

  // Calendar state
  DateTime _selectedCalendarMonth = DateTime.now();
  DateTime? _selectedCalendarDate;

  // Notes editing state
  bool _isEditingNotes = false;
  late TextEditingController _notesController;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 7, vsync: this);
    _scrollController = ScrollController();
    _notesController = TextEditingController();
  }

  @override
  void dispose() {
    _tabController.dispose();
    _scrollController.dispose();
    _notesController.dispose();
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
      _log.severe('Error deleting client', e);
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
    _log.finest('Edit client: ${widget.clientId}');

    final client = await ref
        .read(clientsActionsProvider)
        .getClientById(widget.clientId);
    if (client == null) {
      _log.warning('Client ${widget.clientId} not found');
      return;
    }

    if (!mounted) return;

    final result = await showDialog<bool>(
      context: context,
      builder: (_) => AddEditClientDialog(client: client, mode: Mode.edit),
    );

    if (result == true) {
      _log.finest('Client updated successfully');
    }
  }

  Future<void> _showCreateQuoteDialog() async {
    final result = await showDialog<bool>(
      context: context,
      builder: (context) => QuoteDialog(clientId: widget.clientId),
    );
    if (result == true && mounted) {
      showCustomSnackBar(
        context: context,
        message: 'Preventivo creato con successo',
        okColor: AppTabs.clients.color,
      );
    }
  }

  Future<void> _showCreateFidelityDialog() async {
    final result = await showDialog<bool>(
      context: context,
      builder: (context) => FidelityTopupDialog(clientId: widget.clientId),
    );
    if (result == true && mounted) {
      showCustomSnackBar(
        context: context,
        message: 'Operazione fidelity completata',
        okColor: AppTabs.clients.color,
      );
    }
  }

  Future<void> _showSellProductDialog() async {
    final result = await showDialog<bool>(
      context: context,
      builder: (context) => ProductSaleDialog(clientId: widget.clientId),
    );
    if (result == true && mounted) {
      showCustomSnackBar(
        context: context,
        message: 'Vendita registrata con successo',
        okColor: AppTabs.clients.color,
      );
    }
  }

  @override
  Widget build(final BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final isOffline = ref.watch(isConnectionUnusableProvider);
    final isDisconnectedSup = ref.watch(supabaseAuthProvider).isDisconnected;
    final clientAsync = ref.watch(clientStreamProvider(widget.clientId));

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

          // Initialize notes controller when client data is loaded
          if (!_isEditingNotes &&
              _notesController.text != (client.notes ?? '')) {
            _notesController.text = client.notes ?? '';
          }

          return Column(
            children: [
              // TabBar
              TabBar(
                controller: _tabController,
                isScrollable: true,
                tabs: const [
                  Tab(
                    icon: Icon(Symbols.contact_page_rounded),
                    text: 'Profilo',
                  ),
                  Tab(
                    icon: Icon(Symbols.medical_information_rounded),
                    text: 'Scheda Tecnica',
                  ),
                  Tab(icon: Icon(Symbols.info_rounded), text: 'Generale'),
                  Tab(
                    icon: Icon(Symbols.inventory_2_rounded),
                    text: 'Pacchetti',
                  ),
                  Tab(icon: Icon(Symbols.spa_rounded), text: 'Servizi'),
                  Tab(
                    icon: Icon(Symbols.card_membership_rounded),
                    text: 'Fidelity',
                  ),
                  Tab(
                    icon: Icon(Symbols.analytics_rounded),
                    text: 'Statistiche',
                  ),
                ],
              ),

              // TabBarView
              Expanded(
                child: TabBarView(
                  controller: _tabController,
                  children: [
                    // TAB 1: Profilo (Anagrafica completa, tags, note)
                    _ProfileTab(
                      client: client,
                      clientId: widget.clientId,
                      notesController: _notesController,
                      isEditingNotes: _isEditingNotes,
                      onEditNotes: () => setState(() => _isEditingNotes = true),
                      onSaveNotes: () async {
                        await ref
                            .read(clientsActionsProvider)
                            .updateClient(
                              id: client.id,
                              firstName: client.firstName,
                              lastName: client.lastName,
                              phoneNumber: client.phoneNumber,
                              email: client.email,
                              birthDate: client.birthDate,
                              address: client.address,
                              notes: _notesController.text.trim(),
                            );
                        setState(() => _isEditingNotes = false);
                        if (context.mounted) {
                          showCustomSnackBar(
                            context: context,
                            message: 'Note aggiornate',
                            okColor: AppTabs.clients.color,
                          );
                        }
                      },
                      onCancelEditNotes: () {
                        _notesController.text = client.notes ?? '';
                        setState(() => _isEditingNotes = false);
                      },
                      isOffline: isOffline || isDisconnectedSup,
                    ),

                    // TAB 2: Scheda Tecnica
                    _TechnicalSheetTab(
                      clientId: widget.clientId,
                      isOffline: isOffline || isDisconnectedSup,
                    ),

                    // TAB 3: Generale
                    _GeneralTab(clientId: widget.clientId, client: client),

                    // TAB 3: Pacchetti
                    _PackagesTab(
                      clientId: widget.clientId,
                      onCreateQuote: _showCreateQuoteDialog,
                      onSellProduct: _showSellProductDialog,
                      isOffline: isOffline || isDisconnectedSup,
                    ),

                    // TAB 4: Servizi
                    _ServicesTab(
                      clientId: widget.clientId,
                      selectedCalendarMonth: _selectedCalendarMonth,
                      selectedCalendarDate: _selectedCalendarDate,
                      onMonthChanged: (date) =>
                          setState(() => _selectedCalendarMonth = date),
                      onDateSelected: (date) =>
                          setState(() => _selectedCalendarDate = date),
                    ),

                    // TAB 5: Fidelity
                    _FidelityTab(
                      clientId: widget.clientId,
                      onCreateFidelity: _showCreateFidelityDialog,
                      isOffline: isOffline || isDisconnectedSup,
                    ),

                    // TAB 6: Statistiche
                    _StatisticsTab(clientId: widget.clientId),
                  ],
                ),
              ),
            ],
          );
        },
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (final error, _) => Center(child: Text('Errore: $error')),
      ),
    );
  }
}

// ============================================================================
// TAB 1: Profile - Client Info, Tags, Editable Notes
// ============================================================================
class _ProfileTab extends ConsumerWidget {
  const _ProfileTab({
    required this.client,
    required this.clientId,
    required this.notesController,
    required this.isEditingNotes,
    required this.onEditNotes,
    required this.onSaveNotes,
    required this.onCancelEditNotes,
    required this.isOffline,
  });

  final Client client;
  final String clientId;
  final TextEditingController notesController;
  final bool isEditingNotes;
  final VoidCallback onEditNotes;
  final VoidCallback onSaveNotes;
  final VoidCallback onCancelEditNotes;
  final bool isOffline;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final cs = Theme.of(context).colorScheme;
    final tagsAsync = ref.watch(clientTagsStreamProvider(clientId));

    return SingleChildScrollView(
      padding: EdgeInsets.all(kIsWindows ? 16 : 16.sp),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header con nome, data registrazione e export PDF
          Row(
            children: [
              Expanded(
                child: Text(
                  '${client.firstName} ${client.lastName}',
                  style: TextStyle(
                    fontSize: kIsWindows ? 28 : 28.sp,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
              // Export PDF button
              Consumer(
                builder: (context, ref, _) => IconButton(
                  onPressed: isOffline
                      ? null
                      : () async {
                          final exporter = ref.read(clientPdfExportProvider);
                          final path = await exporter.exportClientSummary(
                            clientId: clientId,
                            clientName:
                                '${client.firstName} ${client.lastName}',
                          );
                          if (path != null && context.mounted) {
                            showCustomSnackBar(
                              context: context,
                              message: 'PDF salvato: $path',
                              okColor: AppTabs.clients.color,
                            );
                          }
                        },
                  icon: const Icon(Symbols.print_rounded),
                  tooltip: 'Esporta PDF',
                ),
              ),
              SizedBox(width: kIsWindows ? 8 : 8.w),
              // Data registrazione
              Container(
                padding: EdgeInsets.symmetric(
                  horizontal: kIsWindows ? 12 : 12.w,
                  vertical: kIsWindows ? 6 : 6.h,
                ),
                decoration: BoxDecoration(
                  color: cs.surfaceContainerHighest,
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      Symbols.calendar_today_rounded,
                      size: kIsWindows ? 14 : 14.sp,
                      color: cs.outline,
                    ),
                    SizedBox(width: kIsWindows ? 6 : 6.w),
                    Text(
                      'Dal ${DateFormat('dd/MM/yyyy').format(client.createdAt)}',
                      style: TextStyle(
                        fontSize: kIsWindows ? 12 : 12.sp,
                        color: cs.onSurfaceVariant,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          SizedBox(height: kIsWindows ? 16 : 16.h),

          // Griglia dettagli cliente
          Container(
            padding: EdgeInsets.all(kIsWindows ? 16 : 16.sp),
            decoration: BoxDecoration(
              color: cs.surfaceContainerLowest,
              borderRadius: BorderRadius.circular(12),
            ),
            child: Column(
              children: [
                // Telefono (sempre presente)
                _DetailRow(
                  icon: Symbols.phone_rounded,
                  iconColor: Colors.green,
                  label: 'Telefono',
                  value: client.phoneNumber,
                  onTap: () => ContactActions.showPhoneActionDialog(
                    context,
                    client.phoneNumber,
                  ),
                ),
                const Divider(height: 16),

                // Email
                if (client.email != null) ...[
                  _DetailRow(
                    icon: Symbols.email_rounded,
                    iconColor: Colors.blue,
                    label: 'Email',
                    value: client.email!,
                    onTap: () =>
                        ContactActions.openEmail(context, client.email!),
                  ),
                  const Divider(height: 16),
                ] else
                  const _EmptyDetailRow(
                    icon: Symbols.email_rounded,
                    label: 'Email',
                  ),

                // Indirizzo
                if (client.address != null) ...[
                  _DetailRow(
                    icon: Symbols.location_on_rounded,
                    iconColor: Colors.orange,
                    label: 'Indirizzo',
                    value: client.address!,
                  ),
                  const Divider(height: 16),
                ] else
                  const _EmptyDetailRow(
                    icon: Symbols.location_on_rounded,
                    label: 'Indirizzo',
                  ),

                // Data di nascita
                if (client.birthDate != null) ...[
                  _DetailRow(
                    icon: Symbols.cake_rounded,
                    iconColor: Colors.purple,
                    label: 'Data di nascita',
                    value: DateFormat('dd/MM/yyyy').format(client.birthDate!),
                    extraValue: _calculateAge(client.birthDate!),
                  ),
                  const Divider(height: 16),
                ] else
                  const _EmptyDetailRow(
                    icon: Symbols.cake_rounded,
                    label: 'Data di nascita',
                  ),
              ],
            ),
          ),

          SizedBox(height: kIsWindows ? 16 : 16.h),

          // Tags
          _ClientTagsWidget(
            clientId: clientId,
            tagsAsync: tagsAsync,
            isOffline: isOffline,
          ),

          SizedBox(height: kIsWindows ? 16 : 16.h),

          // Note modificabili
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Note',
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: kIsWindows ? 16 : 16.sp,
                ),
              ),
              if (!isOffline)
                isEditingNotes
                    ? Row(
                        children: [
                          IconButton(
                            icon: const Icon(Symbols.close_rounded),
                            onPressed: onCancelEditNotes,
                            tooltip: 'Annulla',
                          ),
                          IconButton(
                            icon: const Icon(Symbols.check_rounded),
                            onPressed: onSaveNotes,
                            tooltip: 'Salva',
                            color: cs.primary,
                          ),
                        ],
                      )
                    : IconButton(
                        icon: const Icon(Symbols.edit_rounded),
                        onPressed: onEditNotes,
                        tooltip: 'Modifica note',
                      ),
            ],
          ),
          SizedBox(height: kIsWindows ? 8 : 8.h),
          if (isEditingNotes)
            TextField(
              controller: notesController,
              maxLines: 4,
              decoration: InputDecoration(
                hintText: 'Inserisci note...',
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
              ),
            )
          else if (client.notes != null && client.notes!.isNotEmpty)
            Container(
              width: double.infinity,
              padding: EdgeInsets.all(kIsWindows ? 12 : 12.sp),
              decoration: BoxDecoration(
                color: cs.surfaceContainerHighest,
                borderRadius: BorderRadius.circular(8),
              ),
              child: Text(
                client.notes!,
                style: TextStyle(
                  fontSize: kIsWindows ? 14 : 14.sp,
                  color: cs.onSurfaceVariant,
                ),
              ),
            )
          else
            Text(
              'Nessuna nota',
              style: TextStyle(
                fontSize: kIsWindows ? 14 : 14.sp,
                color: cs.outline,
                fontStyle: FontStyle.italic,
              ),
            ),
        ],
      ),
    );
  }
}

/// Calculate age from birth date
String _calculateAge(DateTime birthDate) {
  final now = DateTime.now();
  var age = now.year - birthDate.year;
  if (now.month < birthDate.month ||
      (now.month == birthDate.month && now.day < birthDate.day)) {
    age--;
  }
  return age == 1 ? '1 anno' : '$age anni';
}

// ============================================================================
// WIDGET: Detail Row
// ============================================================================
class _DetailRow extends StatelessWidget {
  const _DetailRow({
    required this.icon,
    required this.iconColor,
    required this.label,
    required this.value,
    this.extraValue,
    this.onTap,
    this.isSmall = false,
  });

  final IconData icon;
  final Color iconColor;
  final String label;
  final String value;
  final String? extraValue;
  final VoidCallback? onTap;
  final bool isSmall;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(8),
      child: Padding(
        padding: EdgeInsets.symmetric(vertical: kIsWindows ? 4 : 4.sp),
        child: Row(
          children: [
            Container(
              padding: EdgeInsets.all(kIsWindows ? 8 : 8.sp),
              decoration: BoxDecoration(
                color: iconColor.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Icon(
                icon,
                size: kIsWindows ? (isSmall ? 16 : 20) : (isSmall ? 16 : 20).sp,
                color: iconColor,
              ),
            ),
            SizedBox(width: kIsWindows ? 12 : 12.w),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    label,
                    style: TextStyle(
                      fontSize: kIsWindows
                          ? (isSmall ? 11 : 12)
                          : (isSmall ? 11 : 12).sp,
                      color: cs.outline,
                    ),
                  ),
                  Text(
                    value,
                    style: TextStyle(
                      fontSize: kIsWindows
                          ? (isSmall ? 13 : 16)
                          : (isSmall ? 13 : 16).sp,
                      fontWeight: FontWeight.w500,
                      color: onTap != null ? cs.primary : cs.onSurface,
                    ),
                  ),
                ],
              ),
            ),
            if (extraValue != null)
              Container(
                padding: EdgeInsets.symmetric(
                  horizontal: kIsWindows ? 8 : 8.w,
                  vertical: kIsWindows ? 4 : 4.h,
                ),
                decoration: BoxDecoration(
                  color: cs.surfaceContainerHighest,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Text(
                  extraValue!,
                  style: TextStyle(
                    fontSize: kIsWindows ? 12 : 12.sp,
                    color: cs.onSurfaceVariant,
                  ),
                ),
              ),
            if (onTap != null)
              Icon(
                Symbols.chevron_right_rounded,
                size: kIsWindows ? 20 : 20.sp,
                color: cs.outline,
              ),
          ],
        ),
      ),
    );
  }
}

// ============================================================================
// WIDGET: Empty Detail Row
// ============================================================================
class _EmptyDetailRow extends StatelessWidget {
  const _EmptyDetailRow({required this.icon, required this.label});

  final IconData icon;
  final String label;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Padding(
      padding: EdgeInsets.symmetric(vertical: kIsWindows ? 4 : 4.sp),
      child: Row(
        children: [
          Container(
            padding: EdgeInsets.all(kIsWindows ? 8 : 8.sp),
            decoration: BoxDecoration(
              color: cs.surfaceContainerHighest,
              borderRadius: BorderRadius.circular(8),
            ),
            child: Icon(icon, size: kIsWindows ? 20 : 20.sp, color: cs.outline),
          ),
          SizedBox(width: kIsWindows ? 12 : 12.w),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: TextStyle(
                    fontSize: kIsWindows ? 12 : 12.sp,
                    color: cs.outline,
                  ),
                ),
                Text(
                  'Non specificato',
                  style: TextStyle(
                    fontSize: kIsWindows ? 14 : 14.sp,
                    color: cs.outline.withValues(alpha: 0.6),
                    fontStyle: FontStyle.italic,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// ============================================================================
// WIDGET: Client Tags
// ============================================================================
class _ClientTagsWidget extends ConsumerWidget {
  const _ClientTagsWidget({
    required this.clientId,
    required this.tagsAsync,
    required this.isOffline,
  });

  final String clientId;
  final AsyncValue<List<ClientTagData>> tagsAsync;
  final bool isOffline;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final cs = Theme.of(context).colorScheme;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              'Tag',
              style: TextStyle(
                fontWeight: FontWeight.bold,
                fontSize: kIsWindows ? 16 : 16.sp,
              ),
            ),
            if (!isOffline)
              TextButton.icon(
                onPressed: () => _showAddTagDialog(context, ref),
                icon: const Icon(Symbols.add_rounded, size: 18),
                label: const Text('Aggiungi'),
              ),
          ],
        ),
        SizedBox(height: kIsWindows ? 8 : 8.h),
        tagsAsync.when(
          data: (tags) {
            if (tags.isEmpty) {
              return Text(
                'Nessun tag',
                style: TextStyle(
                  fontSize: kIsWindows ? 14 : 14.sp,
                  color: cs.outline,
                  fontStyle: FontStyle.italic,
                ),
              );
            }
            return Wrap(
              spacing: kIsWindows ? 8 : 8.w,
              runSpacing: kIsWindows ? 8 : 8.h,
              children: tags
                  .map(
                    (tag) => _TagChip(
                      tag: tag,
                      onDelete: isOffline
                          ? null
                          : () => _removeTag(context, ref, tag.id),
                    ),
                  )
                  .toList(),
            );
          },
          loading: () =>
              const SizedBox(height: 20, child: LinearProgressIndicator()),
          error: (_, __) => const SizedBox.shrink(),
        ),
      ],
    );
  }

  void _showAddTagDialog(BuildContext context, WidgetRef ref) {
    final controller = TextEditingController();
    String? selectedColor;

    // Predefined tags with colors
    const predefinedTags = <String, String>{
      'VIP': '#FFD700', // Gold
      'Allergica': '#FF6B6B', // Red
      'Preferisce Mattina': '#4ECDC4', // Teal
      'Preferisce Pomeriggio': '#45B7D1', // Blue
      'Gravidanza': '#FF9FF3', // Pink
      'Senior': '#95E1D3', // Light teal
      'Uomo': '#74B9FF', // Light blue
      'Bambino': '#FDCB6E', // Yellow
    };

    // Available colors
    const colors = [
      '#FF6B6B',
      '#4ECDC4',
      '#45B7D1',
      '#96CEB4',
      '#FFEEAD',
      '#FF9FF3',
      '#54A0FF',
      '#5F27CD',
      '#00D2D3',
      '#FF9F43',
      '#10AC84',
      '#EE5A6F',
      '#C44569',
      '#786FA6',
      '#F8B500',
    ];

    showDialog<void>(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setState) => AlertDialog(
          title: const Text('Aggiungi tag'),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Tag name input
                TextField(
                  controller: controller,
                  decoration: InputDecoration(
                    labelText: 'Nome tag',
                    hintText: 'Es: VIP, Allergica...',
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(8),
                    ),
                  ),
                  autofocus: true,
                ),
                SizedBox(height: kIsWindows ? 16 : 16.h),

                // Color selection
                Text(
                  'Colore',
                  style: TextStyle(
                    fontWeight: FontWeight.w600,
                    fontSize: kIsWindows ? 14 : 14.sp,
                  ),
                ),
                SizedBox(height: kIsWindows ? 8 : 8.h),
                Wrap(
                  spacing: kIsWindows ? 8 : 8.w,
                  runSpacing: kIsWindows ? 8 : 8.h,
                  children: colors
                      .map(
                        (color) => InkWell(
                          onTap: () => setState(() => selectedColor = color),
                          child: Container(
                            width: kIsWindows ? 36 : 36.w,
                            height: kIsWindows ? 36 : 36.h,
                            decoration: BoxDecoration(
                              color: Color(
                                int.parse(color.replaceFirst('#', '0xFF')),
                              ),
                              shape: BoxShape.circle,
                              border: selectedColor == color
                                  ? Border.all(color: Colors.white, width: 3)
                                  : null,
                              boxShadow: selectedColor == color
                                  ? [
                                      BoxShadow(
                                        color: Colors.black26,
                                        blurRadius: 4,
                                      ),
                                    ]
                                  : null,
                            ),
                          ),
                        ),
                      )
                      .toList(),
                ),
                SizedBox(height: kIsWindows ? 16 : 16.h),

                // Predefined tags
                Text(
                  'Tag suggeriti',
                  style: TextStyle(
                    fontWeight: FontWeight.w600,
                    fontSize: kIsWindows ? 14 : 14.sp,
                  ),
                ),
                SizedBox(height: kIsWindows ? 8 : 8.h),
                Wrap(
                  spacing: kIsWindows ? 8 : 8.w,
                  runSpacing: kIsWindows ? 8 : 8.h,
                  children: predefinedTags.entries
                      .map(
                        (entry) => ActionChip(
                          label: Text(entry.key),
                          backgroundColor: Color(
                            int.parse(entry.value.replaceFirst('#', '0xFF')),
                          ).withValues(alpha: 0.2),
                          side: BorderSide(
                            color: Color(
                              int.parse(entry.value.replaceFirst('#', '0xFF')),
                            ).withValues(alpha: 0.3),
                          ),
                          onPressed: () {
                            controller.text = entry.key;
                            setState(() => selectedColor = entry.value);
                          },
                        ),
                      )
                      .toList(),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Annulla'),
            ),
            FilledButton(
              onPressed: () async {
                final tag = controller.text.trim();
                if (tag.isNotEmpty) {
                  await ref
                      .read(clientTagsActionsProvider)
                      .addTag(
                        clientId: clientId,
                        tag: tag,
                        colorHex: selectedColor ?? '#95A5A6',
                      );
                  if (context.mounted) {
                    Navigator.pop(context);
                    showCustomSnackBar(
                      context: context,
                      message: 'Tag aggiunto',
                      okColor: AppTabs.clients.color,
                    );
                  }
                }
              },
              child: const Text('Aggiungi'),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _removeTag(
    BuildContext context,
    WidgetRef ref,
    String tagId,
  ) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Rimuovi tag'),
        content: const Text('Sei sicuro di voler rimuovere questo tag?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Annulla'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Rimuovi'),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      await ref.read(clientTagsActionsProvider).removeTag(tagId);
      if (context.mounted) {
        showCustomSnackBar(
          context: context,
          message: 'Tag rimosso',
          okColor: AppTabs.clients.color,
        );
      }
    }
  }
}

class _TagChip extends StatelessWidget {
  const _TagChip({required this.tag, this.onDelete});

  final ClientTagData tag;
  final VoidCallback? onDelete;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final color = tag.colorHex != null
        ? Color(int.parse(tag.colorHex!.replaceFirst('#', '0xFF')))
        : cs.secondary;

    return Chip(
      label: Text(tag.tag),
      backgroundColor: color.withValues(alpha: 0.15),
      side: BorderSide(color: color.withValues(alpha: 0.3)),
      deleteIcon: onDelete != null
          ? const Icon(Symbols.close_rounded, size: 16)
          : null,
      onDeleted: onDelete,
      labelStyle: TextStyle(
        color: color,
        fontSize: kIsWindows ? 13 : 13.sp,
        fontWeight: FontWeight.w500,
      ),
    );
  }
}

// ============================================================================
// TAB 2: Scheda Tecnica - Technical Sheet for Treatments
// ============================================================================
class _TechnicalSheetTab extends ConsumerStatefulWidget {
  const _TechnicalSheetTab({required this.clientId, required this.isOffline});

  final String clientId;
  final bool isOffline;

  @override
  ConsumerState<_TechnicalSheetTab> createState() => _TechnicalSheetTabState();
}

class _TechnicalSheetTabState extends ConsumerState<_TechnicalSheetTab> {
  bool _isEditing = false;
  bool _isLoading = false;

  // Controllers for text fields
  late final Map<String, TextEditingController> _controllers;

  // Checkbox values
  late final Map<String, bool> _checkboxValues;

  // Fitzpatrick type
  int? _fitzpatrickType;

  @override
  void initState() {
    super.initState();
    _controllers = {
      'skinType': TextEditingController(),
      'skinConditions': TextEditingController(),
      'allergies': TextEditingController(),
      'contraindications': TextEditingController(),
      'currentMedications': TextEditingController(),
      'previousTreatments': TextEditingController(),
      'machineSettings': TextEditingController(),
      'treatmentGoals': TextEditingController(),
      'medicalNotes': TextEditingController(),
    };
    _checkboxValues = {
      'isPregnant': false,
      'isBreastfeeding': false,
      'hasSunSensitivity': false,
      'hasHerpesHistory': false,
      'hasKeloidTendency': false,
      'hasDiabetes': false,
      'hasPacemaker': false,
    };
  }

  @override
  void dispose() {
    for (final controller in _controllers.values) {
      controller.dispose();
    }
    super.dispose();
  }

  void _initializeFromData(ClientTechnicalSheetData? data) {
    if (data == null) return;

    _controllers['skinType']!.text = data.skinType ?? '';
    _controllers['skinConditions']!.text = data.skinConditions ?? '';
    _controllers['allergies']!.text = data.allergies ?? '';
    _controllers['contraindications']!.text = data.contraindications ?? '';
    _controllers['currentMedications']!.text = data.currentMedications ?? '';
    _controllers['previousTreatments']!.text = data.previousTreatments ?? '';
    _controllers['machineSettings']!.text = data.machineSettings ?? '';
    _controllers['treatmentGoals']!.text = data.treatmentGoals ?? '';
    _controllers['medicalNotes']!.text = data.medicalNotes ?? '';

    _checkboxValues['isPregnant'] = data.isPregnant;
    _checkboxValues['isBreastfeeding'] = data.isBreastfeeding;
    _checkboxValues['hasSunSensitivity'] = data.hasSunSensitivity;
    _checkboxValues['hasHerpesHistory'] = data.hasHerpesHistory;
    _checkboxValues['hasKeloidTendency'] = data.hasKeloidTendency;
    _checkboxValues['hasDiabetes'] = data.hasDiabetes;
    _checkboxValues['hasPacemaker'] = data.hasPacemaker;

    _fitzpatrickType = data.fitzpatrickType;
  }

  Future<void> _saveTechnicalSheet() async {
    setState(() => _isLoading = true);

    final success = await ref
        .read(clientsActionsProvider)
        .updateTechnicalSheet(
          clientId: widget.clientId,
          skinType: _controllers['skinType']!.text.trim(),
          skinConditions: _controllers['skinConditions']!.text.trim(),
          allergies: _controllers['allergies']!.text.trim(),
          contraindications: _controllers['contraindications']!.text.trim(),
          currentMedications: _controllers['currentMedications']!.text.trim(),
          previousTreatments: _controllers['previousTreatments']!.text.trim(),
          machineSettings: _controllers['machineSettings']!.text.trim(),
          treatmentGoals: _controllers['treatmentGoals']!.text.trim(),
          medicalNotes: _controllers['medicalNotes']!.text.trim(),
          isPregnant: _checkboxValues['isPregnant'],
          isBreastfeeding: _checkboxValues['isBreastfeeding'],
          hasSunSensitivity: _checkboxValues['hasSunSensitivity'],
          hasHerpesHistory: _checkboxValues['hasHerpesHistory'],
          hasKeloidTendency: _checkboxValues['hasKeloidTendency'],
          hasDiabetes: _checkboxValues['hasDiabetes'],
          hasPacemaker: _checkboxValues['hasPacemaker'],
          fitzpatrickType: _fitzpatrickType,
        );

    setState(() {
      _isLoading = false;
      _isEditing = false;
    });

    if (mounted) {
      showCustomSnackBar(
        context: context,
        message: success
            ? 'Scheda tecnica aggiornata'
            : 'Errore durante il salvataggio',
        okColor: success ? AppTabs.clients.color : Colors.red,
      );
    }
  }

  void _cancelEdit() {
    setState(() {
      _isEditing = false;
      // Reset controllers from current data
      final data = ref
          .read(clientTechnicalSheetStreamProvider(widget.clientId))
          .value;
      _initializeFromData(data);
    });
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final sheetAsync = ref.watch(
      clientTechnicalSheetStreamProvider(widget.clientId),
    );

    return sheetAsync.when(
      data: (data) {
        // Initialize controllers if not editing
        if (!_isEditing && data != null) {
          _initializeFromData(data);
        }

        return SingleChildScrollView(
          padding: EdgeInsets.all(kIsWindows ? 16 : 16.sp),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Header with edit button
              _buildHeader(cs, data),
              SizedBox(height: kIsWindows ? 16 : 16.h),

              // Alert banner for critical conditions
              if (_showAlertBanner(data)) ...[
                _buildAlertBanner(cs, data!),
                SizedBox(height: kIsWindows ? 16 : 16.h),
              ],

              // Fitzpatrick Skin Type
              _buildFitzpatrickSection(cs),
              SizedBox(height: kIsWindows ? 16 : 16.h),

              // Skin Information Section
              _buildSectionCard(
                cs,
                title: 'Informazioni Pelle',
                icon: Symbols.face_3_rounded,
                color: Colors.orange,
                children: [
                  _buildTextField(
                    'skinType',
                    'Tipo di Pelle',
                    'Es: Secca, Grassa, Mista, Normale, Sensibile',
                    fieldIcon: Symbols.spa_rounded,
                  ),
                  SizedBox(height: kIsWindows ? 12 : 12.h),
                  _buildTextField(
                    'skinConditions',
                    'Condizioni e Inestetismi',
                    'Es: Acne, Rosacea, Iperpigmentazione, Couperose...',
                    fieldIcon: Symbols.healing,
                    maxLines: 3,
                  ),
                ],
              ),
              SizedBox(height: kIsWindows ? 16 : 16.h),

              // Medical History Section
              _buildSectionCard(
                cs,
                title: 'Storia Medica',
                icon: Symbols.medical_services_rounded,
                color: Colors.red,
                children: [
                  _buildCheckboxGrid(cs),
                  SizedBox(height: kIsWindows ? 12 : 12.h),
                  _buildTextField(
                    'allergies',
                    'Allergie',
                    'Allergie note a prodotti, ingredienti, farmaci...',
                    fieldIcon: Symbols.warning_rounded,
                    maxLines: 3,
                  ),
                  SizedBox(height: kIsWindows ? 12 : 12.h),
                  _buildTextField(
                    'contraindications',
                    'Controindicazioni',
                    'Controindicazioni per trattamenti estetici',
                    fieldIcon: Symbols.block_rounded,
                    maxLines: 3,
                  ),
                  SizedBox(height: kIsWindows ? 12 : 12.h),
                  _buildTextField(
                    'currentMedications',
                    'Farmaci in Corso',
                    'Farmaci attuali che potrebbero influire sui trattamenti',
                    fieldIcon: Symbols.medication_rounded,
                    maxLines: 2,
                  ),
                ],
              ),
              SizedBox(height: kIsWindows ? 16 : 16.h),

              // Treatment History Section
              _buildSectionCard(
                cs,
                title: 'Storia Trattamenti',
                icon: Symbols.history_rounded,
                color: Colors.blue,
                children: [
                  _buildTextField(
                    'previousTreatments',
                    'Trattamenti Precedenti',
                    'Storia dei trattamenti estetici precedenti, risultati, reazioni...',
                    fieldIcon: Symbols.history_rounded,
                    maxLines: 4,
                  ),
                  SizedBox(height: kIsWindows ? 12 : 12.h),
                  _buildTextField(
                    'machineSettings',
                    'Impostazioni Macchinari',
                    'Parametri e configurazioni macchinari utilizzati (laser, radiofrequenza, ecc.)',
                    fieldIcon: Symbols.settings_rounded,
                    maxLines: 4,
                  ),
                ],
              ),
              SizedBox(height: kIsWindows ? 16 : 16.h),

              // Treatment Goals Section
              _buildSectionCard(
                cs,
                title: 'Obiettivi e Note',
                icon: Symbols.target_rounded,
                color: Colors.green,
                children: [
                  _buildTextField(
                    'treatmentGoals',
                    'Obiettivi Trattamento',
                    'Cosa desidera ottenere il cliente, aspettative...',
                    fieldIcon: Symbols.flag_rounded,
                    maxLines: 3,
                  ),
                  SizedBox(height: kIsWindows ? 12 : 12.h),
                  _buildTextField(
                    'medicalNotes',
                    'Note Mediche',
                    'Note aggiuntive rilevanti per i trattamenti',
                    fieldIcon: Symbols.note_rounded,
                    maxLines: 4,
                  ),
                ],
              ),
              SizedBox(height: kIsWindows ? 16 : 16.h),

              // Treatment Timeline Section
              _buildTreatmentTimelineSection(cs),
              SizedBox(height: kIsWindows ? 16 : 16.h),

              // PDF Export Button
              _buildPdfExportButton(cs),
              SizedBox(height: kIsWindows ? 16 : 16.h),

              // AI/ML Insights Section
              ClientMLInsightsCard(clientId: widget.clientId),
              SizedBox(height: kIsWindows ? 16 : 16.h),

              // Last updated
              if (data != null) ...[
                SizedBox(height: kIsWindows ? 24 : 24.h),
                Center(
                  child: Text(
                    'Ultimo aggiornamento: ${DateFormat('dd/MM/yyyy HH:mm').format(data.updatedAt.toLocal())}',
                    style: TextStyle(
                      fontSize: kIsWindows ? 12 : 12.sp,
                      color: cs.outline,
                      fontStyle: FontStyle.italic,
                    ),
                  ),
                ),
              ],
            ],
          ),
        );
      },
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (error, _) =>
          Center(child: Text('Errore caricamento scheda: $error')),
    );
  }

  Widget _buildHeader(ColorScheme cs, ClientTechnicalSheetData? data) {
    return Row(
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Scheda Tecnica Cliente',
                style: TextStyle(
                  fontSize: kIsWindows ? 22 : 22.sp,
                  fontWeight: FontWeight.bold,
                ),
              ),
              SizedBox(height: kIsWindows ? 4 : 4.h),
              Text(
                'Informazioni tecniche per trattamenti e configurazioni macchinari',
                style: TextStyle(
                  fontSize: kIsWindows ? 13 : 13.sp,
                  color: cs.outline,
                ),
              ),
            ],
          ),
        ),
        if (!widget.isOffline)
          _isLoading
              ? const SizedBox(
                  width: 24,
                  height: 24,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              : _isEditing
              ? Row(
                  children: [
                    IconButton(
                      onPressed: _cancelEdit,
                      icon: const Icon(Symbols.close_rounded),
                      tooltip: 'Annulla',
                    ),
                    FilledButton.icon(
                      onPressed: _saveTechnicalSheet,
                      icon: const Icon(Symbols.save_rounded),
                      label: const Text('Salva'),
                    ),
                  ],
                )
              : FilledButton.icon(
                  onPressed: () => setState(() => _isEditing = true),
                  icon: const Icon(Symbols.edit_rounded),
                  label: const Text('Modifica'),
                ),
      ],
    );
  }

  bool _showAlertBanner(ClientTechnicalSheetData? data) {
    if (data == null) return false;
    return data.isPregnant ||
        data.isBreastfeeding ||
        data.hasPacemaker ||
        data.hasHerpesHistory ||
        data.hasKeloidTendency;
  }

  Widget _buildAlertBanner(ColorScheme cs, ClientTechnicalSheetData data) {
    final alerts = <String>[];
    if (data.isPregnant) alerts.add('Gravidanza in corso');
    if (data.isBreastfeeding) alerts.add('Allattamento');
    if (data.hasPacemaker) alerts.add('Pacemaker / Impianto elettronico');
    if (data.hasHerpesHistory) alerts.add('Storia Herpes Simplex');
    if (data.hasKeloidTendency) alerts.add('Tendenza Cheloidi');

    return Container(
      padding: EdgeInsets.all(kIsWindows ? 16 : 16.sp),
      decoration: BoxDecoration(
        color: Colors.red.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.red.withValues(alpha: 0.3)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(
                Symbols.warning_rounded,
                color: Colors.red,
                size: kIsWindows ? 20 : 20.sp,
              ),
              SizedBox(width: kIsWindows ? 8 : 8.w),
              Text(
                'Attenzione - Controindicazioni',
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: kIsWindows ? 14 : 14.sp,
                  color: Colors.red,
                ),
              ),
            ],
          ),
          SizedBox(height: kIsWindows ? 8 : 8.h),
          Wrap(
            spacing: kIsWindows ? 8 : 8.w,
            runSpacing: kIsWindows ? 4 : 4.h,
            children: alerts
                .map(
                  (alert) => Chip(
                    label: Text(alert),
                    backgroundColor: Colors.red.withValues(alpha: 0.1),
                    side: BorderSide(color: Colors.red.withValues(alpha: 0.3)),
                    labelStyle: TextStyle(
                      color: Colors.red,
                      fontSize: kIsWindows ? 12 : 12.sp,
                    ),
                    padding: EdgeInsets.zero,
                    visualDensity: VisualDensity.compact,
                  ),
                )
                .toList(),
          ),
        ],
      ),
    );
  }

  Widget _buildFitzpatrickSection(ColorScheme cs) {
    return _buildSectionCard(
      cs,
      title: 'Scala Fitzpatrick',
      icon: Symbols.palette_rounded,
      color: Colors.purple,
      children: [
        Text(
          'Tipo fotografico della pelle (1-6)',
          style: TextStyle(
            fontSize: kIsWindows ? 13 : 13.sp,
            color: cs.outline,
          ),
        ),
        SizedBox(height: kIsWindows ? 12 : 12.h),
        if (_isEditing)
          Wrap(
            spacing: kIsWindows ? 8 : 8.w,
            children: List.generate(6, (index) {
              final type = index + 1;
              final isSelected = _fitzpatrickType == type;
              return ChoiceChip(
                label: Text(
                  '$type',
                  style: TextStyle(
                    fontWeight: isSelected
                        ? FontWeight.bold
                        : FontWeight.normal,
                    fontSize: kIsWindows ? 14 : 14.sp,
                  ),
                ),
                selected: isSelected,
                onSelected: (selected) {
                  setState(() {
                    _fitzpatrickType = selected ? type : null;
                  });
                },
              );
            }),
          )
        else
          Row(
            children: [
              Container(
                padding: EdgeInsets.symmetric(
                  horizontal: kIsWindows ? 16 : 16.w,
                  vertical: kIsWindows ? 8 : 8.h,
                ),
                decoration: BoxDecoration(
                  color: _fitzpatrickType != null
                      ? Colors.purple.withValues(alpha: 0.1)
                      : cs.surfaceContainerHighest,
                  borderRadius: BorderRadius.circular(8),
                  border: _fitzpatrickType != null
                      ? Border.all(color: Colors.purple.withValues(alpha: 0.3))
                      : null,
                ),
                child: Text(
                  _fitzpatrickType != null
                      ? 'Tipo $_fitzpatrickType'
                      : 'Non specificato',
                  style: TextStyle(
                    fontSize: kIsWindows ? 16 : 16.sp,
                    fontWeight: FontWeight.w500,
                    color: _fitzpatrickType != null
                        ? Colors.purple
                        : cs.outline,
                  ),
                ),
              ),
              if (_fitzpatrickType != null) ...[
                SizedBox(width: kIsWindows ? 12 : 12.w),
                Expanded(
                  child: Text(
                    _getFitzpatrickDescription(_fitzpatrickType!),
                    style: TextStyle(
                      fontSize: kIsWindows ? 13 : 13.sp,
                      color: cs.onSurfaceVariant,
                    ),
                  ),
                ),
              ],
            ],
          ),
      ],
    );
  }

  String _getFitzpatrickDescription(int type) {
    switch (type) {
      case 1:
        return 'Pelle molto chiara, sempre brucia, non si abbronza';
      case 2:
        return 'Pelle chiara, brucia facilmente, si abbronza poco';
      case 3:
        return 'Pelle media, brucia a volte, si abbronza gradualmente';
      case 4:
        return 'Pelle olivastra, brucia raramente, si abbronza facilmente';
      case 5:
        return 'Pelle scura, brucia molto raramente, si abbronza molto';
      case 6:
        return 'Pelle molto scura, non brucia mai, si abbronza molto';
      default:
        return '';
    }
  }

  Widget _buildTreatmentTimelineSection(ColorScheme cs) {
    final timelineAsync = ref.watch(
      clientTreatmentTimelineProvider(widget.clientId),
    );

    return _buildSectionCard(
      cs,
      title: 'Cronologia Trattamenti',
      icon: Symbols.timeline_rounded,
      color: Colors.purple,
      children: [
        timelineAsync.when(
          data: (entries) {
            if (entries.isEmpty) {
              return Center(
                child: Padding(
                  padding: EdgeInsets.all(kIsWindows ? 16 : 16.sp),
                  child: Column(
                    children: [
                      Icon(
                        Symbols.history_toggle_off_rounded,
                        size: kIsWindows ? 40 : 40.sp,
                        color: cs.outline,
                      ),
                      SizedBox(height: kIsWindows ? 8 : 8.h),
                      Text(
                        'Nessun trattamento registrato',
                        style: TextStyle(
                          color: cs.outline,
                          fontSize: kIsWindows ? 14 : 14.sp,
                        ),
                      ),
                    ],
                  ),
                ),
              );
            }

            return Column(
              children: entries.map((entry) {
                final isFirst = entries.first == entry;
                final isLast = entries.last == entry;

                return IntrinsicHeight(
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Timeline line
                      Column(
                        children: [
                          if (!isFirst)
                            Container(
                              width: 2,
                              height: kIsWindows ? 12 : 12.h,
                              color: cs.primary.withValues(alpha: 0.3),
                            ),
                          Container(
                            width: kIsWindows ? 12 : 12.w,
                            height: kIsWindows ? 12 : 12.h,
                            decoration: BoxDecoration(
                              color: cs.primary,
                              shape: BoxShape.circle,
                            ),
                          ),
                          if (!isLast)
                            Expanded(
                              child: Container(
                                width: 2,
                                color: cs.primary.withValues(alpha: 0.3),
                              ),
                            ),
                        ],
                      ),
                      SizedBox(width: kIsWindows ? 12 : 12.w),

                      // Content
                      Expanded(
                        child: Card(
                          margin: EdgeInsets.only(
                            bottom: kIsWindows ? 12 : 12.h,
                          ),
                          child: Padding(
                            padding: EdgeInsets.all(kIsWindows ? 12 : 12.sp),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Row(
                                  children: [
                                    Icon(
                                      Symbols.calendar_today_rounded,
                                      size: kIsWindows ? 14 : 14.sp,
                                      color: cs.primary,
                                    ),
                                    SizedBox(width: kIsWindows ? 6 : 6.w),
                                    Text(
                                      DateFormat(
                                        'dd/MM/yyyy',
                                      ).format(entry.date),
                                      style: TextStyle(
                                        fontWeight: FontWeight.bold,
                                        fontSize: kIsWindows ? 14 : 14.sp,
                                        color: cs.primary,
                                      ),
                                    ),
                                  ],
                                ),
                                SizedBox(height: kIsWindows ? 6 : 6.h),
                                if (entry.serviceNames.isNotEmpty) ...[
                                  Wrap(
                                    spacing: kIsWindows ? 4 : 4.w,
                                    runSpacing: kIsWindows ? 4 : 4.h,
                                    children: entry.serviceNames.map((name) {
                                      return Chip(
                                        label: Text(
                                          name,
                                          style: TextStyle(
                                            fontSize: kIsWindows ? 11 : 11.sp,
                                          ),
                                        ),
                                        visualDensity: VisualDensity.compact,
                                        padding: EdgeInsets.zero,
                                      );
                                    }).toList(),
                                  ),
                                  SizedBox(height: kIsWindows ? 6 : 6.h),
                                ],
                                if (entry.operatorName != null) ...[
                                  Row(
                                    children: [
                                      Icon(
                                        Symbols.person_rounded,
                                        size: kIsWindows ? 12 : 12.sp,
                                        color: cs.outline,
                                      ),
                                      SizedBox(width: kIsWindows ? 4 : 4.w),
                                      Text(
                                        entry.operatorName!,
                                        style: TextStyle(
                                          fontSize: kIsWindows ? 12 : 12.sp,
                                          color: cs.outline,
                                        ),
                                      ),
                                    ],
                                  ),
                                  SizedBox(height: kIsWindows ? 4 : 4.h),
                                ],
                                if (entry.operatorNotes?.isNotEmpty ==
                                    true) ...[
                                  Container(
                                    width: double.infinity,
                                    padding: EdgeInsets.all(
                                      kIsWindows ? 8 : 8.sp,
                                    ),
                                    decoration: BoxDecoration(
                                      color: cs.surfaceContainerHighest,
                                      borderRadius: BorderRadius.circular(8),
                                    ),
                                    child: Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        Text(
                                          'Note operatore:',
                                          style: TextStyle(
                                            fontSize: kIsWindows ? 11 : 11.sp,
                                            fontWeight: FontWeight.bold,
                                            color: cs.outline,
                                          ),
                                        ),
                                        SizedBox(height: kIsWindows ? 2 : 2.h),
                                        Text(
                                          entry.operatorNotes!,
                                          style: TextStyle(
                                            fontSize: kIsWindows ? 12 : 12.sp,
                                            color: cs.onSurfaceVariant,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                  SizedBox(height: kIsWindows ? 6 : 6.h),
                                ],
                                if (entry.skinReaction?.isNotEmpty == true) ...[
                                  Container(
                                    width: double.infinity,
                                    padding: EdgeInsets.all(
                                      kIsWindows ? 8 : 8.sp,
                                    ),
                                    decoration: BoxDecoration(
                                      color: Colors.orange.withValues(
                                        alpha: 0.1,
                                      ),
                                      borderRadius: BorderRadius.circular(8),
                                      border: Border.all(
                                        color: Colors.orange.withValues(
                                          alpha: 0.3,
                                        ),
                                      ),
                                    ),
                                    child: Row(
                                      children: [
                                        Icon(
                                          Symbols.healing_rounded,
                                          size: kIsWindows ? 14 : 14.sp,
                                          color: Colors.orange,
                                        ),
                                        SizedBox(width: kIsWindows ? 6 : 6.w),
                                        Expanded(
                                          child: Text(
                                            'Reazione: ${entry.skinReaction}',
                                            style: TextStyle(
                                              fontSize: kIsWindows ? 12 : 12.sp,
                                              color: Colors.orange.shade800,
                                            ),
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
                      ),
                    ],
                  ),
                );
              }).toList(),
            );
          },
          loading: () => const Center(child: CircularProgressIndicator()),
          error: (error, _) => Center(
            child: Text(
              'Errore caricamento: $error',
              style: TextStyle(color: cs.error),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildPdfExportButton(ColorScheme cs) {
    return Card(
      child: InkWell(
        onTap: widget.isOffline
            ? null
            : () async {
                final exporter = ref.read(clientPdfExportProvider);
                final path = await exporter.exportTechnicalSheetPdf(
                  clientId: widget.clientId,
                  clientName: 'Cliente',
                );
                if (path != null && mounted) {
                  showCustomSnackBar(
                    context: context,
                    message: 'PDF salvato: $path',
                    okColor: AppTabs.clients.color,
                  );
                }
              },
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: EdgeInsets.all(kIsWindows ? 16 : 16.sp),
          child: Row(
            children: [
              Container(
                padding: EdgeInsets.all(kIsWindows ? 10 : 10.sp),
                decoration: BoxDecoration(
                  color: cs.primaryContainer,
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(
                  Symbols.print_rounded,
                  color: cs.onPrimaryContainer,
                  size: kIsWindows ? 24 : 24.sp,
                ),
              ),
              SizedBox(width: kIsWindows ? 16 : 16.w),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Esporta Scheda Tecnica PDF',
                      style: TextStyle(
                        fontSize: kIsWindows ? 16 : 16.sp,
                        fontWeight: FontWeight.bold,
                        color: cs.onSurface,
                      ),
                    ),
                    SizedBox(height: kIsWindows ? 2 : 2.h),
                    Text(
                      'Genera PDF medico confidenziale con tutti i dati',
                      style: TextStyle(
                        fontSize: kIsWindows ? 13 : 13.sp,
                        color: cs.outline,
                      ),
                    ),
                  ],
                ),
              ),
              Icon(Symbols.chevron_right_rounded, color: cs.outline),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildSectionCard(
    ColorScheme cs, {
    required String title,
    required IconData icon,
    required Color color,
    required List<Widget> children,
  }) {
    return Card(
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(color: cs.outlineVariant.withValues(alpha: 0.5)),
      ),
      child: Padding(
        padding: EdgeInsets.all(kIsWindows ? 16 : 16.sp),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  padding: EdgeInsets.all(kIsWindows ? 8 : 8.sp),
                  decoration: BoxDecoration(
                    color: color.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Icon(
                    icon,
                    color: color,
                    size: kIsWindows ? 20 : 20.sp,
                  ),
                ),
                SizedBox(width: kIsWindows ? 12 : 12.w),
                Text(
                  title,
                  style: TextStyle(
                    fontSize: kIsWindows ? 16 : 16.sp,
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
    );
  }

  Widget _buildTextField(
    String key,
    String label,
    String hint, {
    required IconData fieldIcon,
    int maxLines = 1,
  }) {
    final cs = Theme.of(context).colorScheme;

    if (_isEditing) {
      return TextField(
        controller: _controllers[key],
        maxLines: maxLines,
        decoration: InputDecoration(
          labelText: label,
          hintText: hint,
          prefixIcon: Icon(fieldIcon, size: kIsWindows ? 20 : 20.sp),
          border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
          contentPadding: EdgeInsets.symmetric(
            horizontal: kIsWindows ? 12 : 12.w,
            vertical: maxLines > 1
                ? kIsWindows
                      ? 12
                      : 12.h
                : kIsWindows
                ? 0
                : 0,
          ),
        ),
      );
    }

    final text = _controllers[key]!.text;
    final hasValue = text.isNotEmpty;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Icon(fieldIcon, size: kIsWindows ? 18 : 18.sp, color: cs.outline),
            SizedBox(width: kIsWindows ? 8 : 8.w),
            Text(
              label,
              style: TextStyle(
                fontSize: kIsWindows ? 13 : 13.sp,
                color: cs.outline,
              ),
            ),
          ],
        ),
        SizedBox(height: kIsWindows ? 4 : 4.h),
        Container(
          width: double.infinity,
          padding: EdgeInsets.all(kIsWindows ? 12 : 12.sp),
          decoration: BoxDecoration(
            color: hasValue
                ? cs.surfaceContainerLowest
                : cs.surfaceContainerHighest,
            borderRadius: BorderRadius.circular(8),
          ),
          child: hasValue
              ? Text(
                  text,
                  style: TextStyle(
                    fontSize: kIsWindows ? 14 : 14.sp,
                    height: 1.4,
                  ),
                )
              : Text(
                  'Non specificato',
                  style: TextStyle(
                    fontSize: kIsWindows ? 14 : 14.sp,
                    color: cs.outline.withValues(alpha: 0.6),
                    fontStyle: FontStyle.italic,
                  ),
                ),
        ),
      ],
    );
  }

  Widget _buildCheckboxGrid(ColorScheme cs) {
    final items = [
      _CheckboxItem(
        key: 'isPregnant',
        label: 'Gravidanza',
        icon: Symbols.pregnant_woman_rounded,
        color: Colors.pink,
      ),
      _CheckboxItem(
        key: 'isBreastfeeding',
        label: 'Allattamento',
        icon: Symbols.child_care_rounded,
        color: Colors.blue,
      ),
      _CheckboxItem(
        key: 'hasSunSensitivity',
        label: 'Fotosensibilità',
        icon: Symbols.wb_sunny_rounded,
        color: Colors.orange,
      ),
      _CheckboxItem(
        key: 'hasHerpesHistory',
        label: 'Storia Herpes',
        icon: Symbols.bug_report_rounded,
        color: Colors.red,
      ),
      _CheckboxItem(
        key: 'hasKeloidTendency',
        label: 'Tendenza Cheloidi',
        icon: Symbols.cut_rounded,
        color: Colors.purple,
      ),
      _CheckboxItem(
        key: 'hasDiabetes',
        label: 'Diabete',
        icon: Symbols.water_drop_rounded,
        color: Colors.red.shade700,
      ),
      _CheckboxItem(
        key: 'hasPacemaker',
        label: 'Pacemaker / Impianto',
        icon: Symbols.monitor_heart_rounded,
        color: Colors.teal,
      ),
    ];

    return Column(
      children: [
        if (_isEditing)
          Wrap(
            spacing: kIsWindows ? 8 : 8.w,
            runSpacing: kIsWindows ? 8 : 8.h,
            children: items.map((item) {
              final isSelected = _checkboxValues[item.key] ?? false;
              return FilterChip(
                label: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      item.icon,
                      size: kIsWindows ? 16 : 16.sp,
                      color: isSelected ? item.color : cs.outline,
                    ),
                    SizedBox(width: kIsWindows ? 4 : 4.w),
                    Text(item.label),
                  ],
                ),
                selected: isSelected,
                onSelected: (selected) {
                  setState(() {
                    _checkboxValues[item.key] = selected;
                  });
                },
                selectedColor: item.color.withValues(alpha: 0.1),
                checkmarkColor: item.color,
                side: BorderSide(
                  color: isSelected
                      ? item.color.withValues(alpha: 0.5)
                      : cs.outlineVariant,
                ),
              );
            }).toList(),
          )
        else
          Wrap(
            spacing: kIsWindows ? 8 : 8.w,
            runSpacing: kIsWindows ? 8 : 8.h,
            children: items
                .where((item) => _checkboxValues[item.key] ?? false)
                .map((item) {
                  return Chip(
                    label: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          item.icon,
                          size: kIsWindows ? 16 : 16.sp,
                          color: item.color,
                        ),
                        SizedBox(width: kIsWindows ? 4 : 4.w),
                        Text(item.label),
                      ],
                    ),
                    backgroundColor: item.color.withValues(alpha: 0.1),
                    side: BorderSide(color: item.color.withValues(alpha: 0.3)),
                    labelStyle: TextStyle(
                      color: item.color,
                      fontSize: kIsWindows ? 12 : 12.sp,
                    ),
                  );
                })
                .toList(),
          ),
      ],
    );
  }
}

class _CheckboxItem {
  final String key;
  final String label;
  final IconData icon;
  final Color color;

  _CheckboxItem({
    required this.key,
    required this.label,
    required this.icon,
    required this.color,
  });
}

// ============================================================================
// TAB 1: Generale
// ============================================================================
class _GeneralTab extends StatelessWidget {
  const _GeneralTab({required this.clientId, required this.client});

  final String clientId;
  final Client client;

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: EdgeInsets.all(kIsWindows ? 16 : 16.sp),
      children: [
        // Alert Scadenze Pacchetti
        _PackageAlertsSection(clientId: clientId),
        SizedBox(height: kIsWindows ? 12 : 12.h),

        // Customer Lifetime Value
        _CLVCard(clientId: clientId),
        SizedBox(height: kIsWindows ? 12 : 12.h),

        // ML Service Recommendations
        _RecommendationsCard(clientId: clientId),
        SizedBox(height: kIsWindows ? 12 : 12.h),

        // Statistiche rapide
        _QuickStatsCard(clientId: clientId),
        SizedBox(height: kIsWindows ? 12 : 12.h),

        // Preferenze
        _PreferencesSection(
          clientId: clientId,
          isExpanded: true,
          onToggle: () {},
        ),
        SizedBox(height: kIsWindows ? 12 : 12.h),

        // Product Blacklist
        _ProductBlacklistCard(clientId: clientId, client: client),
      ],
    );
  }
}

class _QuickStatsCard extends ConsumerWidget {
  const _QuickStatsCard({required this.clientId});

  final String clientId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final cs = Theme.of(context).colorScheme;
    final statsAsync = ref.watch(clientStatisticsProvider(clientId));

    return Card(
      child: Padding(
        padding: EdgeInsets.all(kIsWindows ? 16 : 16.sp),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Statistiche Rapide',
              style: TextStyle(
                fontWeight: FontWeight.bold,
                fontSize: kIsWindows ? 16 : 16.sp,
              ),
            ),
            SizedBox(height: kIsWindows ? 12 : 12.h),
            statsAsync.when(
              data: (stats) {
                return Wrap(
                  spacing: kIsWindows ? 8 : 8.w,
                  runSpacing: kIsWindows ? 8 : 8.h,
                  children: [
                    _QuickStatChip(
                      icon: Symbols.payments_rounded,
                      label: 'Speso',
                      value: '€${stats.totalSpent.toStringAsFixed(0)}',
                      color: Colors.green,
                    ),
                    _QuickStatChip(
                      icon: Symbols.inventory_2_rounded,
                      label: 'Pacchetti',
                      value: '${stats.activePackages} attivi',
                      color: cs.primary,
                    ),
                    _QuickStatChip(
                      icon: Symbols.schedule_rounded,
                      label: 'Visite',
                      value: '${stats.totalAppointments}',
                      color: Colors.orange,
                    ),
                    if (stats.totalFidelityBalance > 0)
                      _QuickStatChip(
                        icon: Symbols.card_membership_rounded,
                        label: 'Fidelity',
                        value:
                            '€${stats.totalFidelityBalance.toStringAsFixed(0)}',
                        color: Colors.purple,
                      ),
                  ],
                );
              },
              loading: () =>
                  const SizedBox(height: 40, child: LinearProgressIndicator()),
              error: (_, __) => const SizedBox.shrink(),
            ),
          ],
        ),
      ),
    );
  }
}

class _QuickStatChip extends StatelessWidget {
  const _QuickStatChip({
    required this.icon,
    required this.label,
    required this.value,
    required this.color,
  });

  final IconData icon;
  final String label;
  final String value;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: EdgeInsets.symmetric(
        horizontal: kIsWindows ? 12 : 12.w,
        vertical: kIsWindows ? 8 : 8.h,
      ),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withValues(alpha: 0.2)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: kIsWindows ? 16 : 16.sp, color: color),
          SizedBox(width: kIsWindows ? 6 : 6.w),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                label,
                style: TextStyle(
                  fontSize: kIsWindows ? 11 : 11.sp,
                  color: color,
                ),
              ),
              Text(
                value,
                style: TextStyle(
                  fontSize: kIsWindows ? 14 : 14.sp,
                  fontWeight: FontWeight.bold,
                  color: color,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

// ============================================================================
// WIDGET: CLV Card (Customer Lifetime Value)
// ============================================================================
class _CLVCard extends ConsumerWidget {
  const _CLVCard({required this.clientId});

  final String clientId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final cs = Theme.of(context).colorScheme;
    final clvAsync = ref.watch(clientCLVProvider(clientId));

    return Card(
      child: Padding(
        padding: EdgeInsets.all(kIsWindows ? 16 : 16.sp),
        child: clvAsync.when(
          data: (clv) => Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Icon(Symbols.analytics_rounded, color: cs.primary),
                  SizedBox(width: kIsWindows ? 8 : 8.w),
                  Text(
                    'Valore Cliente Stimato (CLV)',
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: kIsWindows ? 16 : 16.sp,
                    ),
                  ),
                  const Spacer(),
                  Container(
                    padding: EdgeInsets.symmetric(
                      horizontal: kIsWindows ? 8 : 8.w,
                      vertical: kIsWindows ? 4 : 4.h,
                    ),
                    decoration: BoxDecoration(
                      color: clv.riskColor.withValues(alpha: 0.15),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Text(
                      clv.riskLevel,
                      style: TextStyle(
                        fontSize: kIsWindows ? 12 : 12.sp,
                        color: clv.riskColor,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ),
                ],
              ),
              SizedBox(height: kIsWindows ? 16 : 16.h),
              Row(
                children: [
                  Expanded(
                    child: _CLVStat(
                      label: 'Valore Lifetime',
                      value: '€${clv.estimatedValue.toStringAsFixed(0)}',
                      icon: Symbols.payments_rounded,
                      color: Colors.green,
                    ),
                  ),
                  Expanded(
                    child: _CLVStat(
                      label: 'Spesa/Media',
                      value: '€${clv.averageMonthlySpend.toStringAsFixed(0)}',
                      icon: Symbols.calendar_view_month_rounded,
                      color: Colors.blue,
                    ),
                  ),
                  Expanded(
                    child: _CLVStat(
                      label: 'Visite/Mese',
                      value: clv.visitFrequency.toStringAsFixed(1),
                      icon: Symbols.schedule_rounded,
                      color: Colors.orange,
                    ),
                  ),
                ],
              ),
            ],
          ),
          loading: () =>
              const SizedBox(height: 60, child: LinearProgressIndicator()),
          error: (_, __) => const SizedBox.shrink(),
        ),
      ),
    );
  }
}

class _CLVStat extends StatelessWidget {
  const _CLVStat({
    required this.label,
    required this.value,
    required this.icon,
    required this.color,
  });

  final String label;
  final String value;
  final IconData icon;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Icon(icon, color: color, size: kIsWindows ? 24 : 24.sp),
        SizedBox(height: kIsWindows ? 4 : 4.h),
        Text(
          value,
          style: TextStyle(
            fontSize: kIsWindows ? 18 : 18.sp,
            fontWeight: FontWeight.bold,
            color: color,
          ),
        ),
        Text(
          label,
          style: TextStyle(
            fontSize: kIsWindows ? 11 : 11.sp,
            color: Colors.grey,
          ),
        ),
      ],
    );
  }
}

// ============================================================================
// WIDGET: ML Recommendations Card
// ============================================================================
class _RecommendationsCard extends ConsumerWidget {
  const _RecommendationsCard({required this.clientId});

  final String clientId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final cs = Theme.of(context).colorScheme;
    final recsAsync = ref.watch(clientServiceRecommendationsProvider(clientId));

    return Card(
      child: Padding(
        padding: EdgeInsets.all(kIsWindows ? 16 : 16.sp),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Symbols.lightbulb_rounded, color: Colors.amber),
                SizedBox(width: kIsWindows ? 8 : 8.w),
                Text(
                  'Consigliati per te',
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: kIsWindows ? 16 : 16.sp,
                  ),
                ),
              ],
            ),
            SizedBox(height: kIsWindows ? 12 : 12.h),
            recsAsync.when(
              data: (recs) {
                if (recs.isEmpty) {
                  return Text(
                    'Nessun consiglio disponibile',
                    style: TextStyle(
                      fontSize: kIsWindows ? 14 : 14.sp,
                      color: cs.outline,
                      fontStyle: FontStyle.italic,
                    ),
                  );
                }
                return Column(
                  children: recs
                      .take(3)
                      .map(
                        (rec) => ListTile(
                          leading: Container(
                            width: 40,
                            height: 40,
                            decoration: BoxDecoration(
                              color: rec.isUrgent
                                  ? Colors.red.withValues(alpha: 0.1)
                                  : rec.confidenceColor.withValues(alpha: 0.1),
                              shape: BoxShape.circle,
                            ),
                            child: Icon(
                              rec.isUrgent
                                  ? Symbols.notifications_active_rounded
                                  : Symbols.spa_rounded,
                              color: rec.isUrgent
                                  ? Colors.red
                                  : rec.confidenceColor,
                            ),
                          ),
                          title: Text(
                            rec.serviceName,
                            style: TextStyle(fontWeight: FontWeight.w500),
                          ),
                          subtitle: Text(
                            rec.reason,
                            style: TextStyle(fontSize: kIsWindows ? 12 : 12.sp),
                          ),
                          trailing: Chip(
                            label: Text(rec.confidenceLabel),
                            backgroundColor: rec.confidenceColor.withValues(
                              alpha: 0.15,
                            ),
                            side: BorderSide(
                              color: rec.confidenceColor.withValues(alpha: 0.3),
                            ),
                            labelStyle: TextStyle(
                              color: rec.confidenceColor,
                              fontSize: kIsWindows ? 11 : 11.sp,
                            ),
                          ),
                        ),
                      )
                      .toList(),
                );
              },
              loading: () =>
                  const SizedBox(height: 60, child: LinearProgressIndicator()),
              error: (_, __) => const SizedBox.shrink(),
            ),
          ],
        ),
      ),
    );
  }
}

// ============================================================================
// WIDGET: Product Blacklist Card
// ============================================================================
class _ProductBlacklistCard extends ConsumerWidget {
  const _ProductBlacklistCard({required this.clientId, required this.client});

  final String clientId;
  final Client client;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final cs = Theme.of(context).colorScheme;
    final blacklistAsync = ref.watch(
      clientProductBlacklistStreamProvider(clientId),
    );
    final productsAsync = ref.watch(productsStreamProvider);

    return Card(
      child: Padding(
        padding: EdgeInsets.all(kIsWindows ? 16 : 16.sp),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Row(
                  children: [
                    Icon(Symbols.block_rounded, color: Colors.red),
                    SizedBox(width: kIsWindows ? 8 : 8.w),
                    Text(
                      'Prodotti da non proporre',
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: kIsWindows ? 16 : 16.sp,
                      ),
                    ),
                  ],
                ),
                TextButton.icon(
                  onPressed: () => _showAddToBlacklistDialog(context, ref),
                  icon: const Icon(Symbols.add_rounded, size: 18),
                  label: const Text('Aggiungi'),
                ),
              ],
            ),
            SizedBox(height: kIsWindows ? 12 : 12.h),
            blacklistAsync.when(
              data: (blacklist) {
                if (blacklist.isEmpty) {
                  return Text(
                    'Nessun prodotto in blacklist',
                    style: TextStyle(
                      fontSize: kIsWindows ? 14 : 14.sp,
                      color: cs.outline,
                      fontStyle: FontStyle.italic,
                    ),
                  );
                }
                return productsAsync.when(
                  data: (products) {
                    return Column(
                      children: blacklist.map((item) {
                        final product = products.firstWhere(
                          (p) => p.id == item.productId,
                          orElse: () => ProductData(
                            id: '',
                            name: 'Prodotto sconosciuto',
                            description: '',
                            price: 0,
                            isActive: false,
                            createdAt: DateTime.now(),
                            updatedAt: DateTime.now(),
                          ),
                        );
                        return ListTile(
                          leading: Icon(
                            Symbols.shopping_bag_rounded,
                            color: Colors.red,
                          ),
                          title: Text(product.name),
                          subtitle: Text(
                            item.reason ?? 'Nessuna motivazione',
                            style: TextStyle(fontSize: kIsWindows ? 12 : 12.sp),
                          ),
                          trailing: IconButton(
                            icon: const Icon(
                              Symbols.delete_rounded,
                              color: Colors.red,
                            ),
                            onPressed: () =>
                                _removeFromBlacklist(context, ref, item.id),
                          ),
                        );
                      }).toList(),
                    );
                  },
                  loading: () => const SizedBox(
                    height: 40,
                    child: LinearProgressIndicator(),
                  ),
                  error: (_, __) => const SizedBox.shrink(),
                );
              },
              loading: () =>
                  const SizedBox(height: 40, child: LinearProgressIndicator()),
              error: (_, __) => const SizedBox.shrink(),
            ),
          ],
        ),
      ),
    );
  }

  void _showAddToBlacklistDialog(BuildContext context, WidgetRef ref) {
    final reasonController = TextEditingController();
    String? selectedProductId;

    showDialog<void>(
      context: context,
      builder: (context) => Consumer(
        builder: (context, ref, _) {
          final productsAsync = ref.watch(productsStreamProvider);

          return AlertDialog(
            title: const Text('Aggiungi a blacklist'),
            content: productsAsync.when(
              data: (products) => Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  DropdownButtonFormField<String>(
                    initialValue: selectedProductId,
                    hint: const Text('Seleziona prodotto'),
                    items: products
                        .map(
                          (p) => DropdownMenuItem(
                            value: p.id,
                            child: Text(p.name),
                          ),
                        )
                        .toList(),
                    onChanged: (value) => selectedProductId = value,
                  ),
                  SizedBox(height: kIsWindows ? 16 : 16.h),
                  TextField(
                    controller: reasonController,
                    decoration: InputDecoration(
                      labelText: 'Motivazione (opzionale)',
                      hintText: 'Es: Allergia, Non gradito...',
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(8),
                      ),
                    ),
                  ),
                ],
              ),
              loading: () => const SizedBox(
                height: 100,
                child: Center(child: CircularProgressIndicator()),
              ),
              error: (_, __) => const Text('Errore caricamento prodotti'),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: const Text('Annulla'),
              ),
              FilledButton(
                onPressed: selectedProductId == null
                    ? null
                    : () async {
                        await ref
                            .read(clientProductBlacklistActionsProvider)
                            .addToBlacklist(
                              clientId: clientId,
                              productId: selectedProductId!,
                              reason: reasonController.text.trim().isNotEmpty
                                  ? reasonController.text.trim()
                                  : null,
                            );
                        if (context.mounted) {
                          Navigator.pop(context);
                          showCustomSnackBar(
                            context: context,
                            message: 'Prodotto aggiunto alla blacklist',
                            okColor: AppTabs.clients.color,
                          );
                        }
                      },
                child: const Text('Aggiungi'),
              ),
            ],
          );
        },
      ),
    );
  }

  Future<void> _removeFromBlacklist(
    BuildContext context,
    WidgetRef ref,
    String blacklistId,
  ) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Rimuovi dalla blacklist'),
        content: const Text(
          'Sei sicuro di voler rimuovere questo prodotto dalla blacklist?',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Annulla'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Rimuovi'),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      await ref
          .read(clientProductBlacklistActionsProvider)
          .removeFromBlacklist(blacklistId);
      if (context.mounted) {
        showCustomSnackBar(
          context: context,
          message: 'Prodotto rimosso dalla blacklist',
          okColor: AppTabs.clients.color,
        );
      }
    }
  }
}

// ============================================================================
// TAB 2: Pacchetti
// ============================================================================
class _PackagesTab extends StatelessWidget {
  const _PackagesTab({
    required this.clientId,
    required this.onCreateQuote,
    required this.onSellProduct,
    required this.isOffline,
  });

  final String clientId;
  final VoidCallback onCreateQuote;
  final VoidCallback onSellProduct;
  final bool isOffline;

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: EdgeInsets.all(kIsWindows ? 16 : 16.sp),
      children: [
        _QuotesSection(
          clientId: clientId,
          isExpanded: true,
          onToggle: () {},
          onCreateQuote: onCreateQuote,
          isOffline: isOffline,
        ),
        SizedBox(height: kIsWindows ? 12 : 12.h),
        _PackagesSection(
          clientId: clientId,
          isExpanded: true,
          onToggle: () {},
          isOffline: isOffline,
        ),
        SizedBox(height: kIsWindows ? 12 : 12.h),
        _ProductsSection(
          clientId: clientId,
          isExpanded: true,
          onToggle: () {},
          onSellProduct: onSellProduct,
          isOffline: isOffline,
        ),
      ],
    );
  }
}

// ============================================================================
// TAB 3: Servizi
// ============================================================================
class _ServicesTab extends StatelessWidget {
  const _ServicesTab({
    required this.clientId,
    required this.selectedCalendarMonth,
    required this.selectedCalendarDate,
    required this.onMonthChanged,
    required this.onDateSelected,
  });

  final String clientId;
  final DateTime selectedCalendarMonth;
  final DateTime? selectedCalendarDate;
  final void Function(DateTime) onMonthChanged;
  final void Function(DateTime?) onDateSelected;

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: EdgeInsets.all(kIsWindows ? 16 : 16.sp),
      children: [
        _CalendarSection(
          clientId: clientId,
          isExpanded: true,
          onToggle: () {},
          selectedMonth: selectedCalendarMonth,
          selectedDate: selectedCalendarDate,
          onMonthChanged: onMonthChanged,
          onDateSelected: onDateSelected,
        ),
        SizedBox(height: kIsWindows ? 12 : 12.h),
        _HistorySection(clientId: clientId, isExpanded: true, onToggle: () {}),
      ],
    );
  }
}

// ============================================================================
// TAB 4: Fidelity
// ============================================================================
class _FidelityTab extends StatelessWidget {
  const _FidelityTab({
    required this.clientId,
    required this.onCreateFidelity,
    required this.isOffline,
  });

  final String clientId;
  final VoidCallback onCreateFidelity;
  final bool isOffline;

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: EdgeInsets.all(kIsWindows ? 16 : 16.sp),
      children: [
        _FidelitySection(
          clientId: clientId,
          isExpanded: true,
          onToggle: () {},
          onCreateFidelity: onCreateFidelity,
          isOffline: isOffline,
        ),
        SizedBox(height: kIsWindows ? 12 : 12.h),
        _FidelityHistorySection(
          clientId: clientId,
          isExpanded: true,
          onToggle: () {},
        ),
      ],
    );
  }
}

// ============================================================================
// TAB 5: Statistiche
// ============================================================================
class _StatisticsTab extends StatelessWidget {
  const _StatisticsTab({required this.clientId});

  final String clientId;

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: EdgeInsets.all(kIsWindows ? 16 : 16.sp),
      children: [
        _ChartsSection(clientId: clientId, isExpanded: true, onToggle: () {}),
        SizedBox(height: kIsWindows ? 12 : 12.h),
        _StatisticsSection(
          clientId: clientId,
          isExpanded: true,
          onToggle: () {},
        ),
      ],
    );
  }
}

// ============================================================================
// SEZIONE: Preventivi (espandibile con azioni)
// ============================================================================
class _QuotesSection extends ConsumerWidget {
  const _QuotesSection({
    required this.clientId,
    required this.isExpanded,
    required this.onToggle,
    required this.onCreateQuote,
    required this.isOffline,
  });

  final String clientId;
  final bool isExpanded;
  final VoidCallback onToggle;
  final VoidCallback onCreateQuote;
  final bool isOffline;

  Future<void> _showAcceptQuoteDialog(
    BuildContext context,
    String quoteId,
  ) async {
    final result = await showDialog<bool>(
      context: context,
      builder: (context) => QuoteAcceptanceDialog(quoteId: quoteId),
    );
    if (result == true && context.mounted) {
      showCustomSnackBar(
        context: context,
        message: 'Preventivo accettato e pacchetto creato',
        okColor: AppTabs.clients.color,
      );
    }
  }

  Future<void> _showQuoteDetails(BuildContext context, String quoteId) async {
    await showDialog<void>(
      context: context,
      builder: (context) => QuoteDetailsDialog(quoteId: quoteId),
    );
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final colorScheme = Theme.of(context).colorScheme;
    final quotesAsync = ref.watch(quotesByClientStreamProvider(clientId));

    return Card(
      clipBehavior: Clip.antiAlias,
      child: Column(
        children: [
          // Header espandibile
          InkWell(
            onTap: onToggle,
            child: Padding(
              padding: EdgeInsets.all(kIsWindows ? 16 : 16.sp),
              child: Row(
                children: [
                  Icon(Symbols.description_rounded, color: colorScheme.primary),
                  SizedBox(width: kIsWindows ? 12 : 12.w),
                  Expanded(
                    child: Text(
                      'Preventivi',
                      style: TextStyle(
                        fontSize: kIsWindows ? 18 : 18.sp,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                  // Azione Crea Preventivo
                  if (!isOffline)
                    IconButton(
                      icon: const Icon(Symbols.add_rounded),
                      tooltip: 'Crea preventivo',
                      onPressed: onCreateQuote,
                    ),
                  Icon(
                    isExpanded
                        ? Symbols.expand_less_rounded
                        : Symbols.expand_more_rounded,
                    color: colorScheme.outline,
                  ),
                ],
              ),
            ),
          ),
          // Contenuto espandibile
          if (isExpanded)
            quotesAsync.when(
              data: (quotes) {
                if (quotes.isEmpty) {
                  return Padding(
                    padding: EdgeInsets.all(kIsWindows ? 24 : 24.sp),
                    child: Column(
                      children: [
                        Icon(
                          Symbols.description_rounded,
                          size: kIsWindows ? 48 : 48.sp,
                          color: colorScheme.outline,
                        ),
                        SizedBox(height: kIsWindows ? 12 : 12.h),
                        Text(
                          'Nessun preventivo',
                          style: TextStyle(
                            color: colorScheme.outline,
                            fontSize: kIsWindows ? 16 : 16.sp,
                          ),
                        ),
                      ],
                    ),
                  );
                }

                return ConstrainedBox(
                  constraints: BoxConstraints(
                    maxHeight: MediaQuery.of(context).size.height * 0.5,
                  ),
                  child: ListView.separated(
                    shrinkWrap: true,
                    padding: EdgeInsets.fromLTRB(
                      kIsWindows ? 16 : 16.sp,
                      0,
                      kIsWindows ? 16 : 16.sp,
                      kIsWindows ? 16 : 16.sp,
                    ),
                    itemCount: quotes.length,
                    separatorBuilder: (_, __) =>
                        SizedBox(height: kIsWindows ? 8 : 8.h),
                    itemBuilder: (context, index) {
                      final quote = quotes[index];
                      final canAccept =
                          (quote.status == 'draft' || quote.status == 'sent') &&
                          !isOffline;
                      final finalPrice =
                          quote.totalPrice - quote.discountAmount;
                      final hasDiscount = quote.discountAmount > 0;

                      return Card(
                        margin: EdgeInsets.zero,
                        child: ListTile(
                          onTap: () => _showQuoteDetails(context, quote.id),
                          contentPadding: EdgeInsets.symmetric(
                            horizontal: kIsWindows ? 12 : 12.sp,
                            vertical: kIsWindows ? 8 : 8.h,
                          ),
                          leading: Container(
                            width: kIsWindows ? 44 : 44.sp,
                            height: kIsWindows ? 44 : 44.sp,
                            decoration: BoxDecoration(
                              color: _getQuoteStatusColor(
                                quote.status,
                                colorScheme,
                              ).withValues(alpha: 0.1),
                              borderRadius: BorderRadius.circular(
                                kIsWindows ? 10 : 10.r,
                              ),
                            ),
                            child: Icon(
                              Symbols.description_rounded,
                              color: _getQuoteStatusColor(
                                quote.status,
                                colorScheme,
                              ),
                              size: kIsWindows ? 24 : 24.sp,
                            ),
                          ),
                          title: Text(
                            quote.quoteNumber,
                            style: TextStyle(
                              fontWeight: FontWeight.bold,
                              fontSize: kIsWindows ? 15 : 15.sp,
                            ),
                          ),
                          subtitle: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              SizedBox(height: kIsWindows ? 4 : 4.h),
                              Row(
                                children: [
                                  _buildQuoteStatusChip(
                                    quote.status,
                                    colorScheme,
                                  ),
                                  const SizedBox(width: 8),
                                  Text(
                                    '${DateFormat('dd/MM/yy', 'it').format(quote.createdAt)}',
                                    style: TextStyle(
                                      fontSize: kIsWindows ? 12 : 12.sp,
                                      color: colorScheme.outline,
                                    ),
                                  ),
                                ],
                              ),
                              if (hasDiscount) ...[
                                SizedBox(height: kIsWindows ? 4 : 4.h),
                                Row(
                                  children: [
                                    Text(
                                      '€${quote.totalPrice.toStringAsFixed(2)}',
                                      style: TextStyle(
                                        fontSize: kIsWindows ? 12 : 12.sp,
                                        decoration: TextDecoration.lineThrough,
                                        color: colorScheme.outline,
                                      ),
                                    ),
                                    const SizedBox(width: 6),
                                    Icon(
                                      Symbols.arrow_forward_rounded,
                                      size: kIsWindows ? 12 : 12.sp,
                                      color: Colors.green,
                                    ),
                                    const SizedBox(width: 4),
                                    Text(
                                      '€${finalPrice.toStringAsFixed(2)}',
                                      style: TextStyle(
                                        fontSize: kIsWindows ? 14 : 14.sp,
                                        fontWeight: FontWeight.bold,
                                        color: Colors.green,
                                      ),
                                    ),
                                    const SizedBox(width: 6),
                                    Container(
                                      padding: EdgeInsets.symmetric(
                                        horizontal: kIsWindows ? 6 : 6.sp,
                                        vertical: kIsWindows ? 2 : 2.sp,
                                      ),
                                      decoration: BoxDecoration(
                                        color: Colors.green.withValues(
                                          alpha: 0.1,
                                        ),
                                        borderRadius: BorderRadius.circular(
                                          kIsWindows ? 4 : 4.r,
                                        ),
                                      ),
                                      child: Text(
                                        '-€${quote.discountAmount.toStringAsFixed(2)}',
                                        style: TextStyle(
                                          fontSize: kIsWindows ? 11 : 11.sp,
                                          color: Colors.green,
                                          fontWeight: FontWeight.w500,
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                              ] else ...[
                                Text(
                                  '€${finalPrice.toStringAsFixed(2)}',
                                  style: TextStyle(
                                    fontSize: kIsWindows ? 14 : 14.sp,
                                    fontWeight: FontWeight.w500,
                                    color: colorScheme.onSurface,
                                  ),
                                ),
                              ],
                            ],
                          ),
                          isThreeLine: hasDiscount,
                          trailing: canAccept
                              ? FilledButton.tonal(
                                  onPressed: () =>
                                      _showAcceptQuoteDialog(context, quote.id),
                                  style: FilledButton.styleFrom(
                                    padding: EdgeInsets.symmetric(
                                      horizontal: kIsWindows ? 12 : 12.sp,
                                    ),
                                  ),
                                  child: const Text('Accetta'),
                                )
                              : _buildQuoteStatusIcon(
                                  quote.status,
                                  colorScheme,
                                ),
                        ),
                      );
                    },
                  ),
                );
              },
              loading: () => const Padding(
                padding: EdgeInsets.all(24),
                child: Center(child: CircularProgressIndicator()),
              ),
              error: (error, _) => Padding(
                padding: const EdgeInsets.all(16),
                child: Text(
                  'Errore: $error',
                  style: TextStyle(color: colorScheme.error),
                ),
              ),
            ),
        ],
      ),
    );
  }

  Color _getQuoteStatusColor(String status, ColorScheme colorScheme) {
    switch (status) {
      case 'accepted':
        return Colors.green;
      case 'rejected':
        return colorScheme.error;
      case 'expired':
        return Colors.orange;
      case 'sent':
        return colorScheme.primary;
      default:
        return colorScheme.outline;
    }
  }

  String _mapQuoteStatus(String status) {
    switch (status) {
      case 'draft':
        return 'Bozza';
      case 'sent':
        return 'Inviato';
      case 'accepted':
        return 'Accettato';
      case 'rejected':
        return 'Rifiutato';
      case 'expired':
        return 'Scaduto';
      default:
        return status;
    }
  }

  Widget _buildQuoteStatusIcon(String status, ColorScheme colorScheme) {
    return Container(
      width: kIsWindows ? 36 : 36.sp,
      height: kIsWindows ? 36 : 36.sp,
      decoration: BoxDecoration(
        color: _getQuoteStatusColor(status, colorScheme).withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(kIsWindows ? 18 : 18.r),
      ),
      child: Icon(
        _getQuoteStatusIcon(status),
        color: _getQuoteStatusColor(status, colorScheme),
        size: kIsWindows ? 20 : 20.sp,
      ),
    );
  }

  IconData _getQuoteStatusIcon(String status) {
    switch (status) {
      case 'accepted':
        return Symbols.check_circle_rounded;
      case 'rejected':
        return Symbols.cancel_rounded;
      case 'expired':
        return Symbols.schedule_rounded;
      case 'sent':
        return Symbols.send_rounded;
      default:
        return Symbols.drafts_rounded;
    }
  }

  Widget _buildQuoteStatusChip(String status, ColorScheme colorScheme) {
    final color = _getQuoteStatusColor(status, colorScheme);
    return Container(
      padding: EdgeInsets.symmetric(
        horizontal: kIsWindows ? 8 : 8.sp,
        vertical: kIsWindows ? 3 : 3.sp,
      ),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(kIsWindows ? 8 : 8.r),
      ),
      child: Text(
        _mapQuoteStatus(status),
        style: TextStyle(
          fontSize: kIsWindows ? 11 : 11.sp,
          color: color,
          fontWeight: FontWeight.w500,
        ),
      ),
    );
  }
}

// ============================================================================
// SEZIONE: Pacchetti (espandibile)
// ============================================================================
class _PackagesSection extends ConsumerWidget {
  const _PackagesSection({
    required this.clientId,
    required this.isExpanded,
    required this.onToggle,
    required this.isOffline,
  });

  final String clientId;
  final bool isExpanded;
  final VoidCallback onToggle;
  final bool isOffline;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final colorScheme = Theme.of(context).colorScheme;
    final packagesAsync = ref.watch(packagesByClientStreamProvider(clientId));

    return Card(
      clipBehavior: Clip.antiAlias,
      child: Column(
        children: [
          InkWell(
            onTap: onToggle,
            child: Padding(
              padding: EdgeInsets.all(kIsWindows ? 16 : 16.sp),
              child: Row(
                children: [
                  Icon(Symbols.inventory_2_rounded, color: colorScheme.primary),
                  SizedBox(width: kIsWindows ? 12 : 12.w),
                  Expanded(
                    child: Text(
                      'Pacchetti',
                      style: TextStyle(
                        fontSize: kIsWindows ? 18 : 18.sp,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                  Icon(
                    isExpanded
                        ? Symbols.expand_less_rounded
                        : Symbols.expand_more_rounded,
                    color: colorScheme.outline,
                  ),
                ],
              ),
            ),
          ),
          if (isExpanded)
            packagesAsync.when(
              data: (packages) {
                if (packages.isEmpty) {
                  return Padding(
                    padding: EdgeInsets.all(kIsWindows ? 24 : 24.sp),
                    child: Column(
                      children: [
                        Icon(
                          Symbols.inventory_2_rounded,
                          size: kIsWindows ? 48 : 48.sp,
                          color: colorScheme.outline,
                        ),
                        SizedBox(height: kIsWindows ? 12 : 12.h),
                        Text(
                          'Nessun pacchetto',
                          style: TextStyle(
                            color: colorScheme.outline,
                            fontSize: kIsWindows ? 16 : 16.sp,
                          ),
                        ),
                      ],
                    ),
                  );
                }

                return ConstrainedBox(
                  constraints: BoxConstraints(
                    maxHeight: MediaQuery.of(context).size.height * 0.5,
                  ),
                  child: ListView.separated(
                    shrinkWrap: true,
                    padding: EdgeInsets.fromLTRB(
                      kIsWindows ? 16 : 16.sp,
                      0,
                      kIsWindows ? 16 : 16.sp,
                      kIsWindows ? 16 : 16.sp,
                    ),
                    itemCount: packages.length,
                    separatorBuilder: (_, __) =>
                        SizedBox(height: kIsWindows ? 8 : 8.h),
                    itemBuilder: (context, index) => _PackageCard(
                      package: packages[index],
                      clientId: clientId,
                      isOffline: isOffline,
                    ),
                  ),
                );
              },
              loading: () => const Padding(
                padding: EdgeInsets.all(24),
                child: Center(child: CircularProgressIndicator()),
              ),
              error: (error, _) => Padding(
                padding: const EdgeInsets.all(16),
                child: Text(
                  'Errore: $error',
                  style: TextStyle(color: colorScheme.error),
                ),
              ),
            ),
        ],
      ),
    );
  }
}

// ============================================================================
// WIDGET: Card Pacchetto espandibile con dettagli e pagamento
// ============================================================================
class _PackageCard extends ConsumerStatefulWidget {
  const _PackageCard({
    required this.package,
    required this.clientId,
    required this.isOffline,
  });

  final PackageData package;
  final String clientId;
  final bool isOffline;

  @override
  ConsumerState<_PackageCard> createState() => _PackageCardState();
}

class _PackageCardState extends ConsumerState<_PackageCard> {
  bool _isExpanded = false;

  Future<void> _showAddPaymentDialog() async {
    final remaining = widget.package.totalPrice - widget.package.paidAmount;
    if (remaining <= 0) return;

    final amountController = TextEditingController(
      text: remaining.toStringAsFixed(2),
    );
    PaymentMethod selectedMethod = PaymentMethod.cash;

    final result = await showDialog<double>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Aggiungi pagamento'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              'Importo rimanente: €${remaining.toStringAsFixed(2)}',
              style: const TextStyle(fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: amountController,
              keyboardType: const TextInputType.numberWithOptions(
                decimal: true,
              ),
              decoration: const InputDecoration(
                labelText: 'Importo (€)',
                prefixIcon: Icon(Symbols.euro_rounded),
              ),
            ),
            const SizedBox(height: 12),
            DropdownButtonFormField<PaymentMethod>(
              initialValue: selectedMethod,
              decoration: const InputDecoration(
                labelText: 'Metodo di pagamento',
                prefixIcon: Icon(Symbols.credit_card_rounded),
              ),
              items: PaymentMethod.values.map((method) {
                return DropdownMenuItem(
                  value: method,
                  child: Text(method.displayName),
                );
              }).toList(),
              onChanged: (value) {
                if (value != null) selectedMethod = value;
              },
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Annulla'),
          ),
          FilledButton(
            onPressed: () {
              final amount = double.tryParse(amountController.text);
              if (amount != null && amount > 0 && amount <= remaining) {
                Navigator.pop(context, amount);
              }
            },
            child: const Text('Paga'),
          ),
        ],
      ),
    );

    if (result != null && mounted) {
      try {
        // Gestione pagamento fidelity
        if (selectedMethod == PaymentMethod.fidelity) {
          // Recupera carte fidelity attive del cliente
          final fidelityCards = await ref
              .read(fidelityActionsProvider)
              .getActiveFidelityCardsByClientId(widget.clientId);

          if (fidelityCards.isEmpty) {
            if (mounted) {
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                  content: Text('Nessuna carta fidelity attiva trovata'),
                ),
              );
            }
            return;
          }

          // Trova una carta con saldo sufficiente
          final cardWithBalance = fidelityCards.firstWhere(
            (card) => card.balance >= result,
            orElse: () => fidelityCards.first,
          );

          if (cardWithBalance.balance < result) {
            if (mounted) {
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: Text(
                    'Credito insufficiente. Saldo: €${cardWithBalance.balance.toStringAsFixed(2)}',
                  ),
                ),
              );
            }
            return;
          }

          // Scala il credito dalla carta
          await ref
              .read(fidelityActionsProvider)
              .addUsage(
                cardId: cardWithBalance.id,
                amount: result,
                description: 'Pagamento pacchetto: ${widget.package.name}',
              );
        }

        // Aggiorna l'importo pagato del pacchetto
        final newPaidAmount = widget.package.paidAmount + result;
        await ref
            .read(packagesActionsProvider)
            .updatePackagePaidAmount(
              id: widget.package.id,
              paidAmount: newPaidAmount,
            );

        // Crea il record di pagamento
        await ref
            .read(paymentsActionsProvider)
            .createPayment(
              clientId: widget.clientId,
              packageId: widget.package.id,
              amount: result,
              paymentMethod: selectedMethod.name,
            );

        if (mounted) {
          showCustomSnackBar(
            context: context,
            message: 'Pagamento di €${result.toStringAsFixed(2)} registrato',
            okColor: AppTabs.clients.color,
          );
        }
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(
            context,
          ).showSnackBar(SnackBar(content: Text('Errore pagamento: $e')));
        }
      }
    }
  }

  Future<void> _showPackageDetails() async {
    final itemsAsync = ref.watch(packageItemsStreamProvider(widget.package.id));

    await showDialog<void>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(widget.package.name),
        content: SizedBox(
          width: 400,
          child: itemsAsync.when(
            data: (items) {
              if (items.isEmpty) {
                return const Text('Nessun servizio incluso');
              }
              return Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Servizi inclusi:',
                    style: Theme.of(context).textTheme.titleMedium,
                  ),
                  const SizedBox(height: 8),
                  ...items.map(
                    (item) => ListTile(
                      contentPadding: EdgeInsets.zero,
                      title: Text(item.lockedServiceName),
                      subtitle: Text(
                        '${item.totalSessions} sedut${item.totalSessions > 1 ? 'e' : 'a'} '
                        '• €${item.lockedUnitPrice.toStringAsFixed(2)} cad.',
                      ),
                      trailing: Text(
                        '€${(item.lockedUnitPrice * item.totalSessions).toStringAsFixed(2)}',
                        style: const TextStyle(fontWeight: FontWeight.bold),
                      ),
                    ),
                  ),
                  const Divider(),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text('Totale pacchetto:'),
                      Text(
                        '€${widget.package.totalPrice.toStringAsFixed(2)}',
                        style: const TextStyle(fontWeight: FontWeight.bold),
                      ),
                    ],
                  ),
                ],
              );
            },
            loading: () => const Center(child: CircularProgressIndicator()),
            error: (e, _) => Text('Errore: $e'),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Chiudi'),
          ),
        ],
      ),
    );
  }

  Color _getPackageStatusColor(String status, ColorScheme colorScheme) {
    switch (status) {
      case 'active':
        return colorScheme.primary;
      case 'completed':
        return Colors.green;
      case 'expired':
        return Colors.orange;
      case 'cancelled':
        return colorScheme.error;
      default:
        return colorScheme.outline;
    }
  }

  String _mapPackageStatus(String status) {
    switch (status) {
      case 'active':
        return 'Attivo';
      case 'completed':
        return 'Completato';
      case 'expired':
        return 'Scaduto';
      case 'cancelled':
        return 'Annullato';
      default:
        return status;
    }
  }

  Widget _buildPackageStatusChip(String status, ColorScheme colorScheme) {
    return Container(
      padding: EdgeInsets.symmetric(
        horizontal: kIsWindows ? 8 : 8.w,
        vertical: kIsWindows ? 4 : 4.h,
      ),
      decoration: BoxDecoration(
        color: _getPackageStatusColor(
          status,
          colorScheme,
        ).withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(kIsWindows ? 12 : 12.r),
      ),
      child: Text(
        _mapPackageStatus(status),
        style: TextStyle(
          fontSize: kIsWindows ? 12 : 12.sp,
          color: _getPackageStatusColor(status, colorScheme),
          fontWeight: FontWeight.bold,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final package = widget.package;
    final progress = package.totalPrice > 0
        ? package.paidAmount / package.totalPrice
        : 0.0;
    final remaining = package.totalPrice - package.paidAmount;
    final isPaid = remaining <= 0.01;

    return Card(
      margin: EdgeInsets.zero,
      child: Column(
        children: [
          InkWell(
            onTap: () => setState(() => _isExpanded = !_isExpanded),
            child: Padding(
              padding: EdgeInsets.all(kIsWindows ? 12 : 12.sp),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Icon(
                        Symbols.inventory_2_rounded,
                        color: _getPackageStatusColor(
                          package.status,
                          colorScheme,
                        ),
                        size: kIsWindows ? 20 : 20.sp,
                      ),
                      SizedBox(width: kIsWindows ? 8 : 8.w),
                      Expanded(
                        child: Text(
                          package.name,
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: kIsWindows ? 16 : 16.sp,
                          ),
                        ),
                      ),
                      _buildPackageStatusChip(package.status, colorScheme),
                      Icon(
                        _isExpanded
                            ? Symbols.expand_less_rounded
                            : Symbols.expand_more_rounded,
                        color: colorScheme.outline,
                      ),
                    ],
                  ),
                  SizedBox(height: kIsWindows ? 8 : 8.h),
                  LinearProgressIndicator(
                    value: progress,
                    backgroundColor: colorScheme.surfaceContainerHighest,
                    valueColor: AlwaysStoppedAnimation<Color>(
                      progress >= 1.0 ? Colors.green : colorScheme.primary,
                    ),
                  ),
                  SizedBox(height: kIsWindows ? 8 : 8.h),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        'Pagato: €${package.paidAmount.toStringAsFixed(2)} / '
                        '€${package.totalPrice.toStringAsFixed(2)}',
                        style: TextStyle(
                          fontSize: kIsWindows ? 14 : 14.sp,
                          color: colorScheme.onSurfaceVariant,
                        ),
                      ),
                      if (!isPaid)
                        Text(
                          'Da pagare: €${remaining.toStringAsFixed(2)}',
                          style: TextStyle(
                            fontSize: kIsWindows ? 14 : 14.sp,
                            color: colorScheme.error,
                            fontWeight: FontWeight.bold,
                          ),
                        )
                      else
                        Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(
                              Symbols.check_circle_rounded,
                              color: Colors.green,
                              size: kIsWindows ? 16 : 16.sp,
                            ),
                            SizedBox(width: kIsWindows ? 4 : 4.w),
                            Text(
                              'Pagato',
                              style: TextStyle(
                                color: Colors.green,
                                fontWeight: FontWeight.bold,
                                fontSize: kIsWindows ? 14 : 14.sp,
                              ),
                            ),
                          ],
                        ),
                    ],
                  ),
                ],
              ),
            ),
          ),
          // Contenuto espandibile
          if (_isExpanded)
            Padding(
              padding: EdgeInsets.fromLTRB(
                kIsWindows ? 12 : 12.sp,
                0,
                kIsWindows ? 12 : 12.sp,
                kIsWindows ? 12 : 12.sp,
              ),
              child: Column(
                children: [
                  const Divider(),
                  Row(
                    children: [
                      Expanded(
                        child: OutlinedButton.icon(
                          onPressed: _showPackageDetails,
                          icon: const Icon(Symbols.visibility_rounded),
                          label: const Text('Dettagli'),
                        ),
                      ),
                      if (!isPaid && !widget.isOffline) ...[
                        SizedBox(width: kIsWindows ? 8 : 8.w),
                        Expanded(
                          child: FilledButton.icon(
                            onPressed: _showAddPaymentDialog,
                            icon: const Icon(Symbols.add_rounded),
                            label: const Text('Paga'),
                          ),
                        ),
                      ],
                    ],
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }
}

// ============================================================================
// SEZIONE: Fidelity (espandibile con azioni)
// ============================================================================
class _FidelitySection extends ConsumerWidget {
  const _FidelitySection({
    required this.clientId,
    required this.isExpanded,
    required this.onToggle,
    required this.onCreateFidelity,
    required this.isOffline,
  });

  final String clientId;
  final bool isExpanded;
  final VoidCallback onToggle;
  final VoidCallback onCreateFidelity;
  final bool isOffline;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final colorScheme = Theme.of(context).colorScheme;
    final cardsAsync = ref.watch(fidelityCardsByClientStreamProvider(clientId));

    return Card(
      clipBehavior: Clip.antiAlias,
      child: Column(
        children: [
          InkWell(
            onTap: onToggle,
            child: Padding(
              padding: EdgeInsets.all(kIsWindows ? 16 : 16.sp),
              child: Row(
                children: [
                  Icon(Symbols.style_rounded, color: colorScheme.primary),
                  SizedBox(width: kIsWindows ? 12 : 12.w),
                  Expanded(
                    child: Text(
                      'Carte Fidelity',
                      style: TextStyle(
                        fontSize: kIsWindows ? 18 : 18.sp,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                  if (!isOffline)
                    IconButton(
                      icon: const Icon(Symbols.add_rounded),
                      tooltip: 'Ricarica o crea carta',
                      onPressed: onCreateFidelity,
                    ),
                  Icon(
                    isExpanded
                        ? Symbols.expand_less_rounded
                        : Symbols.expand_more_rounded,
                    color: colorScheme.outline,
                  ),
                ],
              ),
            ),
          ),
          if (isExpanded)
            cardsAsync.when(
              data: (cards) {
                if (cards.isEmpty) {
                  return Padding(
                    padding: EdgeInsets.all(kIsWindows ? 24 : 24.sp),
                    child: Column(
                      children: [
                        Icon(
                          Symbols.style_rounded,
                          size: kIsWindows ? 48 : 48.sp,
                          color: colorScheme.outline,
                        ),
                        SizedBox(height: kIsWindows ? 12 : 12.h),
                        Text(
                          'Nessuna carta fidelity',
                          style: TextStyle(
                            color: colorScheme.outline,
                            fontSize: kIsWindows ? 16 : 16.sp,
                          ),
                        ),
                      ],
                    ),
                  );
                }

                return ConstrainedBox(
                  constraints: BoxConstraints(
                    maxHeight: MediaQuery.of(context).size.height * 0.5,
                  ),
                  child: ListView.separated(
                    shrinkWrap: true,
                    padding: EdgeInsets.fromLTRB(
                      kIsWindows ? 16 : 16.sp,
                      0,
                      kIsWindows ? 16 : 16.sp,
                      kIsWindows ? 16 : 16.sp,
                    ),
                    itemCount: cards.length,
                    separatorBuilder: (_, __) =>
                        SizedBox(height: kIsWindows ? 8 : 8.h),
                    itemBuilder: (context, index) {
                      final card = cards[index];
                      return _FidelityCard(card: card, isOffline: isOffline);
                    },
                  ),
                );
              },
              loading: () => const Padding(
                padding: EdgeInsets.all(24),
                child: Center(child: CircularProgressIndicator()),
              ),
              error: (error, _) => Padding(
                padding: const EdgeInsets.all(16),
                child: Text(
                  'Errore: $error',
                  style: TextStyle(color: colorScheme.error),
                ),
              ),
            ),
        ],
      ),
    );
  }
}

// ============================================================================
// WIDGET: Card Fidelity con azioni CRUD
// ============================================================================
class _FidelityCard extends ConsumerStatefulWidget {
  const _FidelityCard({required this.card, required this.isOffline});

  final FidelityCardData card;
  final bool isOffline;

  @override
  ConsumerState<_FidelityCard> createState() => _FidelityCardState();
}

class _FidelityCardState extends ConsumerState<_FidelityCard> {
  bool _isExpanded = false;

  Future<void> _showDetails() async {
    await showDialog<void>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('Carta ${widget.card.cardNumber}'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildDetailRow(
              context,
              'Stato',
              _mapFidelityStatus(widget.card.status),
            ),
            _buildDetailRow(
              context,
              'Bilancio',
              '€${widget.card.balance.toStringAsFixed(2)}',
            ),
            if (widget.card.isGift) ...[
              _buildDetailRow(context, 'Tipo', 'Carta Regalo'),
              if (widget.card.giftNote != null)
                _buildDetailRow(context, 'Nota regalo', widget.card.giftNote!),
            ],
            _buildDetailRow(
              context,
              'Creata',
              DateFormat('dd/MM/yyyy').format(widget.card.createdAt),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Chiudi'),
          ),
        ],
      ),
    );
  }

  Future<void> _toggleStatus() async {
    final newStatus = widget.card.status == 'active' ? 'suspended' : 'active';
    final action = widget.card.status == 'active' ? 'sospendere' : 'attivare';

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('${action.capitalize()} carta'),
        content: Text('Vuoi ${action} la carta ${widget.card.cardNumber}?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Annulla'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: Text(action.capitalize()),
          ),
        ],
      ),
    );

    if (confirmed != true || !mounted) return;

    try {
      await ref
          .read(fidelityActionsProvider)
          .updateFidelityCardStatus(id: widget.card.id, status: newStatus);
      if (mounted) {
        showCustomSnackBar(
          context: context,
          message: 'Carta ${newStatus == 'active' ? 'attivata' : 'sospesa'}',
          okColor: AppTabs.clients.color,
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Errore: $e')));
      }
    }
  }

  Future<void> _deleteCard() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Elimina carta fidelity'),
        content: Text(
          'Sei sicuro di voler eliminare la carta ${widget.card.cardNumber}? '
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
      await ref
          .read(fidelityActionsProvider)
          .deleteFidelityCard(widget.card.id);
      if (mounted) {
        showCustomSnackBar(
          context: context,
          message: 'Carta eliminata',
          okColor: AppTabs.clients.color,
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Errore eliminazione: $e')));
      }
    }
  }

  Future<void> _editCard() async {
    final notesController = TextEditingController(
      text: widget.card.giftNote ?? '',
    );

    final result = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Modifica note carta'),
        content: TextField(
          controller: notesController,
          maxLines: 3,
          decoration: const InputDecoration(
            labelText: 'Note',
            hintText: 'Inserisci note opzionali...',
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Annulla'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Salva'),
          ),
        ],
      ),
    );

    if (result != true || !mounted) return;

    try {
      await ref
          .read(fidelityActionsProvider)
          .updateFidelityCardNotes(
            id: widget.card.id,
            notes: notesController.text.trim().isEmpty
                ? null
                : notesController.text.trim(),
          );
      if (mounted) {
        showCustomSnackBar(
          context: context,
          message: 'Note aggiornate',
          okColor: AppTabs.clients.color,
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Errore: $e')));
      }
    }
  }

  String _mapFidelityStatus(String status) {
    switch (status) {
      case 'active':
        return 'Attiva';
      case 'suspended':
        return 'Sospesa';
      case 'exhausted':
        return 'Esaurita';
      default:
        return status;
    }
  }

  Color _getStatusColor(String status, ColorScheme colorScheme) {
    switch (status) {
      case 'active':
        return Colors.green;
      case 'suspended':
        return Colors.orange;
      case 'exhausted':
        return colorScheme.error;
      default:
        return colorScheme.outline;
    }
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final card = widget.card;
    final canManage = !widget.isOffline;

    return Card(
      margin: EdgeInsets.zero,
      child: Column(
        children: [
          InkWell(
            onTap: () => setState(() => _isExpanded = !_isExpanded),
            child: Padding(
              padding: EdgeInsets.all(kIsWindows ? 12 : 12.sp),
              child: Row(
                children: [
                  Icon(
                    Symbols.style_rounded,
                    color: card.isGift ? Colors.pink : colorScheme.primary,
                    size: kIsWindows ? 24 : 24.sp,
                  ),
                  SizedBox(width: kIsWindows ? 12 : 12.w),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          card.cardNumber,
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: kIsWindows ? 16 : 16.sp,
                          ),
                        ),
                        Text(
                          '${_mapFidelityStatus(card.status)}${card.isGift ? ' • Regalo' : ''}',
                          style: TextStyle(
                            fontSize: kIsWindows ? 12 : 12.sp,
                            color: _getStatusColor(card.status, colorScheme),
                          ),
                        ),
                      ],
                    ),
                  ),
                  Container(
                    padding: EdgeInsets.symmetric(
                      horizontal: kIsWindows ? 12 : 12.w,
                      vertical: kIsWindows ? 6 : 6.h,
                    ),
                    decoration: BoxDecoration(
                      color: card.balance > 0
                          ? Colors.green.withValues(alpha: 0.1)
                          : colorScheme.surfaceContainerHighest,
                      borderRadius: BorderRadius.circular(
                        kIsWindows ? 16 : 16.r,
                      ),
                    ),
                    child: Text(
                      '€${card.balance.toStringAsFixed(2)}',
                      style: TextStyle(
                        color: card.balance > 0
                            ? Colors.green
                            : colorScheme.outline,
                        fontWeight: FontWeight.bold,
                        fontSize: kIsWindows ? 16 : 16.sp,
                      ),
                    ),
                  ),
                  Icon(
                    _isExpanded
                        ? Symbols.expand_less_rounded
                        : Symbols.expand_more_rounded,
                    color: colorScheme.outline,
                  ),
                ],
              ),
            ),
          ),
          // Azioni espandibili
          if (_isExpanded)
            Padding(
              padding: EdgeInsets.fromLTRB(
                kIsWindows ? 12 : 12.sp,
                0,
                kIsWindows ? 12 : 12.sp,
                kIsWindows ? 12 : 12.sp,
              ),
              child: Column(
                children: [
                  const Divider(),
                  Row(
                    children: [
                      Expanded(
                        child: OutlinedButton.icon(
                          onPressed: _showDetails,
                          icon: const Icon(
                            Symbols.visibility_rounded,
                            size: 18,
                          ),
                          label: const Text('Dettagli'),
                        ),
                      ),
                      if (canManage) ...[
                        SizedBox(width: kIsWindows ? 8 : 8.w),
                        Expanded(
                          child: OutlinedButton.icon(
                            onPressed: _editCard,
                            icon: const Icon(Symbols.edit_rounded, size: 18),
                            label: const Text('Note'),
                          ),
                        ),
                      ],
                    ],
                  ),
                  if (canManage) ...[
                    SizedBox(height: kIsWindows ? 8 : 8.h),
                    Row(
                      children: [
                        Expanded(
                          child: FilledButton.icon(
                            onPressed: _toggleStatus,
                            icon: Icon(
                              card.status == 'active'
                                  ? Symbols.pause_rounded
                                  : Symbols.play_arrow_rounded,
                              size: 18,
                            ),
                            label: Text(
                              card.status == 'active' ? 'Sospendi' : 'Attiva',
                            ),
                            style: FilledButton.styleFrom(
                              backgroundColor: card.status == 'active'
                                  ? Colors.orange
                                  : Colors.green,
                            ),
                          ),
                        ),
                        SizedBox(width: kIsWindows ? 8 : 8.w),
                        Expanded(
                          child: OutlinedButton.icon(
                            onPressed: _deleteCard,
                            icon: const Icon(Symbols.delete_rounded, size: 18),
                            label: const Text('Elimina'),
                            style: OutlinedButton.styleFrom(
                              foregroundColor: colorScheme.error,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ],
                ],
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildDetailRow(
    BuildContext context,
    String label,
    String value, {
    bool isAmount = false,
  }) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            label,
            style: TextStyle(
              color: Theme.of(context).colorScheme.outline,
              fontSize: 12,
            ),
          ),
          Text(
            value,
            style: TextStyle(
              fontWeight: isAmount ? FontWeight.bold : FontWeight.normal,
              color: isAmount
                  ? Colors.green
                  : Theme.of(context).colorScheme.onSurface,
              fontSize: 12,
            ),
          ),
        ],
      ),
    );
  }
}

// ============================================================================
// SEZIONE: Prodotti (espandibile con azioni)
// ============================================================================
class _ProductsSection extends ConsumerWidget {
  const _ProductsSection({
    required this.clientId,
    required this.isExpanded,
    required this.onToggle,
    required this.onSellProduct,
    required this.isOffline,
  });

  final String clientId;
  final bool isExpanded;
  final VoidCallback onToggle;
  final VoidCallback onSellProduct;
  final bool isOffline;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final colorScheme = Theme.of(context).colorScheme;
    final salesAsync = ref.watch(productSalesByClientStreamProvider(clientId));

    return Card(
      clipBehavior: Clip.antiAlias,
      child: Column(
        children: [
          InkWell(
            onTap: onToggle,
            child: Padding(
              padding: EdgeInsets.all(kIsWindows ? 16 : 16.sp),
              child: Row(
                children: [
                  Icon(
                    Symbols.shopping_bag_rounded,
                    color: colorScheme.primary,
                  ),
                  SizedBox(width: kIsWindows ? 12 : 12.w),
                  Expanded(
                    child: Text(
                      'Prodotti Acquistati',
                      style: TextStyle(
                        fontSize: kIsWindows ? 18 : 18.sp,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                  if (!isOffline)
                    IconButton(
                      icon: const Icon(Symbols.add_rounded),
                      tooltip: 'Vendi prodotto',
                      onPressed: onSellProduct,
                    ),
                  Icon(
                    isExpanded
                        ? Symbols.expand_less_rounded
                        : Symbols.expand_more_rounded,
                    color: colorScheme.outline,
                  ),
                ],
              ),
            ),
          ),
          if (isExpanded)
            salesAsync.when(
              data: (sales) {
                if (sales.isEmpty) {
                  return Padding(
                    padding: EdgeInsets.all(kIsWindows ? 24 : 24.sp),
                    child: Column(
                      children: [
                        Icon(
                          Symbols.shopping_bag_rounded,
                          size: kIsWindows ? 48 : 48.sp,
                          color: colorScheme.outline,
                        ),
                        SizedBox(height: kIsWindows ? 12 : 12.h),
                        Text(
                          'Nessun prodotto acquistato',
                          style: TextStyle(
                            color: colorScheme.outline,
                            fontSize: kIsWindows ? 16 : 16.sp,
                          ),
                        ),
                      ],
                    ),
                  );
                }

                return ConstrainedBox(
                  constraints: BoxConstraints(
                    maxHeight: MediaQuery.of(context).size.height * 0.5,
                  ),
                  child: ListView.separated(
                    shrinkWrap: true,
                    padding: EdgeInsets.fromLTRB(
                      kIsWindows ? 16 : 16.sp,
                      0,
                      kIsWindows ? 16 : 16.sp,
                      kIsWindows ? 16 : 16.sp,
                    ),
                    itemCount: sales.length,
                    separatorBuilder: (_, __) =>
                        SizedBox(height: kIsWindows ? 8 : 8.h),
                    itemBuilder: (context, index) {
                      final sale = sales[index];
                      return Card(
                        margin: EdgeInsets.zero,
                        child: ListTile(
                          leading: Icon(
                            Symbols.shopping_bag_rounded,
                            color: colorScheme.primary,
                          ),
                          title: Text(sale.lockedProductName),
                          subtitle: Text(
                            'Qtà: ${sale.quantity} • ${_formatDate(sale.createdAt)}',
                          ),
                          trailing: Text(
                            '€${sale.lineTotal.toStringAsFixed(2)}',
                            style: TextStyle(
                              fontWeight: FontWeight.bold,
                              fontSize: kIsWindows ? 16 : 16.sp,
                            ),
                          ),
                        ),
                      );
                    },
                  ),
                );
              },
              loading: () => const Padding(
                padding: EdgeInsets.all(24),
                child: Center(child: CircularProgressIndicator()),
              ),
              error: (error, _) => Padding(
                padding: const EdgeInsets.all(16),
                child: Text(
                  'Errore: $error',
                  style: TextStyle(color: colorScheme.error),
                ),
              ),
            ),
        ],
      ),
    );
  }

  String _formatDate(DateTime date) {
    return '${date.day.toString().padLeft(2, '0')}/${date.month.toString().padLeft(2, '0')}/${date.year}';
  }
}

// ============================================================================
// SEZIONE: Alert Scadenze Pacchetti
// ============================================================================
class _PackageAlertsSection extends ConsumerWidget {
  const _PackageAlertsSection({required this.clientId});

  final String clientId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final colorScheme = Theme.of(context).colorScheme;
    final alertsAsync = ref.watch(
      clientPackageExpirationAlertsProvider(clientId),
    );

    return alertsAsync.when(
      data: (alerts) {
        if (alerts.isEmpty) return const SizedBox.shrink();

        return Card(
          clipBehavior: Clip.antiAlias,
          color: alerts.any((a) => a.isExpired)
              ? colorScheme.errorContainer
              : (alerts.any((a) => a.isExpiringSoon)
                    ? Colors.orange.withValues(alpha: 0.1)
                    : Colors.yellow.withValues(alpha: 0.1)),
          child: ExpansionTile(
            leading: Icon(
              Symbols.warning_rounded,
              color: alerts.any((a) => a.isExpired)
                  ? colorScheme.error
                  : (alerts.any((a) => a.isExpiringSoon)
                        ? Colors.orange
                        : Colors.amber),
            ),
            title: Text(
              'Alert Scadenze (${alerts.length})',
              style: TextStyle(
                fontWeight: FontWeight.bold,
                color: alerts.any((a) => a.isExpired)
                    ? colorScheme.error
                    : null,
              ),
            ),
            subtitle: alerts.any((a) => a.isExpired)
                ? Text(
                    '${alerts.where((a) => a.isExpired).length} pacchetto/i scaduto/i',
                    style: TextStyle(color: colorScheme.error),
                  )
                : alerts.any((a) => a.isExpiringSoon)
                ? const Text('Alcuni pacchetti scadono a breve')
                : const Text('Pacchetti in scadenza'),
            children: [
              ConstrainedBox(
                constraints: BoxConstraints(
                  maxHeight: MediaQuery.of(context).size.height * 0.4,
                ),
                child: ListView.separated(
                  shrinkWrap: true,
                  padding: EdgeInsets.fromLTRB(
                    kIsWindows ? 16 : 16.sp,
                    0,
                    kIsWindows ? 16 : 16.sp,
                    kIsWindows ? 16 : 16.sp,
                  ),
                  itemCount: alerts.length,
                  separatorBuilder: (_, __) =>
                      SizedBox(height: kIsWindows ? 8 : 8.h),
                  itemBuilder: (context, index) {
                    final alert = alerts[index];
                    return _AlertCard(alert: alert);
                  },
                ),
              ),
            ],
          ),
        );
      },
      loading: () => const SizedBox.shrink(),
      error: (_, __) => const SizedBox.shrink(),
    );
  }
}

class _AlertCard extends StatelessWidget {
  const _AlertCard({required this.alert});

  final PackageExpirationAlert alert;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final isExpired = alert.isExpired;
    final isExpiringSoon = alert.isExpiringSoon;

    return Card(
      margin: EdgeInsets.zero,
      color: isExpired
          ? cs.errorContainer.withValues(alpha: 0.5)
          : (isExpiringSoon ? Colors.orange.withValues(alpha: 0.1) : null),
      child: ListTile(
        leading: Icon(
          isExpired
              ? Symbols.error_rounded
              : (isExpiringSoon
                    ? Symbols.warning_rounded
                    : Symbols.schedule_rounded),
          color: isExpired
              ? cs.error
              : (isExpiringSoon ? Colors.orange : Colors.amber),
        ),
        title: Text(
          alert.packageName,
          style: const TextStyle(fontWeight: FontWeight.w500),
        ),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              isExpired
                  ? 'Scaduto da ${alert.daysUntilExpiration.abs()} giorni'
                  : 'Scade tra ${alert.daysUntilExpiration} giorni',
              style: TextStyle(
                color: isExpired
                    ? cs.error
                    : (isExpiringSoon ? Colors.orange : null),
              ),
            ),
            Text(
              'Sedute rimanenti: ${alert.remainingSessions}/${alert.totalSessions}',
            ),
          ],
        ),
        trailing: isExpired
            ? Chip(
                label: const Text('SCADUTO'),
                backgroundColor: cs.error,
                labelStyle: TextStyle(color: cs.onError, fontSize: 10),
              )
            : isExpiringSoon
            ? Chip(
                label: const Text('URGENTE'),
                backgroundColor: Colors.orange,
                labelStyle: const TextStyle(color: Colors.white, fontSize: 10),
              )
            : null,
        onTap: () {
          Navigator.push<void>(
            context,
            MaterialPageRoute(
              builder: (_) => PackageDetailsPage(packageId: alert.packageId),
            ),
          );
        },
      ),
    );
  }
}

// ============================================================================
// SEZIONE: Statistiche Cliente
// ============================================================================
class _StatisticsSection extends ConsumerWidget {
  const _StatisticsSection({
    required this.clientId,
    required this.isExpanded,
    required this.onToggle,
  });

  final String clientId;
  final bool isExpanded;
  final VoidCallback onToggle;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final colorScheme = Theme.of(context).colorScheme;
    final statsAsync = ref.watch(clientStatisticsProvider(clientId));

    return Card(
      clipBehavior: Clip.antiAlias,
      child: Column(
        children: [
          InkWell(
            onTap: onToggle,
            child: Padding(
              padding: EdgeInsets.all(kIsWindows ? 16 : 16.sp),
              child: Row(
                children: [
                  Icon(Symbols.analytics_rounded, color: colorScheme.primary),
                  SizedBox(width: kIsWindows ? 12 : 12.w),
                  Expanded(
                    child: Text(
                      'Statistiche',
                      style: TextStyle(
                        fontSize: kIsWindows ? 18 : 18.sp,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                  Icon(
                    isExpanded
                        ? Symbols.expand_less_rounded
                        : Symbols.expand_more_rounded,
                    color: colorScheme.outline,
                  ),
                ],
              ),
            ),
          ),
          if (isExpanded)
            statsAsync.when(
              data: (stats) => Padding(
                padding: EdgeInsets.fromLTRB(
                  kIsWindows ? 16 : 16.sp,
                  0,
                  kIsWindows ? 16 : 16.sp,
                  kIsWindows ? 16 : 16.sp,
                ),
                child: Column(
                  children: [
                    // Riga 1: Spesa totale e saldo fidelity
                    Row(
                      children: [
                        Expanded(
                          child: _StatCard(
                            label: 'Spesa Totale',
                            value: '€${stats.totalSpent.toStringAsFixed(2)}',
                            icon: Symbols.payments_rounded,
                            color: Colors.green,
                          ),
                        ),
                        SizedBox(width: kIsWindows ? 8 : 8.w),
                        Expanded(
                          child: _StatCard(
                            label: 'Saldo Fidelity',
                            value:
                                '€${stats.totalFidelityBalance.toStringAsFixed(2)}',
                            icon: Symbols.card_membership_rounded,
                            color: Colors.blue,
                          ),
                        ),
                      ],
                    ),
                    SizedBox(height: kIsWindows ? 8 : 8.h),
                    // Riga 2: Appuntamenti
                    Row(
                      children: [
                        Expanded(
                          child: _StatCard(
                            label: 'Visite Totali',
                            value: '${stats.totalAppointments}',
                            icon: Symbols.event_rounded,
                            color: Colors.purple,
                          ),
                        ),
                        SizedBox(width: kIsWindows ? 8 : 8.w),
                        Expanded(
                          child: _StatCard(
                            label: 'Questo Mese',
                            value: '${stats.appointmentsThisMonth}',
                            icon: Symbols.calendar_month_rounded,
                            color: Colors.orange,
                          ),
                        ),
                      ],
                    ),
                    SizedBox(height: kIsWindows ? 8 : 8.h),
                    // Riga 3: Pacchetti
                    Row(
                      children: [
                        Expanded(
                          child: _StatCard(
                            label: 'Pacchetti Attivi',
                            value: '${stats.activePackages}',
                            icon: Symbols.inventory_2_rounded,
                            color: Colors.teal,
                          ),
                        ),
                        SizedBox(width: kIsWindows ? 8 : 8.w),
                        Expanded(
                          child: _StatCard(
                            label: 'Pacchetti Completati',
                            value: '${stats.completedPackages}',
                            icon: Symbols.check_circle_rounded,
                            color: Colors.indigo,
                          ),
                        ),
                      ],
                    ),
                    SizedBox(height: kIsWindows ? 8 : 8.h),
                    // Riga 4: Preventivi e prodotti
                    Row(
                      children: [
                        Expanded(
                          child: _StatCard(
                            label: 'Preventivi Accettati',
                            value:
                                '${stats.acceptedQuotes}/${stats.totalQuotes}',
                            icon: Symbols.description_rounded,
                            color: Colors.cyan,
                          ),
                        ),
                        SizedBox(width: kIsWindows ? 8 : 8.w),
                        Expanded(
                          child: _StatCard(
                            label: 'Prodotti Acquistati',
                            value: '${stats.totalProductsPurchased}',
                            icon: Symbols.shopping_bag_rounded,
                            color: Colors.pink,
                          ),
                        ),
                      ],
                    ),
                    if (stats.lastVisitDate != null) ...[
                      SizedBox(height: kIsWindows ? 16 : 16.h),
                      Container(
                        padding: EdgeInsets.all(kIsWindows ? 12 : 12.sp),
                        decoration: BoxDecoration(
                          color: colorScheme.surfaceContainerHighest.withValues(
                            alpha: 0.3,
                          ),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Row(
                          children: [
                            Icon(
                              Symbols.history_rounded,
                              color: colorScheme.outline,
                              size: kIsWindows ? 20 : 20.sp,
                            ),
                            SizedBox(width: kIsWindows ? 12 : 12.w),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    'Ultima visita: ${_formatDate(stats.lastVisitDate!)}',
                                    style: const TextStyle(
                                      fontWeight: FontWeight.w500,
                                    ),
                                  ),
                                  if (stats.daysSinceLastVisit != null)
                                    Text(
                                      stats.daysSinceLastVisit == 0
                                          ? 'Oggi'
                                          : '${stats.daysSinceLastVisit} giorni fa',
                                      style: TextStyle(
                                        fontSize: 12,
                                        color: colorScheme.outline,
                                      ),
                                    ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ],
                ),
              ),
              loading: () => const Padding(
                padding: EdgeInsets.all(24),
                child: Center(child: CircularProgressIndicator()),
              ),
              error: (error, _) => Padding(
                padding: const EdgeInsets.all(16),
                child: Text(
                  'Errore: $error',
                  style: TextStyle(color: colorScheme.error),
                ),
              ),
            ),
        ],
      ),
    );
  }

  String _formatDate(DateTime date) {
    return '${date.day.toString().padLeft(2, '0')}/${date.month.toString().padLeft(2, '0')}/${date.year}';
  }
}

class _StatCard extends StatelessWidget {
  const _StatCard({
    required this.label,
    required this.value,
    required this.icon,
    required this.color,
  });

  final String label;
  final String value;
  final IconData icon;
  final Color color;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Card(
      margin: EdgeInsets.zero,
      child: Padding(
        padding: EdgeInsets.all(kIsWindows ? 12 : 12.sp),
        child: Column(
          children: [
            Icon(icon, color: color, size: kIsWindows ? 24 : 24.sp),
            SizedBox(height: kIsWindows ? 4 : 4.h),
            Text(
              value,
              style: TextStyle(
                fontWeight: FontWeight.bold,
                fontSize: kIsWindows ? 16 : 16.sp,
                color: color,
              ),
            ),
            Text(
              label,
              style: TextStyle(
                fontSize: kIsWindows ? 11 : 11.sp,
                color: cs.outline,
              ),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }
}

// ============================================================================
// SEZIONE: Preferenze (Servizi & Prodotti)
// ============================================================================
class _PreferencesSection extends ConsumerWidget {
  const _PreferencesSection({
    required this.clientId,
    required this.isExpanded,
    required this.onToggle,
  });

  final String clientId;
  final bool isExpanded;
  final VoidCallback onToggle;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final colorScheme = Theme.of(context).colorScheme;
    final servicesAsync = ref.watch(clientServicePreferencesProvider(clientId));
    final productsAsync = ref.watch(clientProductPreferencesProvider(clientId));

    return Card(
      clipBehavior: Clip.antiAlias,
      child: Column(
        children: [
          InkWell(
            onTap: onToggle,
            child: Padding(
              padding: EdgeInsets.all(kIsWindows ? 16 : 16.sp),
              child: Row(
                children: [
                  Icon(Symbols.favorite_rounded, color: colorScheme.primary),
                  SizedBox(width: kIsWindows ? 12 : 12.w),
                  Expanded(
                    child: Text(
                      'Preferenze',
                      style: TextStyle(
                        fontSize: kIsWindows ? 18 : 18.sp,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                  Icon(
                    isExpanded
                        ? Symbols.expand_less_rounded
                        : Symbols.expand_more_rounded,
                    color: colorScheme.outline,
                  ),
                ],
              ),
            ),
          ),
          if (isExpanded)
            Padding(
              padding: EdgeInsets.fromLTRB(
                kIsWindows ? 16 : 16.sp,
                0,
                kIsWindows ? 16 : 16.sp,
                kIsWindows ? 16 : 16.sp,
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Servizi preferiti
                  Text(
                    'Servizi più utilizzati',
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: kIsWindows ? 14 : 14.sp,
                    ),
                  ),
                  SizedBox(height: kIsWindows ? 8 : 8.h),
                  servicesAsync.when(
                    data: (services) {
                      if (services.isEmpty) {
                        return Text(
                          'Nessun servizio registrato',
                          style: TextStyle(
                            color: colorScheme.outline,
                            fontSize: kIsWindows ? 12 : 12.sp,
                          ),
                        );
                      }
                      return Wrap(
                        spacing: kIsWindows ? 8 : 8.w,
                        runSpacing: kIsWindows ? 8 : 8.h,
                        children: services
                            .take(5)
                            .map(
                              (s) => Chip(
                                avatar: Icon(
                                  Symbols.spa_rounded,
                                  size: kIsWindows ? 16 : 16.sp,
                                ),
                                label: Text(
                                  '${s.serviceName} (${s.usedSessions}/${s.totalSessions})',
                                ),
                                backgroundColor: colorScheme.primaryContainer
                                    .withValues(alpha: 0.5),
                              ),
                            )
                            .toList(),
                      );
                    },
                    loading: () => const SizedBox(
                      height: 20,
                      child: LinearProgressIndicator(),
                    ),
                    error: (_, __) => const SizedBox.shrink(),
                  ),
                  SizedBox(height: kIsWindows ? 16 : 16.h),
                  // Prodotti preferiti
                  Text(
                    'Prodotti più acquistati',
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: kIsWindows ? 14 : 14.sp,
                    ),
                  ),
                  SizedBox(height: kIsWindows ? 8 : 8.h),
                  productsAsync.when(
                    data: (products) {
                      if (products.isEmpty) {
                        return Text(
                          'Nessun prodotto acquistato',
                          style: TextStyle(
                            color: colorScheme.outline,
                            fontSize: kIsWindows ? 12 : 12.sp,
                          ),
                        );
                      }
                      return Wrap(
                        spacing: kIsWindows ? 8 : 8.w,
                        runSpacing: kIsWindows ? 8 : 8.h,
                        children: products
                            .take(5)
                            .map(
                              (p) => Chip(
                                avatar: Icon(
                                  Symbols.shopping_bag_rounded,
                                  size: kIsWindows ? 16 : 16.sp,
                                ),
                                label: Text(
                                  '${p.productName} (${p.totalQuantity})',
                                ),
                                backgroundColor: colorScheme.secondaryContainer
                                    .withValues(alpha: 0.5),
                              ),
                            )
                            .toList(),
                      );
                    },
                    loading: () => const SizedBox(
                      height: 20,
                      child: LinearProgressIndicator(),
                    ),
                    error: (_, __) => const SizedBox.shrink(),
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }
}

// ============================================================================
// SEZIONE: Grafici Statistiche
// ============================================================================
class _ChartsSection extends ConsumerWidget {
  const _ChartsSection({
    required this.clientId,
    required this.isExpanded,
    required this.onToggle,
  });

  final String clientId;
  final bool isExpanded;
  final VoidCallback onToggle;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final colorScheme = Theme.of(context).colorScheme;
    final spendingAsync = ref.watch(clientMonthlySpendingProvider(clientId));
    final serviceDistAsync = ref.watch(
      clientServiceDistributionProvider(clientId),
    );

    return Card(
      clipBehavior: Clip.antiAlias,
      child: Column(
        children: [
          InkWell(
            onTap: onToggle,
            child: Padding(
              padding: EdgeInsets.all(kIsWindows ? 16 : 16.sp),
              child: Row(
                children: [
                  Icon(
                    Symbols.insert_chart_rounded,
                    color: colorScheme.primary,
                  ),
                  SizedBox(width: kIsWindows ? 12 : 12.w),
                  Expanded(
                    child: Text(
                      'Grafici Statistiche',
                      style: TextStyle(
                        fontSize: kIsWindows ? 18 : 18.sp,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                  Icon(
                    isExpanded
                        ? Symbols.expand_less_rounded
                        : Symbols.expand_more_rounded,
                    color: colorScheme.outline,
                  ),
                ],
              ),
            ),
          ),
          if (isExpanded)
            spendingAsync.when(
              data: (List<MonthlySpendingData> spendingData) {
                return Padding(
                  padding: EdgeInsets.fromLTRB(
                    kIsWindows ? 16 : 16.sp,
                    0,
                    kIsWindows ? 16 : 16.sp,
                    kIsWindows ? 16 : 16.sp,
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Grafico Andamento Spese Mensili
                      Text(
                        'Andamento Spese (ultimi 12 mesi)',
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: kIsWindows ? 14 : 14.sp,
                        ),
                      ),
                      SizedBox(height: kIsWindows ? 16 : 16.h),
                      SizedBox(
                        height: kIsWindows ? 200 : 200.h,
                        child: _buildSpendingChart(spendingData, colorScheme),
                      ),
                      SizedBox(height: kIsWindows ? 24 : 24.h),
                      // Grafico Distribuzione Servizi
                      serviceDistAsync.when(
                        data: (List<ServiceUsageData> services) {
                          if (services.isEmpty) return const SizedBox.shrink();
                          final totalSessions = services.fold<int>(
                            0,
                            (int sum, ServiceUsageData s) => sum + s.sessions,
                          );
                          final servicesWithPercentage = services
                              .map(
                                (s) => ServiceUsageData(
                                  serviceName: s.serviceName,
                                  sessions: s.sessions,
                                  percentage: totalSessions > 0
                                      ? (s.sessions / totalSessions) * 100
                                      : 0,
                                ),
                              )
                              .toList();
                          return Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'Distribuzione Servizi',
                                style: TextStyle(
                                  fontWeight: FontWeight.bold,
                                  fontSize: kIsWindows ? 14 : 14.sp,
                                ),
                              ),
                              SizedBox(height: kIsWindows ? 16 : 16.h),
                              SizedBox(
                                height: kIsWindows ? 200 : 200.h,
                                child: _buildServicePieChart(
                                  servicesWithPercentage.take(5).toList(),
                                  colorScheme,
                                ),
                              ),
                            ],
                          );
                        },
                        loading: () => const SizedBox(
                          height: 100,
                          child: Center(child: CircularProgressIndicator()),
                        ),
                        error: (_, __) => const SizedBox.shrink(),
                      ),
                    ],
                  ),
                );
              },
              loading: () => const Padding(
                padding: EdgeInsets.all(24),
                child: Center(child: CircularProgressIndicator()),
              ),
              error: (Object error, _) => Padding(
                padding: const EdgeInsets.all(16),
                child: Text(
                  'Errore: $error',
                  style: TextStyle(color: colorScheme.error),
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildSpendingChart(List<MonthlySpendingData> data, ColorScheme cs) {
    final maxAmount = data.isNotEmpty
        ? data.map((d) => d.amount).reduce((a, b) => a > b ? a : b)
        : 0;
    final interval = maxAmount > 0 ? maxAmount / 5 : 100;

    return BarChart(
      BarChartData(
        alignment: BarChartAlignment.spaceAround,
        maxY: maxAmount * 1.2,
        barTouchData: BarTouchData(
          touchTooltipData: BarTouchTooltipData(
            getTooltipColor: (_) => cs.inverseSurface,
            getTooltipItem: (group, groupIndex, rod, rodIndex) {
              final item = data[groupIndex];
              return BarTooltipItem(
                '${item.monthName} ${item.year}\n€${item.amount.toStringAsFixed(2)}',
                TextStyle(color: cs.onInverseSurface, fontSize: 12),
              );
            },
          ),
        ),
        titlesData: FlTitlesData(
          show: true,
          leftTitles: AxisTitles(
            sideTitles: SideTitles(
              showTitles: true,
              reservedSize: 40,
              interval: interval.toDouble(),
              getTitlesWidget: (value, meta) => Text(
                '€${value.toInt()}',
                style: TextStyle(fontSize: 10, color: cs.outline),
              ),
            ),
          ),
          bottomTitles: AxisTitles(
            sideTitles: SideTitles(
              showTitles: true,
              getTitlesWidget: (value, meta) {
                if (value.toInt() >= 0 && value.toInt() < data.length) {
                  return Text(
                    data[value.toInt()].monthName,
                    style: TextStyle(fontSize: 10, color: cs.outline),
                  );
                }
                return const Text('');
              },
            ),
          ),
          rightTitles: const AxisTitles(
            sideTitles: SideTitles(showTitles: false),
          ),
          topTitles: const AxisTitles(
            sideTitles: SideTitles(showTitles: false),
          ),
        ),
        gridData: FlGridData(
          show: true,
          drawVerticalLine: false,
          horizontalInterval: interval.toDouble(),
          getDrawingHorizontalLine: (value) =>
              FlLine(color: cs.outline.withValues(alpha: 0.2), strokeWidth: 1),
        ),
        borderData: FlBorderData(show: false),
        barGroups: data.asMap().entries.map((entry) {
          return BarChartGroupData(
            x: entry.key,
            barRods: [
              BarChartRodData(
                toY: entry.value.amount,
                color: entry.value.amount > 0
                    ? cs.primary
                    : cs.outline.withValues(alpha: 0.3),
                width: 16,
                borderRadius: const BorderRadius.vertical(
                  top: Radius.circular(4),
                ),
              ),
            ],
          );
        }).toList(),
      ),
    );
  }

  Widget _buildServicePieChart(
    List<ServiceUsageData> services,
    ColorScheme cs,
  ) {
    final colors = [
      Colors.blue,
      Colors.green,
      Colors.orange,
      Colors.purple,
      Colors.red,
    ];

    return Row(
      children: [
        Expanded(
          flex: 2,
          child: PieChart(
            PieChartData(
              sectionsSpace: 2,
              centerSpaceRadius: 30,
              sections: services.asMap().entries.map((entry) {
                final index = entry.key;
                final service = entry.value;
                return PieChartSectionData(
                  color: colors[index % colors.length],
                  value: service.sessions.toDouble(),
                  title: '${service.percentage.toStringAsFixed(0)}%',
                  radius: 60,
                  titleStyle: const TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                  ),
                );
              }).toList(),
            ),
          ),
        ),
        Expanded(
          flex: 3,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisAlignment: MainAxisAlignment.center,
            children: services.asMap().entries.map((entry) {
              final index = entry.key;
              final service = entry.value;
              return Padding(
                padding: const EdgeInsets.symmetric(vertical: 2),
                child: Row(
                  children: [
                    Container(
                      width: 12,
                      height: 12,
                      decoration: BoxDecoration(
                        color: colors[index % colors.length],
                        shape: BoxShape.circle,
                      ),
                    ),
                    SizedBox(width: kIsWindows ? 8 : 8.w),
                    Expanded(
                      child: Text(
                        '${service.serviceName} (${service.sessions})',
                        style: TextStyle(fontSize: kIsWindows ? 11 : 11.sp),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ],
                ),
              );
            }).toList(),
          ),
        ),
      ],
    );
  }
}

// ============================================================================
// SEZIONE: Calendario Appuntamenti
// ============================================================================
class _CalendarSection extends ConsumerWidget {
  const _CalendarSection({
    required this.clientId,
    required this.isExpanded,
    required this.onToggle,
    required this.selectedMonth,
    required this.selectedDate,
    required this.onMonthChanged,
    required this.onDateSelected,
  });

  final String clientId;
  final bool isExpanded;
  final VoidCallback onToggle;
  final DateTime selectedMonth;
  final DateTime? selectedDate;
  final void Function(DateTime) onMonthChanged;
  final void Function(DateTime?) onDateSelected;

  Future<void> _showPaymentDetails(
    BuildContext context,
    WidgetRef ref,
    PaymentData payment,
  ) async {
    // Fetch related data
    String? packageName;
    String? productName;
    String? appointmentDetails;
    PackageData? packageData;
    ProductSaleData? saleData;
    AppointmentData? appointmentData;

    if (payment.packageId != null) {
      packageData = await ref
          .read(packagesActionsProvider)
          .getPackageById(payment.packageId!);
      packageName = packageData?.name;
    }

    if (payment.productSaleId != null) {
      // Get product sale data from repository
      final sales = await ref
          .read(productSalesActionsProvider)
          .getProductSalesByClientId(clientId);
      saleData = sales.cast<ProductSaleData?>().firstWhere(
        (s) => s?.id == payment.productSaleId,
        orElse: () => null,
      );
      productName = saleData?.lockedProductName;
    }

    if (payment.appointmentId != null) {
      appointmentData = await ref
          .read(appointmentActionsProvider)
          .getById(payment.appointmentId!);

      if (appointmentData != null) {
        final services = await ref
            .read(appointmentActionsProvider)
            .getAppointmentServicesByAppointmentId(payment.appointmentId!);

        // Fetch service names since AppointmentServiceData doesn't have lockedServiceName
        final serviceNames = <String>[];
        for (final service in services) {
          final serviceData = await ref
              .read(servicesActionsProvider)
              .getServiceById(service.serviceId);
          if (serviceData != null) {
            serviceNames.add(serviceData.name);
          }
        }

        final servicesList = serviceNames.join(', ');
        final date = _formatDateTime(appointmentData.startDateTime);
        appointmentDetails = '$date - $servicesList';
      }
    }

    if (!context.mounted) return;

    showDialog<void>(
      context: context,
      builder: (context) => AlertDialog(
        title: Row(
          children: [
            Icon(Icons.payment, color: Colors.green),
            const SizedBox(width: 12),
            const Text('Dettaglio Pagamento'),
          ],
        ),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Payment Information
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Theme.of(
                    context,
                  ).colorScheme.primaryContainer.withValues(alpha: 0.2),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Informazioni Pagamento',
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        color: Theme.of(context).colorScheme.primary,
                      ),
                    ),
                    const SizedBox(height: 8),
                    _buildDetailRow(
                      context,
                      'Importo',
                      '€${payment.amount.toStringAsFixed(2)}',
                      isAmount: true,
                    ),
                    _buildDetailRow(context, 'Metodo', payment.paymentMethod),
                    _buildDetailRow(
                      context,
                      'Data',
                      _formatDateTime(payment.paidAt),
                    ),
                    if (payment.notes != null && payment.notes!.isNotEmpty)
                      _buildDetailRow(context, 'Note', payment.notes!),
                  ],
                ),
              ),

              const SizedBox(height: 16),

              // Related Entity Information
              if (packageName != null ||
                  productName != null ||
                  appointmentDetails != null) ...[
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: Theme.of(context).colorScheme.surfaceContainerHighest
                        .withValues(alpha: 0.3),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Dettagli Acquisto',
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          color: Theme.of(context).colorScheme.onSurface,
                        ),
                      ),
                      const SizedBox(height: 8),
                      if (packageName != null) ...[
                        _buildDetailRow(context, 'Pacchetto', packageName),
                        if (packageData != null) ...[
                          _buildDetailRow(
                            context,
                            'Totale Pacchetto',
                            '€${packageData.totalPrice.toStringAsFixed(2)}',
                          ),
                          _buildDetailRow(
                            context,
                            'Già Pagato',
                            '€${packageData.paidAmount.toStringAsFixed(2)}',
                          ),
                          _buildDetailRow(
                            context,
                            'Rimanente',
                            '€${(packageData.totalPrice - packageData.paidAmount).toStringAsFixed(2)}',
                          ),
                        ],
                      ],
                      if (productName != null) ...[
                        _buildDetailRow(context, 'Prodotto', productName),
                        if (saleData != null) ...[
                          _buildDetailRow(
                            context,
                            'Quantità',
                            '${saleData.quantity}',
                          ),
                          _buildDetailRow(
                            context,
                            'Prezzo Unitario',
                            '€${saleData.lockedPrice.toStringAsFixed(2)}',
                          ),
                        ],
                      ],
                      if (appointmentDetails != null)
                        _buildDetailRow(
                          context,
                          'Appuntamento',
                          appointmentDetails,
                        ),
                    ],
                  ),
                ),
              ],
            ],
          ),
        ),
        actions: [
          if (packageData != null)
            TextButton.icon(
              icon: const Icon(Symbols.inventory_2_rounded),
              label: const Text('Vai al pacchetto'),
              onPressed: () {
                Navigator.pop(context);
                Navigator.push<void>(
                  context,
                  MaterialPageRoute(
                    builder: (_) =>
                        PackageDetailsPage(packageId: packageData!.id),
                  ),
                );
              },
            ),
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Chiudi'),
          ),
        ],
      ),
    );
  }

  String _formatDateTime(DateTime dateTime) {
    return '${dateTime.day.toString().padLeft(2, '0')}/${dateTime.month.toString().padLeft(2, '0')}/${dateTime.year} ${dateTime.hour.toString().padLeft(2, '0')}:${dateTime.minute.toString().padLeft(2, '0')}';
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final colorScheme = Theme.of(context).colorScheme;
    final appointmentsAsync = ref.watch(
      clientAppointmentsStreamProvider(clientId),
    );
    final paymentsAsync = ref.watch(paymentsByClientStreamProvider(clientId));

    return Card(
      clipBehavior: Clip.antiAlias,
      child: Column(
        children: [
          InkWell(
            onTap: onToggle,
            child: Padding(
              padding: EdgeInsets.all(kIsWindows ? 16 : 16.sp),
              child: Row(
                children: [
                  Icon(
                    Symbols.calendar_month_rounded,
                    color: colorScheme.primary,
                  ),
                  SizedBox(width: kIsWindows ? 12 : 12.w),
                  Expanded(
                    child: Text(
                      'Calendario Appuntamenti',
                      style: TextStyle(
                        fontSize: kIsWindows ? 18 : 18.sp,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                  Icon(
                    isExpanded
                        ? Symbols.expand_less_rounded
                        : Symbols.expand_more_rounded,
                    color: colorScheme.outline,
                  ),
                ],
              ),
            ),
          ),
          if (isExpanded)
            appointmentsAsync.when(
              data: (appointments) {
                final payments = paymentsAsync.value ?? [];
                final daysInMonth = DateTime(
                  selectedMonth.year,
                  selectedMonth.month + 1,
                  0,
                ).day;
                final firstWeekday =
                    DateTime(
                      selectedMonth.year,
                      selectedMonth.month,
                      1,
                    ).weekday %
                    7;

                return Column(
                  children: [
                    // Header mese con navigazione
                    Padding(
                      padding: EdgeInsets.symmetric(
                        horizontal: kIsWindows ? 16 : 16.sp,
                      ),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          IconButton(
                            icon: const Icon(Symbols.chevron_left_rounded),
                            onPressed: () => onMonthChanged(
                              DateTime(
                                selectedMonth.year,
                                selectedMonth.month - 1,
                              ),
                            ),
                          ),
                          Text(
                            DateFormat(
                              'MMMM yyyy',
                              'it',
                            ).format(selectedMonth).toUpperCase(),
                            style: TextStyle(
                              fontWeight: FontWeight.bold,
                              fontSize: kIsWindows ? 16 : 16.sp,
                            ),
                          ),
                          IconButton(
                            icon: const Icon(Symbols.chevron_right_rounded),
                            onPressed: () => onMonthChanged(
                              DateTime(
                                selectedMonth.year,
                                selectedMonth.month + 1,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                    // Griglia calendario
                    Padding(
                      padding: EdgeInsets.symmetric(
                        horizontal: kIsWindows ? 16 : 16.sp,
                      ),
                      child: Column(
                        children: [
                          // Giorni della settimana
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceAround,
                            children:
                                [
                                      'Dom',
                                      'Lun',
                                      'Mar',
                                      'Mer',
                                      'Gio',
                                      'Ven',
                                      'Sab',
                                    ]
                                    .map(
                                      (day) => Expanded(
                                        child: Center(
                                          child: Text(
                                            day,
                                            style: TextStyle(
                                              fontWeight: FontWeight.bold,
                                              fontSize: kIsWindows ? 12 : 12.sp,
                                              color: colorScheme.outline,
                                            ),
                                          ),
                                        ),
                                      ),
                                    )
                                    .toList(),
                          ),
                          SizedBox(height: kIsWindows ? 8 : 8.h),
                          // Griglia giorni
                          ...List.generate(6, (weekIndex) {
                            return Row(
                              children: List.generate(7, (dayIndex) {
                                final dayNumber =
                                    weekIndex * 7 + dayIndex - firstWeekday + 1;
                                if (dayNumber < 1 || dayNumber > daysInMonth) {
                                  return Expanded(
                                    child: Container(
                                      height: kIsWindows ? 40 : 40.h,
                                    ),
                                  );
                                }

                                final date = DateTime(
                                  selectedMonth.year,
                                  selectedMonth.month,
                                  dayNumber,
                                );
                                final dayAppointments = appointments
                                    .where(
                                      (a) =>
                                          a.startDateTime.year == date.year &&
                                          a.startDateTime.month == date.month &&
                                          a.startDateTime.day == date.day,
                                    )
                                    .toList();
                                final hasAppointments =
                                    dayAppointments.isNotEmpty;
                                final isSelected =
                                    selectedDate?.year == date.year &&
                                    selectedDate?.month == date.month &&
                                    selectedDate?.day == date.day;

                                return Expanded(
                                  child: InkWell(
                                    onTap: () => onDateSelected(
                                      isSelected ? null : date,
                                    ),
                                    child: Container(
                                      height: kIsWindows ? 40 : 40.h,
                                      margin: EdgeInsets.all(
                                        kIsWindows ? 2 : 2.sp,
                                      ),
                                      decoration: BoxDecoration(
                                        color: isSelected
                                            ? colorScheme.primaryContainer
                                            : (hasAppointments
                                                  ? colorScheme.primary
                                                        .withValues(alpha: 0.1)
                                                  : null),
                                        borderRadius: BorderRadius.circular(8),
                                        border: Border.all(
                                          color: isSelected
                                              ? colorScheme.primary
                                              : Colors.transparent,
                                          width: 2,
                                        ),
                                      ),
                                      child: Stack(
                                        alignment: Alignment.center,
                                        children: [
                                          Text(
                                            '$dayNumber',
                                            style: TextStyle(
                                              fontWeight: hasAppointments
                                                  ? FontWeight.bold
                                                  : FontWeight.normal,
                                              color: isSelected
                                                  ? colorScheme
                                                        .onPrimaryContainer
                                                  : colorScheme.onSurface,
                                            ),
                                          ),
                                          if (hasAppointments)
                                            Positioned(
                                              bottom: 4,
                                              child: Container(
                                                width: 4,
                                                height: 4,
                                                decoration: BoxDecoration(
                                                  color: colorScheme.primary,
                                                  shape: BoxShape.circle,
                                                ),
                                              ),
                                            ),
                                        ],
                                      ),
                                    ),
                                  ),
                                );
                              }),
                            );
                          }),
                        ],
                      ),
                    ),
                    SizedBox(height: kIsWindows ? 16 : 16.h),
                    // Dettaglio appuntamenti giorno selezionato
                    if (selectedDate != null)
                      Container(
                        width: double.infinity,
                        padding: EdgeInsets.all(kIsWindows ? 16 : 16.sp),
                        decoration: BoxDecoration(
                          color: colorScheme.surfaceContainerHighest.withValues(
                            alpha: 0.3,
                          ),
                          borderRadius: BorderRadius.vertical(
                            bottom: Radius.circular(12),
                          ),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Appuntamenti del ${selectedDate!.day}/${selectedDate!.month}/${selectedDate!.year}',
                              style: TextStyle(
                                fontWeight: FontWeight.bold,
                                fontSize: kIsWindows ? 14 : 14.sp,
                              ),
                            ),
                            SizedBox(height: kIsWindows ? 8 : 8.h),
                            Builder(
                              builder: (_) {
                                final dayAppointments =
                                    appointments
                                        .where(
                                          (a) =>
                                              a.startDateTime.year ==
                                                  selectedDate!.year &&
                                              a.startDateTime.month ==
                                                  selectedDate!.month &&
                                              a.startDateTime.day ==
                                                  selectedDate!.day,
                                        )
                                        .toList()
                                      ..sort(
                                        (a, b) => a.startDateTime.compareTo(
                                          b.startDateTime,
                                        ),
                                      );

                                if (dayAppointments.isEmpty) {
                                  return Text(
                                    'Nessun appuntamento',
                                    style: TextStyle(
                                      color: colorScheme.outline,
                                    ),
                                  );
                                }

                                return Column(
                                  children: dayAppointments.map((apt) {
                                    // Find payments for this appointment
                                    final appointmentPayments = payments
                                        .where((p) => p.appointmentId == apt.id)
                                        .toList();

                                    return Card(
                                      margin: EdgeInsets.only(
                                        bottom: kIsWindows ? 8 : 8.h,
                                      ),
                                      child: Column(
                                        children: [
                                          ListTile(
                                            leading: Icon(
                                              Symbols.schedule_rounded,
                                              color: colorScheme.primary,
                                            ),
                                            title: Text(
                                              '${apt.startDateTime.hour.toString().padLeft(2, '0')}:${apt.startDateTime.minute.toString().padLeft(2, '0')} - ${apt.endDateTime.hour.toString().padLeft(2, '0')}:${apt.endDateTime.minute.toString().padLeft(2, '0')}',
                                            ),
                                            subtitle: Text(
                                              'Cabina ${apt.cabinId ?? '-'}',
                                            ),
                                            dense: true,
                                          ),
                                          // Show payments for this appointment
                                          if (appointmentPayments
                                              .isNotEmpty) ...[
                                            Divider(height: 1),
                                            ...appointmentPayments.map(
                                              (payment) => InkWell(
                                                onTap: () =>
                                                    _showPaymentDetails(
                                                      context,
                                                      ref,
                                                      payment,
                                                    ),
                                                child: Padding(
                                                  padding: EdgeInsets.symmetric(
                                                    horizontal: kIsWindows
                                                        ? 16
                                                        : 16.sp,
                                                    vertical: kIsWindows
                                                        ? 8
                                                        : 8.h,
                                                  ),
                                                  child: Row(
                                                    children: [
                                                      Icon(
                                                        Symbols
                                                            .payments_rounded,
                                                        size: 16,
                                                        color: Colors.green,
                                                      ),
                                                      SizedBox(
                                                        width: kIsWindows
                                                            ? 8
                                                            : 8.w,
                                                      ),
                                                      Expanded(
                                                        child: Text(
                                                          'Pagamento: €${payment.amount.toStringAsFixed(2)}',
                                                          style: TextStyle(
                                                            fontSize: kIsWindows
                                                                ? 12
                                                                : 12.sp,
                                                            color: colorScheme
                                                                .onSurfaceVariant,
                                                          ),
                                                        ),
                                                      ),
                                                      Text(
                                                        payment.paymentMethod,
                                                        style: TextStyle(
                                                          fontSize: kIsWindows
                                                              ? 11
                                                              : 11.sp,
                                                          color: colorScheme
                                                              .outline,
                                                        ),
                                                      ),
                                                      SizedBox(
                                                        width: kIsWindows
                                                            ? 4
                                                            : 4.w,
                                                      ),
                                                      Icon(
                                                        Symbols
                                                            .chevron_right_rounded,
                                                        size: 16,
                                                        color:
                                                            colorScheme.outline,
                                                      ),
                                                    ],
                                                  ),
                                                ),
                                              ),
                                            ),
                                          ],
                                        ],
                                      ),
                                    );
                                  }).toList(),
                                );
                              },
                            ),
                          ],
                        ),
                      ),
                  ],
                );
              },
              loading: () => const Padding(
                padding: EdgeInsets.all(24),
                child: Center(child: CircularProgressIndicator()),
              ),
              error: (error, _) => Padding(
                padding: const EdgeInsets.all(16),
                child: Text(
                  'Errore: $error',
                  style: TextStyle(color: colorScheme.error),
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildDetailRow(
    BuildContext context,
    String label,
    String value, {
    bool isAmount = false,
  }) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            label,
            style: TextStyle(
              color: Theme.of(context).colorScheme.outline,
              fontSize: 12,
            ),
          ),
          Text(
            value,
            style: TextStyle(
              fontWeight: isAmount ? FontWeight.bold : FontWeight.normal,
              color: isAmount
                  ? Colors.green
                  : Theme.of(context).colorScheme.onSurface,
              fontSize: 12,
            ),
          ),
        ],
      ),
    );
  }
}

// ============================================================================
// SEZIONE: Storico Fidelity
// ============================================================================
class _FidelityHistorySection extends ConsumerWidget {
  const _FidelityHistorySection({
    required this.clientId,
    required this.isExpanded,
    required this.onToggle,
  });

  final String clientId;
  final bool isExpanded;
  final VoidCallback onToggle;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final colorScheme = Theme.of(context).colorScheme;
    final transactionsAsync = ref.watch(
      clientFidelityTransactionsProvider(clientId),
    );

    return Card(
      clipBehavior: Clip.antiAlias,
      child: Column(
        children: [
          InkWell(
            onTap: onToggle,
            child: Padding(
              padding: EdgeInsets.all(kIsWindows ? 16 : 16.sp),
              child: Row(
                children: [
                  Icon(Symbols.history_rounded, color: colorScheme.primary),
                  SizedBox(width: kIsWindows ? 12 : 12.w),
                  Expanded(
                    child: Text(
                      'Storico Fidelity',
                      style: TextStyle(
                        fontSize: kIsWindows ? 18 : 18.sp,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                  Icon(
                    isExpanded
                        ? Symbols.expand_less_rounded
                        : Symbols.expand_more_rounded,
                    color: colorScheme.outline,
                  ),
                ],
              ),
            ),
          ),
          if (isExpanded)
            transactionsAsync.when(
              data: (List<FidelityTransactionWithCard> transactions) {
                if (transactions.isEmpty) {
                  return Padding(
                    padding: EdgeInsets.all(kIsWindows ? 24 : 24.sp),
                    child: Column(
                      children: [
                        Icon(
                          Symbols.card_membership_rounded,
                          size: kIsWindows ? 48 : 48.sp,
                          color: colorScheme.outline,
                        ),
                        SizedBox(height: kIsWindows ? 12 : 12.h),
                        Text(
                          'Nessuna transazione fidelity',
                          style: TextStyle(
                            color: colorScheme.outline,
                            fontSize: kIsWindows ? 16 : 16.sp,
                          ),
                        ),
                      ],
                    ),
                  );
                }

                return ConstrainedBox(
                  constraints: BoxConstraints(
                    maxHeight: MediaQuery.of(context).size.height * 0.5,
                  ),
                  child: ListView.separated(
                    shrinkWrap: true,
                    padding: EdgeInsets.fromLTRB(
                      kIsWindows ? 16 : 16.sp,
                      0,
                      kIsWindows ? 16 : 16.sp,
                      kIsWindows ? 16 : 16.sp,
                    ),
                    itemCount: transactions.length,
                    separatorBuilder: (_, __) =>
                        SizedBox(height: kIsWindows ? 8 : 8.h),
                    itemBuilder: (BuildContext context, int index) {
                      final FidelityTransactionWithCard item =
                          transactions[index];
                      final bool isTopup = item.transaction.type == 'topup';
                      final bool isUsage = item.transaction.type == 'usage';

                      return Card(
                        margin: EdgeInsets.zero,
                        child: ListTile(
                          leading: Container(
                            width: 40,
                            height: 40,
                            decoration: BoxDecoration(
                              color: isTopup
                                  ? Colors.green.withValues(alpha: 0.1)
                                  : (isUsage
                                        ? Colors.red.withValues(alpha: 0.1)
                                        : Colors.orange.withValues(alpha: 0.1)),
                              shape: BoxShape.circle,
                            ),
                            child: Icon(
                              isTopup
                                  ? Symbols.add_rounded
                                  : (isUsage
                                        ? Symbols.remove_rounded
                                        : Symbols.replay_rounded),
                              color: isTopup
                                  ? Colors.green
                                  : (isUsage ? Colors.red : Colors.orange),
                            ),
                          ),
                          title: Text(
                            isTopup
                                ? 'Ricarica'
                                : (isUsage ? 'Utilizzo' : 'Rimborso'),
                            style: const TextStyle(fontWeight: FontWeight.w500),
                          ),
                          subtitle: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text('Carta: ${item.cardNumber}'),
                              if (item.transaction.description != null &&
                                  item.transaction.description!.isNotEmpty)
                                Text(
                                  item.transaction.description!,
                                  style: TextStyle(
                                    fontSize: 11,
                                    color: colorScheme.outline,
                                  ),
                                ),
                            ],
                          ),
                          trailing: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            crossAxisAlignment: CrossAxisAlignment.end,
                            children: [
                              Text(
                                '${isUsage || (item.transaction.amount < 0) ? '' : '+'}€${item.transaction.amount.abs().toStringAsFixed(2)}',
                                style: TextStyle(
                                  fontWeight: FontWeight.bold,
                                  color: isTopup
                                      ? Colors.green
                                      : (isUsage
                                            ? Colors.red
                                            : colorScheme.onSurface),
                                  fontSize: kIsWindows ? 16 : 16.sp,
                                ),
                              ),
                              Text(
                                '${item.transaction.createdAt.day.toString().padLeft(2, '0')}/${item.transaction.createdAt.month.toString().padLeft(2, '0')}/${item.transaction.createdAt.year}',
                                style: TextStyle(
                                  fontSize: 11,
                                  color: colorScheme.outline,
                                ),
                              ),
                            ],
                          ),
                        ),
                      );
                    },
                  ),
                );
              },
              loading: () => const Padding(
                padding: EdgeInsets.all(24),
                child: Center(child: CircularProgressIndicator()),
              ),
              error: (Object error, _) => Padding(
                padding: const EdgeInsets.all(16),
                child: Text(
                  'Errore: $error',
                  style: TextStyle(color: colorScheme.error),
                ),
              ),
            ),
        ],
      ),
    );
  }
}

// ============================================================================
// SEZIONE: Storico (espandibile con filtri)
// ============================================================================
class _HistorySection extends ConsumerStatefulWidget {
  const _HistorySection({
    required this.clientId,
    required this.isExpanded,
    required this.onToggle,
  });

  final String clientId;
  final bool isExpanded;
  final VoidCallback onToggle;

  @override
  ConsumerState<_HistorySection> createState() => _HistorySectionState();
}

class _HistorySectionState extends ConsumerState<_HistorySection> {
  Widget _buildDetailRow(
    BuildContext context,
    String label,
    String value, {
    bool isAmount = false,
  }) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            label,
            style: TextStyle(
              color: Theme.of(context).colorScheme.outline,
              fontSize: 12,
            ),
          ),
          Text(
            value,
            style: TextStyle(
              fontWeight: isAmount ? FontWeight.bold : FontWeight.normal,
              color: isAmount
                  ? Colors.green
                  : Theme.of(context).colorScheme.onSurface,
              fontSize: 12,
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _showPaymentDetails(
    BuildContext context,
    WidgetRef ref,
    PaymentData payment,
  ) async {
    // Fetch related data
    String? packageName;
    String? productName;
    String? appointmentDetails;
    PackageData? packageData;
    ProductSaleData? saleData;
    AppointmentData? appointmentData;

    if (payment.packageId != null) {
      packageData = await ref
          .read(packagesActionsProvider)
          .getPackageById(payment.packageId!);
      packageName = packageData?.name;
    }

    if (payment.productSaleId != null) {
      // Get product sale data from repository
      final sales = await ref
          .read(productSalesActionsProvider)
          .getProductSalesByClientId(widget.clientId);
      saleData = sales.cast<ProductSaleData?>().firstWhere(
        (s) => s?.id == payment.productSaleId,
        orElse: () => null,
      );
      productName = saleData?.lockedProductName;
    }

    if (payment.appointmentId != null) {
      appointmentData = await ref
          .read(appointmentActionsProvider)
          .getById(payment.appointmentId!);

      if (appointmentData != null) {
        final services = await ref
            .read(appointmentActionsProvider)
            .getAppointmentServicesByAppointmentId(payment.appointmentId!);

        // Fetch service names since AppointmentServiceData doesn't have lockedServiceName
        final serviceNames = <String>[];
        for (final service in services) {
          final serviceData = await ref
              .read(servicesActionsProvider)
              .getServiceById(service.serviceId);
          if (serviceData != null) {
            serviceNames.add(serviceData.name);
          }
        }

        final servicesList = serviceNames.join(', ');
        final date = _formatDateTime(appointmentData.startDateTime);
        appointmentDetails = '$date - $servicesList';
      }
    }

    if (!context.mounted) return;

    showDialog<void>(
      context: context,
      builder: (context) => AlertDialog(
        title: Row(
          children: [
            Icon(Icons.payment, color: Colors.green),
            const SizedBox(width: 12),
            const Text('Dettaglio Pagamento'),
          ],
        ),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Payment Information
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Theme.of(
                    context,
                  ).colorScheme.primaryContainer.withValues(alpha: 0.2),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Informazioni Pagamento',
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        color: Theme.of(context).colorScheme.primary,
                      ),
                    ),
                    const SizedBox(height: 8),
                    _buildDetailRow(
                      context,
                      'Importo',
                      '€${payment.amount.toStringAsFixed(2)}',
                      isAmount: true,
                    ),
                    _buildDetailRow(context, 'Metodo', payment.paymentMethod),
                    _buildDetailRow(
                      context,
                      'Data',
                      _formatDateTime(payment.paidAt),
                    ),
                    if (payment.notes != null && payment.notes!.isNotEmpty)
                      _buildDetailRow(context, 'Note', payment.notes!),
                  ],
                ),
              ),

              const SizedBox(height: 16),

              // Related Entity Information
              if (packageName != null ||
                  productName != null ||
                  appointmentDetails != null) ...[
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: Theme.of(context).colorScheme.surfaceContainerHighest
                        .withValues(alpha: 0.3),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Dettagli Acquisto',
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          color: Theme.of(context).colorScheme.onSurface,
                        ),
                      ),
                      const SizedBox(height: 8),
                      if (packageName != null) ...[
                        _buildDetailRow(context, 'Pacchetto', packageName),
                        if (packageData != null) ...[
                          _buildDetailRow(
                            context,
                            'Totale Pacchetto',
                            '€${packageData.totalPrice.toStringAsFixed(2)}',
                          ),
                          _buildDetailRow(
                            context,
                            'Già Pagato',
                            '€${packageData.paidAmount.toStringAsFixed(2)}',
                          ),
                          _buildDetailRow(
                            context,
                            'Rimanente',
                            '€${(packageData.totalPrice - packageData.paidAmount).toStringAsFixed(2)}',
                          ),
                        ],
                      ],
                      if (productName != null) ...[
                        _buildDetailRow(context, 'Prodotto', productName),
                        if (saleData != null) ...[
                          _buildDetailRow(
                            context,
                            'Quantità',
                            '${saleData.quantity}',
                          ),
                          _buildDetailRow(
                            context,
                            'Prezzo Unitario',
                            '€${saleData.lockedPrice.toStringAsFixed(2)}',
                          ),
                        ],
                      ],
                      if (appointmentDetails != null)
                        _buildDetailRow(
                          context,
                          'Appuntamento',
                          appointmentDetails,
                        ),
                    ],
                  ),
                ),
              ],
            ],
          ),
        ),
        actions: [
          if (packageData != null)
            TextButton.icon(
              icon: const Icon(Symbols.inventory_2_rounded),
              label: const Text('Vai al pacchetto'),
              onPressed: () {
                Navigator.pop(context);
                Navigator.push<void>(
                  context,
                  MaterialPageRoute(
                    builder: (_) =>
                        PackageDetailsPage(packageId: packageData!.id),
                  ),
                );
              },
            ),
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Chiudi'),
          ),
        ],
      ),
    );
  }

  Future<void> _showAppointmentDetails(
    BuildContext context,
    AppointmentData appointment,
  ) async {
    // Check if appointment is linked to a package or fidelity
    // TODO: Add logic to check appointment-package/fidelity linkage when available

    showDialog<void>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Row(
          children: [
            Icon(Icons.event, color: Colors.blue),
            SizedBox(width: 12),
            Text('Dettaglio Appuntamento'),
          ],
        ),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _buildDetailRow(
                context,
                'Data/Ora',
                _formatDateTime(appointment.startDateTime),
              ),
              _buildDetailRow(
                context,
                'Cabina',
                'Cabina ${appointment.cabinId ?? '-'}',
              ),
              _buildDetailRow(
                context,
                'Operatore',
                'ID: ${appointment.operatorId ?? '-'}',
              ),
              // TODO: Add package/fidelity linkage display when available
              if (appointment.discount > 0) ...[
                const Divider(height: 16),
                _buildDetailRow(
                  context,
                  'Sconto applicato',
                  '€${appointment.discount.toStringAsFixed(2)}',
                  isAmount: true,
                ),
                if (appointment.discountReason != null)
                  _buildDetailRow(
                    context,
                    'Motivo sconto',
                    appointment.discountReason!,
                  ),
              ],
              if (appointment.notes != null &&
                  appointment.notes!.isNotEmpty) ...[
                const Divider(height: 16),
                _buildDetailRow(context, 'Note', appointment.notes!),
              ],
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Chiudi'),
          ),
        ],
      ),
    );
  }

  Future<void> _selectDateRange(BuildContext context) async {
    final filters = ref.read(historyFiltersProvider);
    final now = DateTime.now();

    final picked = await showDateRangePicker(
      context: context,
      firstDate: DateTime(2020),
      lastDate: now,
      initialDateRange: filters.dateFrom != null && filters.dateTo != null
          ? DateTimeRange(start: filters.dateFrom!, end: filters.dateTo!)
          : null,
    );

    if (picked != null) {
      ref
          .read(historyFiltersProvider.notifier)
          .setDateRange(picked.start, picked.end);
    }
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final filters = ref.watch(historyFiltersProvider);
    final filteredHistoryAsync = ref.watch(
      filteredClientHistoryProvider(widget.clientId),
    );

    return Card(
      clipBehavior: Clip.antiAlias,
      child: Column(
        children: [
          InkWell(
            onTap: widget.onToggle,
            child: Padding(
              padding: EdgeInsets.all(kIsWindows ? 16 : 16.sp),
              child: Row(
                children: [
                  Icon(Symbols.history_rounded, color: colorScheme.primary),
                  SizedBox(width: kIsWindows ? 12 : 12.w),
                  Expanded(
                    child: Text(
                      'Storico',
                      style: TextStyle(
                        fontSize: kIsWindows ? 18 : 18.sp,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                  Icon(
                    widget.isExpanded
                        ? Symbols.expand_less_rounded
                        : Symbols.expand_more_rounded,
                    color: colorScheme.outline,
                  ),
                ],
              ),
            ),
          ),
          if (widget.isExpanded) ...[
            // Filtri
            Container(
              padding: EdgeInsets.symmetric(
                horizontal: kIsWindows ? 16 : 16.sp,
                vertical: kIsWindows ? 8 : 8.sp,
              ),
              decoration: BoxDecoration(
                color: colorScheme.surfaceContainerHighest.withValues(
                  alpha: 0.3,
                ),
                border: Border(
                  top: BorderSide(
                    color: colorScheme.outline.withValues(alpha: 0.2),
                  ),
                  bottom: BorderSide(
                    color: colorScheme.outline.withValues(alpha: 0.2),
                  ),
                ),
              ),
              child: Column(
                children: [
                  // Filtro tipo
                  SingleChildScrollView(
                    scrollDirection: Axis.horizontal,
                    child: Row(
                      children: [
                        _FilterChip(
                          label: 'Tutti',
                          isSelected: filters.type == HistoryFilterType.all,
                          onTap: () => ref
                              .read(historyFiltersProvider.notifier)
                              .setType(HistoryFilterType.all),
                        ),
                        SizedBox(width: kIsWindows ? 8 : 8.w),
                        _FilterChip(
                          label: 'Pagamenti',
                          isSelected:
                              filters.type == HistoryFilterType.payments,
                          onTap: () => ref
                              .read(historyFiltersProvider.notifier)
                              .setType(HistoryFilterType.payments),
                        ),
                        SizedBox(width: kIsWindows ? 8 : 8.w),
                        _FilterChip(
                          label: 'Appuntamenti',
                          isSelected:
                              filters.type == HistoryFilterType.appointments,
                          onTap: () => ref
                              .read(historyFiltersProvider.notifier)
                              .setType(HistoryFilterType.appointments),
                        ),
                      ],
                    ),
                  ),
                  SizedBox(height: kIsWindows ? 8 : 8.h),
                  // Filtro data e ricerca
                  Row(
                    children: [
                      Expanded(
                        child: TextField(
                          decoration: InputDecoration(
                            hintText: 'Cerca...',
                            prefixIcon: const Icon(
                              Symbols.search_rounded,
                              size: 20,
                            ),
                            isDense: true,
                            filled: true,
                            fillColor: colorScheme.surface,
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(8),
                              borderSide: BorderSide.none,
                            ),
                            contentPadding: EdgeInsets.symmetric(
                              horizontal: kIsWindows ? 12 : 12.w,
                              vertical: kIsWindows ? 8 : 8.sp,
                            ),
                          ),
                          onChanged: (value) => ref
                              .read(historyFiltersProvider.notifier)
                              .setSearchQuery(value),
                        ),
                      ),
                      SizedBox(width: kIsWindows ? 8 : 8.w),
                      IconButton(
                        icon: const Icon(Symbols.calendar_month_rounded),
                        onPressed: () => _selectDateRange(context),
                        tooltip: 'Filtra per data',
                        style: IconButton.styleFrom(
                          backgroundColor: filters.dateFrom != null
                              ? colorScheme.primaryContainer
                              : null,
                        ),
                      ),
                      if (filters.dateFrom != null ||
                          filters.searchQuery.isNotEmpty ||
                          filters.type != HistoryFilterType.all)
                        IconButton(
                          icon: const Icon(Symbols.clear_all_rounded),
                          onPressed: () => ref
                              .read(historyFiltersProvider.notifier)
                              .clearFilters(),
                          tooltip: 'Cancella filtri',
                        ),
                    ],
                  ),
                ],
              ),
            ),
            // Lista storico filtrato
            filteredHistoryAsync.when(
              data: (historyItems) {
                if (historyItems.isEmpty) {
                  return Padding(
                    padding: EdgeInsets.all(kIsWindows ? 24 : 24.sp),
                    child: Column(
                      children: [
                        Icon(
                          Symbols.filter_list_off_rounded,
                          size: kIsWindows ? 48 : 48.sp,
                          color: colorScheme.outline,
                        ),
                        SizedBox(height: kIsWindows ? 12 : 12.h),
                        Text(
                          'Nessun risultato con i filtri attuali',
                          style: TextStyle(
                            color: colorScheme.outline,
                            fontSize: kIsWindows ? 16 : 16.sp,
                          ),
                        ),
                      ],
                    ),
                  );
                }

                return ConstrainedBox(
                  constraints: BoxConstraints(
                    maxHeight: MediaQuery.of(context).size.height * 0.5,
                  ),
                  child: ListView.separated(
                    shrinkWrap: true,
                    padding: EdgeInsets.fromLTRB(
                      kIsWindows ? 16 : 16.sp,
                      kIsWindows ? 16 : 16.sp,
                      kIsWindows ? 16 : 16.sp,
                      kIsWindows ? 16 : 16.sp,
                    ),
                    itemCount: historyItems.length,
                    separatorBuilder: (_, __) =>
                        SizedBox(height: kIsWindows ? 8 : 8.h),
                    itemBuilder: (context, index) {
                      final item = historyItems[index];
                      final isPayment = item.type == HistoryItemType.payment;

                      return Card(
                        margin: EdgeInsets.zero,
                        child: InkWell(
                          onTap: () {
                            if (isPayment && item.paymentData != null) {
                              _showPaymentDetails(
                                context,
                                ref,
                                item.paymentData!,
                              );
                            } else if (!isPayment &&
                                item.appointmentData != null) {
                              _showAppointmentDetails(
                                context,
                                item.appointmentData!,
                              );
                            }
                          },
                          borderRadius: BorderRadius.circular(12),
                          child: ListTile(
                            leading: Icon(
                              isPayment
                                  ? Symbols.payments_rounded
                                  : Symbols.event_rounded,
                              color: isPayment
                                  ? Colors.green
                                  : colorScheme.primary,
                            ),
                            title: Text(item.title),
                            subtitle: Text(
                              '${item.subtitle} • ${_formatDateTime(item.date)}',
                            ),
                            trailing: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                if (item.amount != null)
                                  Text(
                                    '€${item.amount!.toStringAsFixed(2)}',
                                    style: TextStyle(
                                      fontWeight: FontWeight.bold,
                                      color: item.amount! >= 0
                                          ? Colors.green
                                          : colorScheme.error,
                                      fontSize: kIsWindows ? 16 : 16.sp,
                                    ),
                                  ),
                                const SizedBox(width: 8),
                                Icon(
                                  Icons.chevron_right,
                                  color: colorScheme.outline,
                                  size: kIsWindows ? 20 : 20.sp,
                                ),
                              ],
                            ),
                          ),
                        ),
                      );
                    },
                  ),
                );
              },
              loading: () => const Padding(
                padding: EdgeInsets.all(24),
                child: Center(child: CircularProgressIndicator()),
              ),
              error: (error, _) => Padding(
                padding: const EdgeInsets.all(16),
                child: Text(
                  'Errore: $error',
                  style: TextStyle(color: colorScheme.error),
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }

  String _formatDateTime(DateTime date) {
    return '${date.day.toString().padLeft(2, '0')}/${date.month.toString().padLeft(2, '0')}/${date.year} ${date.hour.toString().padLeft(2, '0')}:${date.minute.toString().padLeft(2, '0')}';
  }
}

class _FilterChip extends StatelessWidget {
  const _FilterChip({
    required this.label,
    required this.isSelected,
    required this.onTap,
  });

  final String label;
  final bool isSelected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(16),
      child: Container(
        padding: EdgeInsets.symmetric(
          horizontal: kIsWindows ? 12 : 12.w,
          vertical: kIsWindows ? 6 : 6.sp,
        ),
        decoration: BoxDecoration(
          color: isSelected
              ? cs.primaryContainer
              : cs.surfaceContainerHighest.withValues(alpha: 0.5),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: isSelected ? cs.primary : cs.outline.withValues(alpha: 0.3),
            width: isSelected ? 2 : 1,
          ),
        ),
        child: Text(
          label,
          style: TextStyle(
            fontSize: kIsWindows ? 12 : 12.sp,
            fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
            color: isSelected ? cs.onPrimaryContainer : cs.onSurface,
          ),
        ),
      ),
    );
  }
}

// ============================================================================
// SEZIONE: Preventivi con ricerca e filtri
// ============================================================================
class _QuotesSectionWithFilters extends ConsumerStatefulWidget {
  const _QuotesSectionWithFilters({
    required this.clientId,
    required this.isExpanded,
    required this.onToggle,
    required this.onCreateQuote,
    required this.isOffline,
  });

  final String clientId;
  final bool isExpanded;
  final VoidCallback onToggle;
  final VoidCallback onCreateQuote;
  final bool isOffline;

  @override
  ConsumerState<_QuotesSectionWithFilters> createState() =>
      _QuotesSectionWithFiltersState();
}

class _QuotesSectionWithFiltersState
    extends ConsumerState<_QuotesSectionWithFilters> {
  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final searchQuery = ref.watch(quotesSearchQueryProvider);
    final statusFilter = ref.watch(quotesStatusFilterProvider);
    final quotesAsync = ref.watch(
      quotesByClientStreamProvider(widget.clientId),
    );

    return Card(
      clipBehavior: Clip.antiAlias,
      child: Column(
        children: [
          InkWell(
            onTap: widget.onToggle,
            child: Padding(
              padding: EdgeInsets.all(kIsWindows ? 16 : 16.sp),
              child: Row(
                children: [
                  Icon(Symbols.description_rounded, color: cs.primary),
                  SizedBox(width: kIsWindows ? 12 : 12.w),
                  Expanded(
                    child: Text(
                      'Preventivi',
                      style: TextStyle(
                        fontSize: kIsWindows ? 18 : 18.sp,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                  if (!widget.isOffline)
                    IconButton(
                      icon: const Icon(Symbols.add_rounded),
                      tooltip: 'Nuovo preventivo',
                      onPressed: widget.onCreateQuote,
                    ),
                  Icon(
                    widget.isExpanded
                        ? Symbols.expand_less_rounded
                        : Symbols.expand_more_rounded,
                    color: cs.outline,
                  ),
                ],
              ),
            ),
          ),
          if (widget.isExpanded) ...[
            // Filtri
            Container(
              padding: EdgeInsets.symmetric(
                horizontal: kIsWindows ? 16 : 16.sp,
                vertical: kIsWindows ? 8 : 8.sp,
              ),
              decoration: BoxDecoration(
                color: cs.surfaceContainerHighest.withValues(alpha: 0.3),
                border: Border(
                  top: BorderSide(color: cs.outline.withValues(alpha: 0.2)),
                  bottom: BorderSide(color: cs.outline.withValues(alpha: 0.2)),
                ),
              ),
              child: Row(
                children: [
                  Expanded(
                    child: TextField(
                      decoration: InputDecoration(
                        hintText: 'Cerca preventivo...',
                        prefixIcon: const Icon(
                          Symbols.search_rounded,
                          size: 20,
                        ),
                        isDense: true,
                        filled: true,
                        fillColor: cs.surface,
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(8),
                          borderSide: BorderSide.none,
                        ),
                        contentPadding: EdgeInsets.symmetric(
                          horizontal: kIsWindows ? 12 : 12.w,
                          vertical: kIsWindows ? 8 : 8.sp,
                        ),
                      ),
                      onChanged: (value) => ref
                          .read(quotesSearchQueryProvider.notifier)
                          .set(value),
                    ),
                  ),
                  SizedBox(width: kIsWindows ? 8 : 8.w),
                  PopupMenuButton<QuoteStatusFilter>(
                    initialValue: statusFilter,
                    onSelected: (value) => ref
                        .read(quotesStatusFilterProvider.notifier)
                        .set(value),
                    itemBuilder: (context) => [
                      const PopupMenuItem(
                        value: QuoteStatusFilter.all,
                        child: Text('Tutti'),
                      ),
                      const PopupMenuItem(
                        value: QuoteStatusFilter.pending,
                        child: Text('In attesa'),
                      ),
                      const PopupMenuItem(
                        value: QuoteStatusFilter.accepted,
                        child: Text('Accettati'),
                      ),
                      const PopupMenuItem(
                        value: QuoteStatusFilter.rejected,
                        child: Text('Rifiutati'),
                      ),
                    ],
                    child: Chip(
                      avatar: const Icon(Symbols.filter_list_rounded, size: 18),
                      label: Text(switch (statusFilter) {
                        QuoteStatusFilter.all => 'Tutti',
                        QuoteStatusFilter.pending => 'In attesa',
                        QuoteStatusFilter.accepted => 'Accettati',
                        QuoteStatusFilter.rejected => 'Rifiutati',
                      }),
                    ),
                  ),
                ],
              ),
            ),
            quotesAsync.when(
              data: (quotes) {
                // Apply filters
                var filtered = quotes;
                if (searchQuery.isNotEmpty) {
                  filtered = filtered
                      .where(
                        (q) =>
                            q.quoteNumber.toLowerCase().contains(
                              searchQuery.toLowerCase(),
                            ) ||
                            q.notes?.toLowerCase().contains(
                                  searchQuery.toLowerCase(),
                                ) ==
                                true,
                      )
                      .toList();
                }
                if (statusFilter != QuoteStatusFilter.all) {
                  filtered = filtered
                      .where(
                        (q) => switch (statusFilter) {
                          QuoteStatusFilter.pending => q.status == 'pending',
                          QuoteStatusFilter.accepted => q.status == 'accepted',
                          QuoteStatusFilter.rejected => q.status == 'rejected',
                          _ => true,
                        },
                      )
                      .toList();
                }

                if (filtered.isEmpty) {
                  return Padding(
                    padding: EdgeInsets.all(kIsWindows ? 24 : 24.sp),
                    child: Column(
                      children: [
                        Icon(
                          Symbols.description_rounded,
                          size: kIsWindows ? 48 : 48.sp,
                          color: cs.outline,
                        ),
                        SizedBox(height: kIsWindows ? 12 : 12.h),
                        Text(
                          searchQuery.isEmpty &&
                                  statusFilter == QuoteStatusFilter.all
                              ? 'Nessun preventivo'
                              : 'Nessun risultato con i filtri attuali',
                          style: TextStyle(
                            color: cs.outline,
                            fontSize: kIsWindows ? 16 : 16.sp,
                          ),
                        ),
                      ],
                    ),
                  );
                }

                return ConstrainedBox(
                  constraints: BoxConstraints(
                    maxHeight: MediaQuery.of(context).size.height * 0.5,
                  ),
                  child: ListView.separated(
                    shrinkWrap: true,
                    padding: EdgeInsets.fromLTRB(
                      kIsWindows ? 16 : 16.sp,
                      kIsWindows ? 16 : 16.sp,
                      kIsWindows ? 16 : 16.sp,
                      kIsWindows ? 16 : 16.sp,
                    ),
                    itemCount: filtered.length,
                    separatorBuilder: (_, __) =>
                        SizedBox(height: kIsWindows ? 8 : 8.h),
                    itemBuilder: (context, index) => _QuoteCardSimple(
                      quote: filtered[index],
                      isOffline: widget.isOffline,
                    ),
                  ),
                );
              },
              loading: () => const Padding(
                padding: EdgeInsets.all(24),
                child: Center(child: CircularProgressIndicator()),
              ),
              error: (error, _) => Padding(
                padding: const EdgeInsets.all(16),
                child: Text(
                  'Errore: $error',
                  style: TextStyle(color: cs.error),
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class _QuoteCardSimple extends StatelessWidget {
  const _QuoteCardSimple({required this.quote, required this.isOffline});

  final QuoteData quote;
  final bool isOffline;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final isPending = quote.status == 'pending';
    final isAccepted = quote.status == 'accepted';

    return Card(
      margin: EdgeInsets.zero,
      child: ListTile(
        leading: Icon(
          isPending
              ? Symbols.schedule_rounded
              : (isAccepted
                    ? Symbols.check_circle_rounded
                    : Symbols.cancel_rounded),
          color: isPending
              ? Colors.orange
              : (isAccepted ? Colors.green : cs.error),
        ),
        title: Text(
          quote.quoteNumber,
          style: const TextStyle(fontWeight: FontWeight.w500),
        ),
        subtitle: Text(
          '€${quote.totalPrice.toStringAsFixed(2)} ${quote.discountAmount > 0 ? '(sconto €${quote.discountAmount.toStringAsFixed(2)})' : ''}',
        ),
        trailing: isPending && !isOffline
            ? FilledButton.tonal(
                onPressed: () => _showAcceptQuoteDialog(context),
                child: const Text('Accetta'),
              )
            : Chip(
                label: Text(
                  isPending
                      ? 'In attesa'
                      : (isAccepted ? 'Accettato' : 'Rifiutato'),
                  style: TextStyle(fontSize: kIsWindows ? 11 : 11.sp),
                ),
                backgroundColor: isPending
                    ? Colors.orange.withValues(alpha: 0.2)
                    : (isAccepted
                          ? Colors.green.withValues(alpha: 0.2)
                          : cs.errorContainer),
              ),
        onTap: () => _showQuoteDetails(context),
      ),
    );
  }

  void _showAcceptQuoteDialog(BuildContext context) {
    showDialog<void>(
      context: context,
      builder: (context) => QuoteAcceptanceDialog(quoteId: quote.id),
    );
  }

  void _showQuoteDetails(BuildContext context) {
    showDialog<void>(
      context: context,
      builder: (context) => QuoteDetailsDialog(quoteId: quote.id),
    );
  }
}

// ============================================================================
// SEZIONE: Pacchetti con ricerca e filtri
// ============================================================================
class _PackagesSectionWithFilters extends ConsumerStatefulWidget {
  const _PackagesSectionWithFilters({
    required this.clientId,
    required this.isExpanded,
    required this.onToggle,
    required this.isOffline,
  });

  final String clientId;
  final bool isExpanded;
  final VoidCallback onToggle;
  final bool isOffline;

  @override
  ConsumerState<_PackagesSectionWithFilters> createState() =>
      _PackagesSectionWithFiltersState();
}

class _PackagesSectionWithFiltersState
    extends ConsumerState<_PackagesSectionWithFilters> {
  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final searchQuery = ref.watch(packagesSearchQueryProvider);
    final statusFilter = ref.watch(packagesStatusFilterProvider);
    final packagesAsync = ref.watch(
      packagesByClientStreamProvider(widget.clientId),
    );

    return Card(
      clipBehavior: Clip.antiAlias,
      child: Column(
        children: [
          InkWell(
            onTap: widget.onToggle,
            child: Padding(
              padding: EdgeInsets.all(kIsWindows ? 16 : 16.sp),
              child: Row(
                children: [
                  Icon(Symbols.inventory_2_rounded, color: cs.primary),
                  SizedBox(width: kIsWindows ? 12 : 12.w),
                  Expanded(
                    child: Text(
                      'Pacchetti',
                      style: TextStyle(
                        fontSize: kIsWindows ? 18 : 18.sp,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                  Icon(
                    widget.isExpanded
                        ? Symbols.expand_less_rounded
                        : Symbols.expand_more_rounded,
                    color: cs.outline,
                  ),
                ],
              ),
            ),
          ),
          if (widget.isExpanded) ...[
            // Filtri
            Container(
              padding: EdgeInsets.symmetric(
                horizontal: kIsWindows ? 16 : 16.sp,
                vertical: kIsWindows ? 8 : 8.sp,
              ),
              decoration: BoxDecoration(
                color: cs.surfaceContainerHighest.withValues(alpha: 0.3),
                border: Border(
                  top: BorderSide(color: cs.outline.withValues(alpha: 0.2)),
                  bottom: BorderSide(color: cs.outline.withValues(alpha: 0.2)),
                ),
              ),
              child: Row(
                children: [
                  Expanded(
                    child: TextField(
                      decoration: InputDecoration(
                        hintText: 'Cerca pacchetto...',
                        prefixIcon: const Icon(
                          Symbols.search_rounded,
                          size: 20,
                        ),
                        isDense: true,
                        filled: true,
                        fillColor: cs.surface,
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(8),
                          borderSide: BorderSide.none,
                        ),
                        contentPadding: EdgeInsets.symmetric(
                          horizontal: kIsWindows ? 12 : 12.w,
                          vertical: kIsWindows ? 8 : 8.sp,
                        ),
                      ),
                      onChanged: (value) => ref
                          .read(packagesSearchQueryProvider.notifier)
                          .set(value),
                    ),
                  ),
                  SizedBox(width: kIsWindows ? 8 : 8.w),
                  PopupMenuButton<PackageStatusFilter>(
                    initialValue: statusFilter,
                    onSelected: (value) => ref
                        .read(packagesStatusFilterProvider.notifier)
                        .set(value),
                    itemBuilder: (context) => [
                      const PopupMenuItem(
                        value: PackageStatusFilter.all,
                        child: Text('Tutti'),
                      ),
                      const PopupMenuItem(
                        value: PackageStatusFilter.active,
                        child: Text('Attivi'),
                      ),
                      const PopupMenuItem(
                        value: PackageStatusFilter.completed,
                        child: Text('Completati'),
                      ),
                      const PopupMenuItem(
                        value: PackageStatusFilter.expired,
                        child: Text('Scaduti'),
                      ),
                    ],
                    child: Chip(
                      avatar: const Icon(Symbols.filter_list_rounded, size: 18),
                      label: Text(switch (statusFilter) {
                        PackageStatusFilter.all => 'Tutti',
                        PackageStatusFilter.active => 'Attivi',
                        PackageStatusFilter.completed => 'Completati',
                        PackageStatusFilter.expired => 'Scaduti',
                      }),
                    ),
                  ),
                ],
              ),
            ),
            packagesAsync.when(
              data: (packages) {
                // Apply filters
                var filtered = packages;
                if (searchQuery.isNotEmpty) {
                  filtered = filtered
                      .where(
                        (p) => p.name.toLowerCase().contains(
                          searchQuery.toLowerCase(),
                        ),
                      )
                      .toList();
                }
                if (statusFilter != PackageStatusFilter.all) {
                  filtered = filtered
                      .where(
                        (p) => switch (statusFilter) {
                          PackageStatusFilter.active => p.status == 'active',
                          PackageStatusFilter.completed =>
                            p.status == 'completed',
                          PackageStatusFilter.expired => p.status == 'expired',
                          _ => true,
                        },
                      )
                      .toList();
                }

                if (filtered.isEmpty) {
                  return Padding(
                    padding: EdgeInsets.all(kIsWindows ? 24 : 24.sp),
                    child: Column(
                      children: [
                        Icon(
                          Symbols.inventory_2_rounded,
                          size: kIsWindows ? 48 : 48.sp,
                          color: cs.outline,
                        ),
                        SizedBox(height: kIsWindows ? 12 : 12.h),
                        Text(
                          searchQuery.isEmpty &&
                                  statusFilter == PackageStatusFilter.all
                              ? 'Nessun pacchetto'
                              : 'Nessun risultato con i filtri attuali',
                          style: TextStyle(
                            color: cs.outline,
                            fontSize: kIsWindows ? 16 : 16.sp,
                          ),
                        ),
                      ],
                    ),
                  );
                }

                return ConstrainedBox(
                  constraints: BoxConstraints(
                    maxHeight: MediaQuery.of(context).size.height * 0.5,
                  ),
                  child: ListView.separated(
                    shrinkWrap: true,
                    padding: EdgeInsets.fromLTRB(
                      kIsWindows ? 16 : 16.sp,
                      kIsWindows ? 16 : 16.sp,
                      kIsWindows ? 16 : 16.sp,
                      kIsWindows ? 16 : 16.sp,
                    ),
                    itemCount: filtered.length,
                    separatorBuilder: (_, __) =>
                        SizedBox(height: kIsWindows ? 8 : 8.h),
                    itemBuilder: (context, index) =>
                        _PackageCardListTile(package: filtered[index]),
                  ),
                );
              },
              loading: () => const Padding(
                padding: EdgeInsets.all(24),
                child: Center(child: CircularProgressIndicator()),
              ),
              error: (error, _) => Padding(
                padding: const EdgeInsets.all(16),
                child: Text(
                  'Errore: $error',
                  style: TextStyle(color: cs.error),
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class _PackageCardListTile extends StatelessWidget {
  const _PackageCardListTile({required this.package});

  final PackageData package;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final isActive = package.status == 'active';
    final isCompleted = package.status == 'completed';
    final progress = package.totalPrice > 0
        ? package.paidAmount / package.totalPrice
        : 0.0;

    return Card(
      margin: EdgeInsets.zero,
      child: InkWell(
        onTap: () {
          Navigator.push<void>(
            context,
            MaterialPageRoute(
              builder: (_) => PackageDetailsPage(packageId: package.id),
            ),
          );
        },
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: EdgeInsets.all(kIsWindows ? 12 : 12.sp),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Icon(
                    isActive
                        ? Symbols.inventory_2_rounded
                        : (isCompleted
                              ? Symbols.check_circle_rounded
                              : Symbols.error_rounded),
                    color: isActive
                        ? cs.primary
                        : (isCompleted ? Colors.green : cs.error),
                  ),
                  SizedBox(width: kIsWindows ? 8 : 8.w),
                  Expanded(
                    child: Text(
                      package.name,
                      style: const TextStyle(fontWeight: FontWeight.w500),
                    ),
                  ),
                  Chip(
                    label: Text(
                      isActive
                          ? 'Attivo'
                          : (isCompleted ? 'Completato' : 'Scaduto'),
                      style: TextStyle(fontSize: kIsWindows ? 10 : 10.sp),
                    ),
                    backgroundColor: isActive
                        ? cs.primaryContainer
                        : (isCompleted
                              ? Colors.green.withValues(alpha: 0.2)
                              : cs.errorContainer),
                    padding: EdgeInsets.zero,
                  ),
                ],
              ),
              SizedBox(height: kIsWindows ? 8 : 8.h),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text('Totale: €${package.totalPrice.toStringAsFixed(2)}'),
                  Text('Pagato: €${package.paidAmount.toStringAsFixed(2)}'),
                ],
              ),
              SizedBox(height: kIsWindows ? 4 : 4.h),
              LinearProgressIndicator(
                value: progress.clamp(0.0, 1.0),
                backgroundColor: cs.surfaceContainerHighest,
                valueColor: AlwaysStoppedAnimation<Color>(
                  progress >= 1.0 ? Colors.green : cs.primary,
                ),
              ),
              if (package.expiresAt != null) ...[
                SizedBox(height: kIsWindows ? 4 : 4.h),
                Text(
                  'Scade il: ${_formatDate(package.expiresAt!)}',
                  style: TextStyle(
                    fontSize: kIsWindows ? 11 : 11.sp,
                    color: cs.outline,
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }

  String _formatDate(DateTime date) {
    return '${date.day.toString().padLeft(2, '0')}/${date.month.toString().padLeft(2, '0')}/${date.year}';
  }
}

// ============================================================================
// SEZIONE: Prodotti con ricerca
// ============================================================================
class _ProductsSectionWithSearch extends ConsumerStatefulWidget {
  const _ProductsSectionWithSearch({
    required this.clientId,
    required this.isExpanded,
    required this.onToggle,
    required this.onSellProduct,
    required this.isOffline,
  });

  final String clientId;
  final bool isExpanded;
  final VoidCallback onToggle;
  final VoidCallback onSellProduct;
  final bool isOffline;

  @override
  ConsumerState<_ProductsSectionWithSearch> createState() =>
      _ProductsSectionWithSearchState();
}

class _ProductsSectionWithSearchState
    extends ConsumerState<_ProductsSectionWithSearch> {
  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final searchQuery = ref.watch(productsSearchQueryProvider);
    final salesAsync = ref.watch(
      productSalesByClientStreamProvider(widget.clientId),
    );

    return Card(
      clipBehavior: Clip.antiAlias,
      child: Column(
        children: [
          InkWell(
            onTap: widget.onToggle,
            child: Padding(
              padding: EdgeInsets.all(kIsWindows ? 16 : 16.sp),
              child: Row(
                children: [
                  Icon(Symbols.shopping_bag_rounded, color: cs.primary),
                  SizedBox(width: kIsWindows ? 12 : 12.w),
                  Expanded(
                    child: Text(
                      'Prodotti Acquistati',
                      style: TextStyle(
                        fontSize: kIsWindows ? 18 : 18.sp,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                  if (!widget.isOffline)
                    IconButton(
                      icon: const Icon(Symbols.add_rounded),
                      tooltip: 'Vendi prodotto',
                      onPressed: widget.onSellProduct,
                    ),
                  Icon(
                    widget.isExpanded
                        ? Symbols.expand_less_rounded
                        : Symbols.expand_more_rounded,
                    color: cs.outline,
                  ),
                ],
              ),
            ),
          ),
          if (widget.isExpanded) ...[
            // Filtro ricerca
            if (salesAsync.hasValue &&
                salesAsync.value != null &&
                salesAsync.value!.isNotEmpty)
              Container(
                padding: EdgeInsets.symmetric(
                  horizontal: kIsWindows ? 16 : 16.sp,
                  vertical: kIsWindows ? 8 : 8.sp,
                ),
                decoration: BoxDecoration(
                  color: cs.surfaceContainerHighest.withValues(alpha: 0.3),
                  border: Border(
                    top: BorderSide(color: cs.outline.withValues(alpha: 0.2)),
                    bottom: BorderSide(
                      color: cs.outline.withValues(alpha: 0.2),
                    ),
                  ),
                ),
                child: TextField(
                  decoration: InputDecoration(
                    hintText: 'Cerca prodotto...',
                    prefixIcon: const Icon(Symbols.search_rounded, size: 20),
                    isDense: true,
                    filled: true,
                    fillColor: cs.surface,
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(8),
                      borderSide: BorderSide.none,
                    ),
                    contentPadding: EdgeInsets.symmetric(
                      horizontal: kIsWindows ? 12 : 12.w,
                      vertical: kIsWindows ? 8 : 8.sp,
                    ),
                  ),
                  onChanged: (value) =>
                      ref.read(productsSearchQueryProvider.notifier).set(value),
                ),
              ),
            salesAsync.when(
              data: (sales) {
                // Apply search filter
                var filtered = sales;
                if (searchQuery.isNotEmpty) {
                  filtered = filtered
                      .where(
                        (s) => s.lockedProductName.toLowerCase().contains(
                          searchQuery.toLowerCase(),
                        ),
                      )
                      .toList();
                }

                if (filtered.isEmpty) {
                  return Padding(
                    padding: EdgeInsets.all(kIsWindows ? 24 : 24.sp),
                    child: Column(
                      children: [
                        Icon(
                          Symbols.shopping_bag_rounded,
                          size: kIsWindows ? 48 : 48.sp,
                          color: cs.outline,
                        ),
                        SizedBox(height: kIsWindows ? 12 : 12.h),
                        Text(
                          searchQuery.isEmpty
                              ? 'Nessun prodotto acquistato'
                              : 'Nessun risultato',
                          style: TextStyle(
                            color: cs.outline,
                            fontSize: kIsWindows ? 16 : 16.sp,
                          ),
                        ),
                      ],
                    ),
                  );
                }

                return ConstrainedBox(
                  constraints: BoxConstraints(
                    maxHeight: MediaQuery.of(context).size.height * 0.5,
                  ),
                  child: ListView.separated(
                    shrinkWrap: true,
                    padding: EdgeInsets.fromLTRB(
                      kIsWindows ? 16 : 16.sp,
                      kIsWindows ? 16 : 16.sp,
                      kIsWindows ? 16 : 16.sp,
                      kIsWindows ? 16 : 16.sp,
                    ),
                    itemCount: filtered.length,
                    separatorBuilder: (_, __) =>
                        SizedBox(height: kIsWindows ? 8 : 8.h),
                    itemBuilder: (context, index) {
                      final sale = filtered[index];
                      return Card(
                        margin: EdgeInsets.zero,
                        child: ListTile(
                          leading: Icon(
                            Symbols.shopping_bag_rounded,
                            color: cs.primary,
                          ),
                          title: Text(sale.lockedProductName),
                          subtitle: Text(
                            'Qtà: ${sale.quantity} • ${_formatDate(sale.createdAt)}',
                          ),
                          trailing: Text(
                            '€${sale.lineTotal.toStringAsFixed(2)}',
                            style: TextStyle(
                              fontWeight: FontWeight.bold,
                              fontSize: kIsWindows ? 16 : 16.sp,
                            ),
                          ),
                        ),
                      );
                    },
                  ),
                );
              },
              loading: () => const Padding(
                padding: EdgeInsets.all(24),
                child: Center(child: CircularProgressIndicator()),
              ),
              error: (error, _) => Padding(
                padding: const EdgeInsets.all(16),
                child: Text(
                  'Errore: $error',
                  style: TextStyle(color: cs.error),
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }

  String _formatDate(DateTime date) {
    return '${date.day.toString().padLeft(2, '0')}/${date.month.toString().padLeft(2, '0')}/${date.year}';
  }
}
