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
import '../../../../../../core/widgets/app_error_view.dart';
import '../../../../providers/treatments_providers.dart';
import 'service_list_item.dart';

const _pageSize = 20;

/// Service list with infinite scroll pagination and search support
class SectionServiceList extends ConsumerStatefulWidget {
  const SectionServiceList({
    required this.searchQuery,
    required this.onServiceTap,
    required this.onServiceEdit,
    required this.onServiceDelete,
    this.scrollController,
    super.key,
  });

  final String searchQuery;
  final ValueChanged<String> onServiceTap;
  final ValueChanged<String> onServiceEdit;
    final ValueChanged<String> onServiceDelete;
  final ScrollController? scrollController;

  @override
  ConsumerState<SectionServiceList> createState() =>
      _SectionServiceListState();
}

class _SectionServiceListState extends ConsumerState<SectionServiceList> {
  static final _log = AppLogger.getLogger(name: 'SectionServiceList');

  late final PagingController<int, ServiceData> _pagingController;
  var _hasInitialPageLoaded = false;

  @override
  void initState() {
    super.initState();
    _pagingController = PagingController<int, ServiceData>(
      getNextPageKey: (final state) =>
          state.lastPageIsEmpty ? null : state.nextIntPageKey,
      fetchPage: _fetchPage,
    );
  }

  @override
  void didUpdateWidget(covariant final SectionServiceList oldWidget) {
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

  Future<List<ServiceData>> _fetchPage(final int pageKey) async {
    try {
      final allServices =
          await ref.read(servicesActionsProvider).getAllActiveServices();
      final filteredServices = _filterAndSortServices(allServices);

      final start = (pageKey - 1) * _pageSize;

      if (start >= filteredServices.length) {
        return [];
      }

      final end = (start + _pageSize).clamp(0, filteredServices.length);

      return filteredServices.sublist(start, end);
    } catch (e, stackTrace) {
      _log.severe('Error fetching page $pageKey', e, stackTrace);
      rethrow;
    }
  }

  List<ServiceData> _filterAndSortServices(final List<ServiceData> services) {
    final q = widget.searchQuery.trim().toLowerCase();

    final filtered =
        q.isEmpty
            ? services
            : services
                  .where(
                    (final s) =>
                        s.name.toLowerCase().contains(q) ||
                        (s.description?.toLowerCase().contains(q) ?? false),
                  )
                  .toList()
          ..sort(
            (final a, final b) =>
                a.name.toLowerCase().compareTo(b.name.toLowerCase()),
          );

    return filtered;
  }

  Future<void> _handleRefresh() async {
    try {
      await ref.read(servicesActionsProvider).syncWithSupabase();
    } catch (e, s) {
      _log.warning('Manual sync failed', e, s);
    }

    _log.finest('Manual sync list');
    _pagingController.refresh();
  }

  @override
  Widget build(final BuildContext context) {
    ref.listen<AsyncValue<List<ServiceData>>>(servicesStreamProvider, (
      final prev,
      final next,
    ) {
      if (!_hasInitialPageLoaded) return;

      if (next.hasValue && prev?.hasValue == true) {
        final prevIds = prev!.value!.map((e) => e.id).toSet();
        final nextIds = next.value!.map((e) => e.id).toSet();
        if (prevIds.length != nextIds.length ||
            !prevIds.every(nextIds.contains)) {
          _pagingController.refresh();
        }
      }
    });

    return RefreshIndicator(
      triggerMode: RefreshIndicatorTriggerMode.anywhere,
      onRefresh: _handleRefresh,
      child: PagingListener<int, ServiceData>(
        controller: _pagingController,
        builder: (final context, final state, final fetchNextPage) {
          if (state.isLoading == false &&
              state.pages?.isNotEmpty == true &&
              !_hasInitialPageLoaded) {
            _hasInitialPageLoaded = true;
          }
          return PagedListView<int, ServiceData>.separated(
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
              builderDelegate: PagedChildBuilderDelegate<ServiceData>(
                animateTransitions: true,
                transitionDuration: kDefaultAppAnimationsDuration,
                itemBuilder:
                    (final context, final service, final index) =>
                        ServiceListItem(
                          service: service,
                          onTap: () =>
                              widget.onServiceTap(service.id),
                          onEdit: () =>
                              widget.onServiceEdit(service.id),
                          onDelete: () =>
                              widget.onServiceDelete(service.id),
                          index: index,
                        ),
                firstPageErrorIndicatorBuilder: (final context) =>
                    AppErrorView(
                      error: _pagingController.error,
                      onRetry: _pagingController.refresh,
                    ),
                newPageErrorIndicatorBuilder: (final context) =>
                    AppErrorView(
                      isCompact: true,
                      error: _pagingController.error,
                      onRetry: _pagingController.refresh,
                    ),
                firstPageProgressIndicatorBuilder: (final context) =>
                    _ShimmerLoadingList(),
                newPageProgressIndicatorBuilder: (final context) =>
                    const SizedBox.shrink(),
                noItemsFoundIndicatorBuilder: (final context) =>
                    _EmptyState(
                      hasSearchQuery: widget.searchQuery.isNotEmpty,
                    ),
              ),
              separatorBuilder: (final context, final index) =>
                  SizedBox(height: kIsWindows ? 8 : 6.h),
            );
        },
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
              height: kIsWindows ? 80 : 80.h,
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius:
                    BorderRadius.circular(kIsWindows ? 12 : 12.r),
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
                  : Symbols.massage_rounded,
              size: kIsWindows ? 128 : 128.sp,
              color: colorScheme.outline.withValues(alpha: 0.5),
            ),
            SizedBox(height: kIsWindows ? 16 : 16.h),
            Text(
              hasSearchQuery
                  ? 'Nessun trattamento trovato'
                  : 'Nessun trattamento presente',
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
                  : 'Aggiungi il tuo primo trattamento',
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
