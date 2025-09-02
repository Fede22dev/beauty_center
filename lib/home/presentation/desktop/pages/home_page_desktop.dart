import 'package:beauty_center/home/state/app_route_ui.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:go_router/go_router.dart';
import 'package:sidebarx/sidebarx.dart';

import '../../../../core/app_routes.dart';
import '../../../../core/constants/app_constants.dart';
import '../../../../core/widgets/lazy_keep_alive_stack.dart';
import '../../../../core/widgets/offline_banner.dart';
import '../../../state/home_controller.dart';
import '../widgets/navigations/side_nav.dart';

class HomePageDesktop extends ConsumerStatefulWidget {
  const HomePageDesktop({super.key, this.initialSegment});

  final String? initialSegment;

  @override
  ConsumerState<HomePageDesktop> createState() => _HomePageDesktopState();
}

class _HomePageDesktopState extends ConsumerState<HomePageDesktop> {
  // Cache pages to preserve state and avoid rebuilds bottom nav (compact layout).
  //late final List<Widget?> _pageCache;

  GoRouter? _router;
  VoidCallback? _routerListener;

  bool _initializedControllers = false;
  late final SidebarXController _railController;

  @override
  void initState() {
    super.initState();

    final initialTabIndex = appRouteFromSegmentOrDefault(
      widget.initialSegment,
    ).index;

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

    if (!_initializedControllers) {
      _initializedControllers = true;

      final initialTabIndex = appRouteFromSegmentOrDefault(
        widget.initialSegment,
      ).index;

      // _pageCache = List<Widget?>.filled(
      //   AppRoute.values.length,
      //   null,
      //   growable: false,
      // );

      _railController = SidebarXController(
        selectedIndex: initialTabIndex,
        extended: false,
      );
      _railController.addListener(() {
        _setIndex(_railController.selectedIndex);
      });
    }
  }

  @override
  void dispose() {
    _railController.dispose();

    if (_router != null && _routerListener != null) {
      _router!.routerDelegate.removeListener(_routerListener!);
    }

    super.dispose();
  }

  void _onRouteChanged() {
    // Sync index from current location (supports hash strategy).
    final info = _router!.routeInformationProvider.value;
    final String location = info.uri.toString();
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

  // Unified setter to keep rail, page, router, and provider in sync.
  void _setIndex(int newIndex) {
    final currIndex = ref.read(homeTabProvider.notifier).index;
    if (newIndex == currIndex) return;

    ref.read(homeTabProvider.notifier).setIndex(newIndex);

    // Route change (avoid loops by comparing current route).
    final targetPath = AppRoute.values[newIndex].path;
    final info = _router?.routeInformationProvider.value;
    final String currentLocation = info?.uri.toString() ?? kDefaultRoute.path;
    if (mounted && currentLocation != targetPath) {
      context.go(targetPath);
    }
  }

  // Widget _getPage(int index) {
  //   final cached = _pageCache[index];
  //   if (cached != null) return cached;
  //   final built = AppRoute.values[index].buildPage;
  //   _pageCache[index] = built;
  //   return built;
  // }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    // WIDE: Sidebar + IndexedStack (state preserved).
    return Scaffold(
      backgroundColor: colorScheme.surfaceContainer,
      body: OfflineScaffoldOverlay(
        child: Row(
          children: [
            SafeArea(child: SideNav(controller: _railController)),
            AnimatedBuilder(
              animation: _railController,
              builder: (context, _) {
                return AnimatedPadding(
                  duration: kDefaultAppAnimationsDuration,
                  padding: _railController.extended
                      ? EdgeInsets.symmetric(vertical: 4.h)
                      : EdgeInsets.symmetric(vertical: 20.h),
                  child: VerticalDivider(
                    width: 1.w,
                    color: colorScheme.outlineVariant,
                  ),
                );
              },
            ),
            Expanded(
              child: SafeArea(
                child: LazyKeepAliveStack(
                  index: ref.read(homeTabProvider.notifier).index,
                  itemCount: AppRoute.values.length,
                  // Build on first access; LazyKeepAliveStack will cache it.
                  itemBuilder: (context, index) {
                    // Important: return a stable page for each index.
                    // The widget will be kept mounted once built.
                    return KeyedSubtree(
                      key: ValueKey('page_$index'),
                      child: AppRoute.values[index].buildPage,
                    );
                  },
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
