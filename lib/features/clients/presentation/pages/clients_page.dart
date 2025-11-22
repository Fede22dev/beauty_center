import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:material_symbols_icons/symbols.dart';

import '../../../../core/constants/app_constants.dart';
import '../../../../core/contacts/contact_sync_helper.dart';
import '../../../../core/database/app_database.dart';
import '../../../../core/logging/app_logger.dart';
import '../widgets/add_edit_client_dialog.dart';
import '../widgets/sections/clients_search_add_bar_section.dart';
import '../widgets/sections/list/clients_list_section.dart';
import 'client_details_page.dart';

class ClientsPage extends StatefulWidget {
  const ClientsPage({super.key});

  @override
  State<ClientsPage> createState() => _ClientsPageState();
}

class _ClientsPageState extends State<ClientsPage>
    with AutomaticKeepAliveClientMixin {
  @override
  bool get wantKeepAlive => true;

  static final _log = AppLogger.getLogger(name: 'ClientsPage');

  late final ScrollController _scrollController;
  late final double _scrollbarThickness;
  var _isScrollbarNeeded = false;

  // Search state
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
    _log.finest('Clients search query: $query');
  }

  void _onClientTap(final String clientId) {
    _log.fine('Client tapped: $clientId');
    Navigator.push(
      context,
      MaterialPageRoute<bool>(
        builder: (_) => ClientDetailsPage(clientId: clientId),
      ),
    ).then((final result) {
      if (result == null) return;

      if (result) {
        _log.fine('Client was deleted');
      }
    });
  }

  Future<void> _onAddClient() async {
    _log.fine('Add client button pressed');

    String? action;

    // 1. Determine flow based on Platform
    if (kIsWindows) {
      // Desktop: Skip selection, force manual entry
      action = 'manual';
    } else {
      // Mobile: Ask user (Manual vs Import)
      final colorScheme = Theme.of(context).colorScheme;

      action = await showDialog<String>(
        context: context,
        builder: (final ctx) => SimpleDialog(
          title: Text('Nuovo Cliente', style: TextStyle(fontSize: 24.sp)),
          children: [
            SimpleDialogOption(
              onPressed: () => Navigator.pop(ctx, 'manual'),
              padding: EdgeInsets.symmetric(vertical: 16.h, horizontal: 28.w),
              child: Row(
                children: [
                  Icon(
                    Symbols.edit_note_rounded,
                    color: colorScheme.primary,
                    size: 26.sp,
                  ),
                  SizedBox(width: 14.w),
                  Text(
                    'Inserisci manualmente',
                    style: TextStyle(fontSize: 16.sp),
                  ),
                ],
              ),
            ),
            SimpleDialogOption(
              onPressed: () => Navigator.pop(ctx, 'import'),
              padding: EdgeInsets.symmetric(vertical: 16.h, horizontal: 28.w),
              child: Row(
                children: [
                  Icon(
                    Symbols.contacts_rounded,
                    color: colorScheme.primary,
                    size: 26.sp,
                  ),
                  SizedBox(width: 14.w),
                  Text('Importa da Rubrica', style: TextStyle(fontSize: 16.sp)),
                ],
              ),
            ),
          ],
        ),
      );
    }

    // 2. Handle cancellation (User dismissed dialog on mobile)
    if (action == null) return;

    Client? preFilledClient;

    // 3. Handle Import Logic (Only triggers if 'import' was selected)
    if (action == 'import') {
      preFilledClient = await ContactSyncHelper.pickContactAsClient();
      if (preFilledClient == null) return; // User cancelled contact picker
    }

    if (!mounted) return;

    // 4. Open Form Dialog
    final result = await showDialog<bool>(
      context: context,
      builder: (_) => AddEditClientDialog(client: preFilledClient),
    );

    if (result == true) {
      _log.fine(
        'Client was added, list should refresh automatically via stream',
      );
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

    _log.fine('build');

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
          child: SectionSearchAddBar(
            onSearchChanged: _onSearchChanged,
            onAddClient: _onAddClient,
          ),
        ),
        Expanded(
          child: Scrollbar(
            controller: _scrollController,
            thickness: _scrollbarThickness,
            thumbVisibility: kIsWindows,
            interactive: kIsWindows,
            child: SectionClientList(
              searchQuery: _searchQuery,
              onClientTap: _onClientTap,
              scrollController: _scrollController,
            ),
          ),
        ),
        const SafeArea(top: false, child: SizedBox.shrink()),
      ],
    );
  }
}
