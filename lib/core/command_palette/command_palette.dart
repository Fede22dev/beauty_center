import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:material_symbols_icons/symbols.dart';

import '../../features/clients/providers/clients_providers.dart';
import '../../home/providers/home_tab_provider.dart';
import '../constants/app_constants.dart';
import '../database/app_database.dart';
import '../tabs/app_tabs.dart';
import '../utils/fuzzy_search.dart';

/// Command Palette Action Types
enum CommandActionType {
  navigate,
  searchClient,
  createAppointment,
  toggleTheme,
  openSettings,
  quickAction,
}

/// Command Palette Item
class CommandPaletteItem {
  final String id;
  final String title;
  final String subtitle;
  final IconData icon;
  final Color? iconColor;
  final CommandActionType type;
  final dynamic payload;
  final String searchKeywords;
  final double score;

  CommandPaletteItem({
    required this.id,
    required this.title,
    required this.subtitle,
    required this.icon,
    this.iconColor,
    required this.type,
    this.payload,
    this.searchKeywords = '',
    this.score = 0,
  });

  CommandPaletteItem copyWith({double? score}) {
    return CommandPaletteItem(
      id: id,
      title: title,
      subtitle: subtitle,
      icon: icon,
      iconColor: iconColor,
      type: type,
      payload: payload,
      searchKeywords: searchKeywords,
      score: score ?? this.score,
    );
  }
}

/// Command Palette Provider
final commandPaletteProvider =
    NotifierProvider<CommandPaletteNotifier, CommandPaletteState>(() {
      return CommandPaletteNotifier();
    });

class CommandPaletteState {
  final bool isOpen;
  final String query;
  final List<CommandPaletteItem> items;
  final int selectedIndex;
  final bool isLoading;

  CommandPaletteState({
    this.isOpen = false,
    this.query = '',
    this.items = const [],
    this.selectedIndex = 0,
    this.isLoading = false,
  });

  CommandPaletteState copyWith({
    bool? isOpen,
    String? query,
    List<CommandPaletteItem>? items,
    int? selectedIndex,
    bool? isLoading,
  }) {
    return CommandPaletteState(
      isOpen: isOpen ?? this.isOpen,
      query: query ?? this.query,
      items: items ?? this.items,
      selectedIndex: selectedIndex ?? this.selectedIndex,
      isLoading: isLoading ?? this.isLoading,
    );
  }
}

class CommandPaletteNotifier extends Notifier<CommandPaletteState> {
  @override
  CommandPaletteState build() {
    return CommandPaletteState();
  }

  void open() {
    state = CommandPaletteState(
      isOpen: true,
      query: '',
      items: _buildStaticItems(),
      selectedIndex: 0,
    );
  }

  void close() {
    state = state.copyWith(isOpen: false);
  }

  void setQuery(String query) {
    state = state.copyWith(query: query, isLoading: true);

    // Debounce search
    Future.delayed(const Duration(milliseconds: 150), () {
      _performSearch(query);
    });
  }

  void selectNext() {
    if (state.items.isEmpty) return;
    final nextIndex = (state.selectedIndex + 1) % state.items.length;
    state = state.copyWith(selectedIndex: nextIndex);
  }

  void selectPrevious() {
    if (state.items.isEmpty) return;
    final prevIndex = state.selectedIndex == 0
        ? state.items.length - 1
        : state.selectedIndex - 1;
    state = state.copyWith(selectedIndex: prevIndex);
  }

  void selectItem(int index) {
    if (index < 0 || index >= state.items.length) return;
    state = state.copyWith(selectedIndex: index);
    _executeSelected();
  }

  void _performSearch(String query) {
    if (query.isEmpty) {
      state = state.copyWith(items: _buildStaticItems(), isLoading: false);
      return;
    }

    final allItems = <CommandPaletteItem>[];

    // Add static navigation items
    allItems.addAll(_buildStaticItems());

    // Search clients using fuzzy search
    final clientsAsync = ref.read(clientsStreamProvider);
    clientsAsync.whenData((clients) {
      final filtered = FuzzySearch.filterAndSort<Client>(
        query,
        clients.take(20).toList(),
        (c) => '${c.firstName} ${c.lastName} ${c.phoneNumber}',
        threshold: 0.5,
      );

      final clientItems = filtered.take(5).map((client) {
        return CommandPaletteItem(
          id: 'client_${client.id}',
          title: '${client.firstName} ${client.lastName}',
          subtitle: client.phoneNumber,
          icon: Symbols.person_rounded,
          iconColor: AppTabs.clients.color,
          type: CommandActionType.searchClient,
          payload: client,
          searchKeywords:
              '${client.firstName} ${client.lastName} ${client.phoneNumber}',
        );
      });

      allItems.addAll(clientItems);

      // Score and sort all items
      final scored = allItems.map((item) {
        final score = FuzzySearch.matchScore(query, item.searchKeywords);
        return item.copyWith(score: score.toDouble());
      }).toList();

      scored.sort((a, b) => b.score.compareTo(a.score));

      state = state.copyWith(
        items: scored.take(10).toList(),
        selectedIndex: 0,
        isLoading: false,
      );
    });
  }

  List<CommandPaletteItem> _buildStaticItems() {
    return [
      // Navigation commands
      CommandPaletteItem(
        id: 'nav_appointments',
        title: 'Appuntamenti',
        subtitle: 'Vai alla pagina appuntamenti',
        icon: Symbols.calendar_month_rounded,
        iconColor: AppTabs.appointments.color,
        type: CommandActionType.navigate,
        payload: AppTabs.appointments,
        searchKeywords: 'appuntamenti calendario agenda',
      ),
      CommandPaletteItem(
        id: 'nav_clients',
        title: 'Clienti',
        subtitle: 'Vai alla pagina clienti',
        icon: Symbols.patient_list_rounded,
        iconColor: AppTabs.clients.color,
        type: CommandActionType.navigate,
        payload: AppTabs.clients,
        searchKeywords: 'clienti anagrafica persone',
      ),
      CommandPaletteItem(
        id: 'nav_treatments',
        title: 'Trattamenti',
        subtitle: 'Vai alla pagina trattamenti',
        icon: Symbols.massage_rounded,
        iconColor: AppTabs.treatments.color,
        type: CommandActionType.navigate,
        payload: AppTabs.treatments,
        searchKeywords: 'trattamenti servizi massaggi',
      ),
      CommandPaletteItem(
        id: 'nav_products',
        title: 'Prodotti',
        subtitle: 'Vai alla pagina prodotti',
        icon: Symbols.experiment_rounded,
        iconColor: AppTabs.products.color,
        type: CommandActionType.navigate,
        payload: AppTabs.products,
        searchKeywords: 'prodotti fornitori magazzino',
      ),
      CommandPaletteItem(
        id: 'nav_statistics',
        title: 'Statistiche',
        subtitle: 'Vai alla pagina statistiche',
        icon: Symbols.show_chart_rounded,
        iconColor: AppTabs.statistics.color,
        type: CommandActionType.navigate,
        payload: AppTabs.statistics,
        searchKeywords: 'statistiche report analytics grafici',
      ),
      CommandPaletteItem(
        id: 'nav_settings',
        title: 'Impostazioni',
        subtitle: 'Vai alla pagina impostazioni',
        icon: Symbols.settings_rounded,
        iconColor: AppTabs.settings.color,
        type: CommandActionType.navigate,
        payload: AppTabs.settings,
        searchKeywords: 'impostazioni configurazione preferenze',
      ),

      // Quick actions
      CommandPaletteItem(
        id: 'action_new_appointment',
        title: 'Nuovo Appuntamento',
        subtitle: 'Crea un nuovo appuntamento',
        icon: Symbols.add_rounded,
        iconColor: Colors.green,
        type: CommandActionType.createAppointment,
        searchKeywords: 'nuovo appuntamento crea aggiungi',
      ),
      CommandPaletteItem(
        id: 'action_toggle_theme',
        title: 'Cambia Tema',
        subtitle: 'Passa da chiaro a scuro',
        icon: Symbols.brightness_1_rounded,
        iconColor: Colors.orange,
        type: CommandActionType.toggleTheme,
        searchKeywords: 'tema chiaro scuro dark mode',
      ),
    ];
  }

  void _executeSelected() {
    if (state.items.isEmpty) return;
    final item = state.items[state.selectedIndex];

    switch (item.type) {
      case CommandActionType.navigate:
        final tab = item.payload as AppTabs;
        ref.read(homeTabProvider.notifier).setIndex(tab.index);
        break;

      case CommandActionType.searchClient:
        ref.read(homeTabProvider.notifier).setIndex(AppTabs.clients.index);
        // Navigate to client details would need navigator
        break;

      case CommandActionType.createAppointment:
        ref.read(homeTabProvider.notifier).setIndex(AppTabs.appointments.index);
        break;

      case CommandActionType.toggleTheme:
        // Toggle theme through provider
        break;

      case CommandActionType.openSettings:
        ref.read(homeTabProvider.notifier).setIndex(AppTabs.settings.index);
        break;

      case CommandActionType.quickAction:
        break;
    }

    close();
  }
}

/// Command Palette Widget
class CommandPalette extends ConsumerWidget {
  const CommandPalette({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(commandPaletteProvider);

    if (!state.isOpen) return const SizedBox.shrink();

    return Navigator(
      onGenerateRoute: (_) => MaterialPageRoute(
        builder: (_) => Material(
          color: Colors.transparent,
          child: Stack(
            children: [
              // Backdrop
              GestureDetector(
                onTap: () => ref.read(commandPaletteProvider.notifier).close(),
                child: Container(color: Colors.black54),
              ),

              // Command Palette Card
              Center(
                child:
                    Container(
                          margin: EdgeInsets.symmetric(
                            horizontal: kIsWindows ? 100 : 20.w,
                          ),
                          constraints: BoxConstraints(
                            maxWidth: 600,
                            maxHeight: kIsWindows ? 500 : 400.h,
                          ),
                          decoration: BoxDecoration(
                            color: Theme.of(context).colorScheme.surface,
                            borderRadius: BorderRadius.circular(16),
                            boxShadow: [
                              BoxShadow(
                                color: Colors.black.withValues(alpha: 0.3),
                                blurRadius: 20,
                                offset: const Offset(0, 10),
                              ),
                            ],
                          ),
                          child: ClipRRect(
                            borderRadius: BorderRadius.circular(16),
                            child: Column(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                // Search Input
                                _buildSearchInput(context, ref, state),

                                // Results List
                                Flexible(
                                  child: _buildResultsList(context, ref, state),
                                ),

                                // Footer
                                _buildFooter(context),
                              ],
                            ),
                          ),
                        )
                        .animate()
                        .scale(
                          begin: const Offset(0.95, 0.95),
                          end: const Offset(1, 1),
                          duration: 200.ms,
                        )
                        .fadeIn(duration: 200.ms),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildSearchInput(
    BuildContext context,
    WidgetRef ref,
    CommandPaletteState state,
  ) {
    final colorScheme = Theme.of(context).colorScheme;

    return Container(
      padding: EdgeInsets.all(kIsWindows ? 16 : 16.sp),
      decoration: BoxDecoration(
        border: Border(
          bottom: BorderSide(
            color: colorScheme.outlineVariant.withValues(alpha: 0.5),
          ),
        ),
      ),
      child: Row(
        children: [
          Icon(
            Symbols.search_rounded,
            color: colorScheme.onSurfaceVariant,
            size: kIsWindows ? 24 : 24.sp,
          ),
          SizedBox(width: kIsWindows ? 12 : 12.w),
          Expanded(
            child: TextField(
              autofocus: true,
              onChanged: (value) =>
                  ref.read(commandPaletteProvider.notifier).setQuery(value),
              style: TextStyle(
                fontSize: kIsWindows ? 16 : 16.sp,
                color: colorScheme.onSurface,
              ),
              decoration: InputDecoration(
                hintText: 'Cerca pagine, clienti, azioni...',
                hintStyle: TextStyle(color: colorScheme.onSurfaceVariant),
                border: InputBorder.none,
                contentPadding: EdgeInsets.zero,
              ),
            ),
          ),
          if (state.isLoading)
            SizedBox(
              width: kIsWindows ? 20 : 20.sp,
              height: kIsWindows ? 20 : 20.sp,
              child: CircularProgressIndicator(
                strokeWidth: 2,
                color: colorScheme.primary,
              ),
            )
          else
            Container(
              padding: EdgeInsets.symmetric(
                horizontal: kIsWindows ? 8 : 8.w,
                vertical: kIsWindows ? 4 : 4.sp,
              ),
              decoration: BoxDecoration(
                color: colorScheme.surfaceContainerHighest,
                borderRadius: BorderRadius.circular(6),
              ),
              child: Text(
                'ESC',
                style: TextStyle(
                  fontSize: kIsWindows ? 12 : 12.sp,
                  fontWeight: FontWeight.bold,
                  color: colorScheme.onSurfaceVariant,
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildResultsList(
    BuildContext context,
    WidgetRef ref,
    CommandPaletteState state,
  ) {
    final colorScheme = Theme.of(context).colorScheme;

    if (state.items.isEmpty) {
      return Container(
        padding: EdgeInsets.all(kIsWindows ? 32 : 32.sp),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Symbols.search_off_rounded,
              color: colorScheme.outline,
              size: kIsWindows ? 48 : 48.sp,
            ),
            SizedBox(height: kIsWindows ? 16 : 16.h),
            Text(
              'Nessun risultato',
              style: TextStyle(
                color: colorScheme.onSurfaceVariant,
                fontSize: kIsWindows ? 14 : 14.sp,
              ),
            ),
          ],
        ),
      );
    }

    return ListView.builder(
      shrinkWrap: true,
      itemCount: state.items.length,
      itemBuilder: (context, index) {
        final item = state.items[index];
        final isSelected = index == state.selectedIndex;

        return InkWell(
          onTap: () =>
              ref.read(commandPaletteProvider.notifier).selectItem(index),
          child: Container(
            padding: EdgeInsets.symmetric(
              horizontal: kIsWindows ? 16 : 16.sp,
              vertical: kIsWindows ? 12 : 12.sp,
            ),
            decoration: BoxDecoration(
              color: isSelected
                  ? colorScheme.primaryContainer.withValues(alpha: 0.5)
                  : Colors.transparent,
              border: Border(
                left: BorderSide(
                  color: isSelected ? colorScheme.primary : Colors.transparent,
                  width: 3,
                ),
              ),
            ),
            child: Row(
              children: [
                Container(
                  padding: EdgeInsets.all(kIsWindows ? 8 : 8.sp),
                  decoration: BoxDecoration(
                    color: (item.iconColor ?? colorScheme.primary).withValues(
                      alpha: 0.1,
                    ),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Icon(
                    item.icon,
                    color: item.iconColor ?? colorScheme.primary,
                    size: kIsWindows ? 20 : 20.sp,
                  ),
                ),
                SizedBox(width: kIsWindows ? 12 : 12.w),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        item.title,
                        style: TextStyle(
                          fontSize: kIsWindows ? 14 : 14.sp,
                          fontWeight: FontWeight.w600,
                          color: colorScheme.onSurface,
                        ),
                      ),
                      SizedBox(height: kIsWindows ? 2 : 2.h),
                      Text(
                        item.subtitle,
                        style: TextStyle(
                          fontSize: kIsWindows ? 12 : 12.sp,
                          color: colorScheme.onSurfaceVariant,
                        ),
                      ),
                    ],
                  ),
                ),
                if (isSelected)
                  Icon(
                    Symbols.keyboard_return_rounded,
                    color: colorScheme.primary,
                    size: kIsWindows ? 18 : 18.sp,
                  ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildFooter(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return Container(
      padding: EdgeInsets.symmetric(
        horizontal: kIsWindows ? 16 : 16.sp,
        vertical: kIsWindows ? 12 : 12.sp,
      ),
      decoration: BoxDecoration(
        color: colorScheme.surfaceContainerHighest.withValues(alpha: 0.5),
        border: Border(
          top: BorderSide(
            color: colorScheme.outlineVariant.withValues(alpha: 0.5),
          ),
        ),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          _buildShortcutHint('↑↓', 'Naviga', colorScheme),
          _buildShortcutHint('↵', 'Seleziona', colorScheme),
          _buildShortcutHint('esc', 'Chiudi', colorScheme),
        ],
      ),
    );
  }

  Widget _buildShortcutHint(
    String key,
    String action,
    ColorScheme colorScheme,
  ) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          padding: EdgeInsets.symmetric(
            horizontal: kIsWindows ? 6 : 6.w,
            vertical: kIsWindows ? 2 : 2.sp,
          ),
          decoration: BoxDecoration(
            color: colorScheme.surface,
            borderRadius: BorderRadius.circular(4),
            border: Border.all(color: colorScheme.outlineVariant, width: 1),
          ),
          child: Text(
            key,
            style: TextStyle(
              fontSize: kIsWindows ? 11 : 11.sp,
              fontWeight: FontWeight.bold,
              color: colorScheme.onSurfaceVariant,
            ),
          ),
        ),
        SizedBox(width: kIsWindows ? 4 : 4.w),
        Text(
          action,
          style: TextStyle(
            fontSize: kIsWindows ? 11 : 11.sp,
            color: colorScheme.onSurfaceVariant,
          ),
        ),
      ],
    );
  }
}

/// Keyboard shortcut handler for Command Palette
class CommandPaletteShortcut extends ConsumerWidget {
  final Widget child;

  const CommandPaletteShortcut({required this.child, super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Focus(
      autofocus: true,
      onKeyEvent: (node, event) {
        // Handle Ctrl+K or Cmd+K
        if (event is KeyDownEvent) {
          final isCtrlOrCmd =
              event.logicalKey == LogicalKeyboardKey.controlLeft ||
              event.logicalKey == LogicalKeyboardKey.controlRight ||
              event.logicalKey == LogicalKeyboardKey.metaLeft ||
              event.logicalKey == LogicalKeyboardKey.metaRight;

          if (isCtrlOrCmd) {
            // Wait for K key
            return KeyEventResult.ignored;
          }

          if (event.logicalKey == LogicalKeyboardKey.keyK) {
            final isModifierPressed =
                HardwareKeyboard.instance.isControlPressed ||
                HardwareKeyboard.instance.isMetaPressed;
            if (isModifierPressed) {
              ref.read(commandPaletteProvider.notifier).open();
              return KeyEventResult.handled;
            }
          }

          // ESC to close
          if (event.logicalKey == LogicalKeyboardKey.escape) {
            final state = ref.read(commandPaletteProvider);
            if (state.isOpen) {
              ref.read(commandPaletteProvider.notifier).close();
              return KeyEventResult.handled;
            }
          }

          // Arrow navigation when open
          final state = ref.read(commandPaletteProvider);
          if (state.isOpen) {
            if (event.logicalKey == LogicalKeyboardKey.arrowDown) {
              ref.read(commandPaletteProvider.notifier).selectNext();
              return KeyEventResult.handled;
            }
            if (event.logicalKey == LogicalKeyboardKey.arrowUp) {
              ref.read(commandPaletteProvider.notifier).selectPrevious();
              return KeyEventResult.handled;
            }
            if (event.logicalKey == LogicalKeyboardKey.enter) {
              ref
                  .read(commandPaletteProvider.notifier)
                  .selectItem(state.selectedIndex);
              return KeyEventResult.handled;
            }
          }
        }

        return KeyEventResult.ignored;
      },
      child: child,
    );
  }
}
