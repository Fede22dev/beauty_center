import 'package:beauty_center/core/tabs/app_tabs.dart';
import 'package:beauty_center/core/widgets/custom_snackbar.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:material_symbols_icons/symbols.dart';

import '../../../../core/constants/app_constants.dart';
import '../../../../core/logging/app_logger.dart';
import '../../providers/treatments_providers.dart';
import '../widgets/add_edit_service_dialog.dart';
import '../widgets/sections/list/services_list_section.dart';
import '../widgets/sections/treatments_search_add_bar_section.dart';

class TreatmentsPage extends ConsumerStatefulWidget {
  const TreatmentsPage({super.key});

  @override
  ConsumerState<TreatmentsPage> createState() => _TreatmentsPageState();
}

class _TreatmentsPageState extends ConsumerState<TreatmentsPage>
    with AutomaticKeepAliveClientMixin {
  @override
  bool get wantKeepAlive => true;

  static final _log = AppLogger.getLogger(name: 'TreatmentsPage');

  late final ScrollController _scrollController;
  late final double _scrollbarThickness;
  var _isScrollbarNeeded = false;
  var _searchQuery = '';

  @override
  void initState() {
    super.initState();
    _scrollController = ScrollController();
    _scrollbarThickness = kIsWindows ? 8.0 : 0.0;
  }

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  void _onSearchChanged(final String query) {
    setState(() => _searchQuery = query);
    _log.finest('Treatments search query: $query');
  }

  Future<void> _onAddTreatment() async {
    _log.finest('Add treatment button pressed');

    final result = await showDialog<bool>(
      context: context,
      builder: (_) => const AddEditServiceDialog(),
    );

    if (result == true) {
      _log.finest(
        'Service was added, list should refresh automatically via stream',
      );
    }
  }

  void _onServiceTap(final String serviceId) {
    _log.finest('Service tapped: $serviceId');
    _onServiceEdit(serviceId);
  }

  Future<void> _onServiceEdit(final String serviceId) async {
    final service = await ref
        .read(servicesActionsProvider)
        .getServiceById(serviceId);
    if (service == null || !mounted) return;

    final result = await showDialog<bool>(
      context: context,
      builder: (_) =>
          AddEditServiceDialog(service: service, mode: ServiceDialogMode.edit),
    );

    if (result == true) {
      _log.finest('Service was edited');
    }
  }

  Future<void> _onServiceDelete(final String serviceId) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (final ctx) => AlertDialog(
        icon: Icon(
          Symbols.warning_rounded,
          color: Theme.of(ctx).colorScheme.error,
          size: kIsWindows ? 32 : 32.sp,
        ),
        title: const Text('Elimina trattamento'),
        content: const Text(
          "Sei sicuro di voler eliminare questo trattamento? L'azione è irreversibile.",
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Annulla'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: FilledButton.styleFrom(
              backgroundColor: Theme.of(ctx).colorScheme.error,
            ),
            child: const Text('Elimina'),
          ),
        ],
      ),
    );

    if (confirmed != true || !mounted) return;

    try {
      await ref.read(servicesActionsProvider).deleteService(serviceId);
      if (mounted) {
        showCustomSnackBar(
          context: context,
          message: 'Trattamento eliminato con successo',
          okColor: AppTabs.treatments.color,
        );
      }
    } catch (e, stackTrace) {
      _log.severe('Error deleting service', e, stackTrace);
      if (mounted) {
        showCustomSnackBar(
          context: context,
          message: "Errore durante l'eliminazione",
          okColor: AppTabs.treatments.color,
        );
      }
    }
  }

  @override
  Widget build(final BuildContext context) {
    super.build(context);

    if (_scrollbarThickness > 0) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted) return;
        final isNeeded =
            _scrollController.hasClients &&
            _scrollController.position.maxScrollExtent > 0;
        if (isNeeded != _isScrollbarNeeded) {
          setState(() => _isScrollbarNeeded = isNeeded);
        }
      });
    }

    _log.finest('build');

    return Column(
      children: [
        Container(
          padding: EdgeInsets.fromLTRB(
            kIsWindows ? 16 : 8.w,
            kIsWindows ? 12 : 8.h,
            kIsWindows ? 16 : 8.w,
            kIsWindows ? 12 : 8.h,
          ),
          decoration: BoxDecoration(
            color: Theme.of(context).colorScheme.surface,
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.05),
                blurRadius: 4,
                offset: const Offset(0, 2),
              ),
            ],
          ),
          child: SectionTreatmentsSearchAddBar(
            onSearchChanged: _onSearchChanged,
            onAddTreatment: _onAddTreatment,
          ),
        ),
        Expanded(
          child: Scrollbar(
            controller: _scrollController,
            thickness: _scrollbarThickness,
            thumbVisibility: kIsWindows,
            interactive: kIsWindows,
            child: SectionServiceList(
              searchQuery: _searchQuery,
              onServiceTap: _onServiceTap,
              onServiceEdit: _onServiceEdit,
              onServiceDelete: _onServiceDelete,
              scrollController: _scrollController,
            ),
          ),
        ),
        const SafeArea(top: false, child: SizedBox.shrink()),
      ],
    );
  }
}
