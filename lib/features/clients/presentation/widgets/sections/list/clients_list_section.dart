import 'dart:async';

import 'package:beauty_center/core/logging/app_logger.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:infinite_scroll_pagination/infinite_scroll_pagination.dart';
import 'package:material_symbols_icons/material_symbols_icons.dart';
import 'package:shimmer/shimmer.dart';

import '../../../../../../core/constants/app_constants.dart';
import '../../../../../../core/database/app_database.dart';
import '../../../providers/clients_providers.dart';
import 'client_list_item.dart';

const _pageSize = 20;

/// Client list with infinite scroll pagination and search support
class SectionClientList extends ConsumerStatefulWidget {
  const SectionClientList({
    required this.searchQuery,
    required this.onClientTap,
    this.scrollController,
    super.key,
  });

  final String searchQuery;
  final ValueChanged<String> onClientTap;
  final ScrollController? scrollController;

  @override
  ConsumerState<SectionClientList> createState() => _SectionClientListState();
}

class _SectionClientListState extends ConsumerState<SectionClientList> {
  static final log = AppLogger.getLogger(name: 'SectionClientList');

  late final PagingController<int, Client> _pagingController;

  @override
  void initState() {
    super.initState();
    _pagingController = PagingController<int, Client>(
      getNextPageKey: (final state) =>
          state.lastPageIsEmpty ? null : state.nextIntPageKey,
      fetchPage: _fetchPage,
    );
  }

  @override
  void didUpdateWidget(covariant final SectionClientList oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.searchQuery != widget.searchQuery) {
      _pagingController.refresh();
    }
  }

  @override
  void dispose() {
    _pagingController.dispose();
    super.dispose();
  }

  Future<List<Client>> _fetchPage(final int pageKey) async {
    try {
      final allClients = await ref.read(clientsActionsProvider).getAllClients();
      final filteredClients = _filterAndSortClients(allClients);

      // Page 1 -> start = 0, Page 2 -> start = 10, ecc.
      final start = (pageKey - 1) * _pageSize;

      if (start >= filteredClients.length) {
        return []; // No more pages to load
      }

      final end = (start + _pageSize).clamp(0, filteredClients.length);

      return filteredClients.sublist(start, end);
    } catch (e, stackTrace) {
      log.severe('Error fetching page $pageKey', e, stackTrace);
      rethrow;
    }
  }

  List<Client> _filterAndSortClients(final List<Client> clients) {
    final q = widget.searchQuery.trim().toLowerCase();

    final filtered =
        q.isEmpty
              ? clients
              : clients
                    .where(
                      (final c) =>
                          c.firstName.toLowerCase().contains(q) ||
                          c.lastName.toLowerCase().contains(q) ||
                          c.phoneNumber.contains(q),
                    )
                    .toList()
          ..sort((final a, final b) {
            final f = a.firstName.toLowerCase().compareTo(
              b.firstName.toLowerCase(),
            );
            return f != 0
                ? f
                : a.lastName.toLowerCase().compareTo(b.lastName.toLowerCase());
          });

    return filtered;
  }

  Future<void> _handleRefresh() async {
    try {
      await ref.read(clientsActionsProvider).syncWithSupabase();
    } catch (e, s) {
      log.warning('Manual sync failed', e, s);
    }

    log.fine('Manual sync list');
    _pagingController.refresh();
  }

  @override
  Widget build(final BuildContext context) {
    ref.listen<AsyncValue<List<Client>>>(clientsStreamProvider, (
      final prev,
      final next,
    ) {
      final isNotLoading = !next.isLoading && next.hasValue;
      final valueChanged = prev?.value?.length != next.value?.length;

      if (isNotLoading && (valueChanged || prev == null)) {
        log.fine('Stream aggiornato, refresh lista');
        _pagingController.refresh();
      }
    });

    return RefreshIndicator(
      triggerMode: RefreshIndicatorTriggerMode.anywhere,
      onRefresh: _handleRefresh,
      child: PagingListener<int, Client>(
        controller: _pagingController,
        builder: (final context, final state, final fetchNextPage) =>
            PagedListView<int, Client>.separated(
              state: state,
              fetchNextPage: fetchNextPage,
              scrollController: widget.scrollController,
              physics: const AlwaysScrollableScrollPhysics(
                parent: BouncingScrollPhysics(),
              ),
              padding: EdgeInsets.fromLTRB(
                kIsWindows ? 16 : 8.w,
                kIsWindows ? 5 : 0,
                kIsWindows ? 16 : 8.w,
                kIsWindows ? 0 : kBottomNavigationBarHeight + 28.h,
              ),
              builderDelegate: PagedChildBuilderDelegate<Client>(
                animateTransitions: true,
                transitionDuration: kDefaultAppAnimationsDuration,
                itemBuilder: (final context, final client, final index) =>
                    ClientListItem(
                      client: client,
                      onTap: () => widget.onClientTap(client.id),
                      index: index,
                    ),
                firstPageErrorIndicatorBuilder: (final context) =>
                    _ErrorIndicator(onRetry: _pagingController.refresh),
                newPageErrorIndicatorBuilder: (final context) =>
                    _ErrorIndicator(onRetry: _pagingController.refresh),
                firstPageProgressIndicatorBuilder: (final context) =>
                    _ShimmerLoadingList(),
                newPageProgressIndicatorBuilder: (final context) =>
                    const SizedBox.shrink(),
                noItemsFoundIndicatorBuilder: (final context) =>
                    _EmptyState(hasSearchQuery: widget.searchQuery.isNotEmpty),
              ),
              separatorBuilder: (final context, final index) =>
                  SizedBox(height: kIsWindows ? 8 : 6.h),
            ),
      ),
    );
  }
}

/// Widget shimmer per loading state
class _ShimmerLoadingList extends StatelessWidget {
  @override
  Widget build(final BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return Shimmer.fromColors(
      baseColor: colorScheme.surfaceContainerHighest,
      highlightColor: colorScheme.surface,
      child: Column(
        children: List.generate(
          _pageSize,
          (_) => Padding(
            padding: EdgeInsets.only(bottom: kIsWindows ? 8 : 8.h),
            child: Container(
              height: kIsWindows ? 100 : 100.h,
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(kIsWindows ? 12 : 12.r),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// Empty state widget
class _EmptyState extends StatelessWidget {
  const _EmptyState({required this.hasSearchQuery});

  final bool hasSearchQuery;

  @override
  Widget build(final BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return Center(
      child: Padding(
        padding: EdgeInsets.symmetric(
          vertical: kIsWindows ? 100 : 100.h,
          horizontal: kIsWindows ? 32 : 32.w,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              hasSearchQuery
                  ? Symbols.search_off_rounded
                  : Symbols.people_outline_rounded,
              size: kIsWindows ? 128 : 128.sp,
              color: colorScheme.outline.withValues(alpha: 0.5),
            ),
            SizedBox(height: kIsWindows ? 16 : 16.h),
            Text(
              hasSearchQuery
                  ? 'Nessun cliente trovato'
                  : 'Nessun cliente presente',
              style: TextStyle(
                color: colorScheme.onSurfaceVariant,
                fontSize: kIsWindows ? 20 : 20.sp,
                fontWeight: FontWeight.w600,
              ),
              textAlign: TextAlign.center,
            ),
            SizedBox(height: kIsWindows ? 8 : 8.h),
            Text(
              hasSearchQuery
                  ? 'Prova con un altro termine di ricerca'
                  : 'Aggiungi il tuo primo cliente',
              style: TextStyle(
                color: colorScheme.outline,
                fontSize: kIsWindows ? 18 : 18.sp,
                fontWeight: FontWeight.w500,
              ),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }
}

/// Error indicator widget
class _ErrorIndicator extends StatelessWidget {
  const _ErrorIndicator({required this.onRetry});

  final VoidCallback onRetry;

  @override
  Widget build(final BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return Center(
      child: Padding(
        padding: EdgeInsets.all(kIsWindows ? 32 : 32.w),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Symbols.error_outline_rounded,
              size: kIsWindows ? 128 : 128.sp,
              color: colorScheme.error,
            ),
            SizedBox(height: kIsWindows ? 16 : 16.h),
            Text(
              'Errore nel caricamento',
              style: TextStyle(
                color: colorScheme.onSurfaceVariant,
                fontSize: kIsWindows ? 20 : 20.sp,
                fontWeight: FontWeight.w600,
              ),
            ),
            SizedBox(height: kIsWindows ? 16 : 16.h),
            FilledButton.icon(
              onPressed: onRetry,
              icon: const Icon(Symbols.refresh_rounded),
              label: const Text('Riprova'),
            ),
          ],
        ),
      ),
    );
  }
}
