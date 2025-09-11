import 'package:beauty_center/core/providers/app_route_ui_provider.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:go_router/go_router.dart';
import 'package:sidebarx/sidebarx.dart';

import '../../../../core/constants/app_constants.dart';
import '../../../../core/router/app_routes.dart';
import '../../../../core/widgets/lazy_keep_alive_stack.dart';
import '../../../../core/widgets/offline_banner.dart';
import '../../../providers/home_provider.dart';
import '../widgets/navigations/side_nav.dart';

class HomePageDesktop extends ConsumerStatefulWidget {
  const HomePageDesktop({super.key, this.initialSegment});

  final String? initialSegment;

  @override
  ConsumerState<HomePageDesktop> createState() => _HomePageDesktopState();
}

class _HomePageDesktopState extends ConsumerState<HomePageDesktop> {
  GoRouter? _router;
  VoidCallback? _routerListener;
  late final SidebarXController _railController;

  @override
  void initState() {
    super.initState();

    final initialTabIndex = appRouteFromSegmentOrDefault(
      widget.initialSegment,
    ).index;

    _railController = SidebarXController(
      selectedIndex: initialTabIndex,
      extended: false,
    );

    _railController.addListener(_onRailSelectionChanged);

    // Sync provider state on first build.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      ref.read(homeTabProvider.notifier).setIndex(initialTabIndex);
    });
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    // Deep links typed in the address bar on web/desktop.
    final router = GoRouter.of(context);
    if (_router != router) {
      if (_router != null && _routerListener != null) {
        _router!.routerDelegate.removeListener(_routerListener!);
      }

      _router = router;
      _routerListener = _onRouteChanged;
      _router!.routerDelegate.addListener(_routerListener!);
    }
  }

  void _onRouteChanged() {
    // Sync index from current location (supports hash strategy).
    final info = _router!.routeInformationProvider.value;
    final location = info.uri.toString();
    final uri = Uri.parse(location);
    final segment = uri.pathSegments.isNotEmpty
        ? uri.pathSegments.first
        : kDefaultRoute.segment;
    final route = appRouteFromSegmentOrDefault(segment);
    final index = route.index;

    if (index != ref.read(homeTabProvider.notifier).index) {
      _railController.selectIndex(index);
    }
  }

  @override
  void dispose() {
    _railController
      ..removeListener(_onRailSelectionChanged)
      ..dispose();

    if (_router != null && _routerListener != null) {
      _router!.routerDelegate.removeListener(_routerListener!);
    }

    super.dispose();
  }

  void _onRailSelectionChanged() {
    _setIndex(_railController.selectedIndex);
  }

  // Unified setter to keep rail, page, router, and provider in sync.
  void _setIndex(final int newIndex) {
    final currIndex = ref.read(homeTabProvider.notifier).index;
    if (newIndex == currIndex) return;

    ref.read(homeTabProvider.notifier).setIndex(newIndex);

    // Route change (avoid loops by comparing current route).
    final targetPath = AppRoute.values[newIndex].path;
    final info = _router?.routeInformationProvider.value;
    final currentLocation = info?.uri.toString() ?? kDefaultRoute.path;
    if (mounted && currentLocation != targetPath) {
      context.go(targetPath);
    }
  }

  Widget _buildPage(final BuildContext context, final int index) =>
      KeyedSubtree(
        key: ValueKey('page_$index'),
        child: AppRoute.values[index].buildPage,
      );

  @override
  Widget build(final BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    // WIDE: Sidebar + IndexedStack (state preserved).
    return Scaffold(
      backgroundColor: colorScheme.surfaceContainer,
      body: OfflineScaffoldOverlay(
        child: Row(
          children: [
            SafeArea(
              child: Consumer(
                builder: (final context, final ref, _) => SideNav(
                  selectedIndex: ref.watch(homeTabProvider).index,
                  controller: _railController,
                ),
              ),
            ),
            AnimatedBuilder(
              animation: _railController,
              builder: (final context, _) => AnimatedPadding(
                duration: kDefaultAppAnimationsDuration,
                padding: _railController.extended
                    ? EdgeInsets.symmetric(vertical: 4.h)
                    : EdgeInsets.symmetric(vertical: 20.h),
                child: VerticalDivider(
                  width: 1.w,
                  color: colorScheme.outlineVariant,
                ),
              ),
            ),
            Expanded(
              child: SafeArea(
                child: Consumer(
                  builder: (final context, final ref, _) => LazyKeepAliveStack(
                    index: ref.watch(homeTabProvider).index,
                    itemCount: AppRoute.values.length,
                    itemBuilder: _buildPage,
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
