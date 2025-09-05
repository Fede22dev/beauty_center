import 'package:beauty_center/home/state/app_route_ui.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/app_routes.dart';
import '../../../../core/constants/app_constants.dart';
import '../../../../core/widgets/offline_banner.dart';
import '../../../state/home_controller.dart';
import '../widgets/navigations/bottom_nav.dart';

class HomePageMobile extends ConsumerStatefulWidget {
  const HomePageMobile({super.key, this.initialSegment});

  final String? initialSegment;

  @override
  ConsumerState<HomePageMobile> createState() => _HomePageMobileState();
}

class _HomePageMobileState extends ConsumerState<HomePageMobile> {
  // Cache pages to preserve state and avoid rebuilds bottom nav (compact layout).
  late final List<Widget?> _pageCache;

  // Keys to auto-scroll the selected bottom tab into view (compact layout).
  late final List<GlobalKey> _tabKeys;

  GoRouter? _router;
  VoidCallback? _routerListener;

  late final PageController _pageController;
  late final ScrollController _navScrollController;

  @override
  void initState() {
    super.initState();

    _pageCache = List<Widget?>.filled(
      AppRoute.values.length,
      null,
      growable: false,
    );

    _tabKeys = List<GlobalKey>.generate(
      AppRoute.values.length,
      (_) => GlobalKey(),
    );

    final initialTabIndex = appRouteFromSegmentOrDefault(
      widget.initialSegment,
    ).index;

    _pageController = PageController(initialPage: initialTabIndex);
    _navScrollController = ScrollController();

    // Sync provider state on first build.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      ref.read(homeTabProvider.notifier).setIndex(initialTabIndex);
      _scrollActiveTabIntoView(duration: Duration.zero);
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

  @override
  void dispose() {
    _pageController.dispose();
    _navScrollController.dispose();

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
      _pageController.jumpToPage(index);
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

    // Scroll the selected bottom tab into view on compact layout.
    _scrollActiveTabIntoView();
  }

  void _onBottomNavTabChanged(int newIndex) {
    // Jump to page call -> _onPageChanged and propagates to _setIndex.
    _pageController.jumpToPage(newIndex);
  }

  void _onPageChanged(int newIndex) {
    _setIndex(newIndex);
  }

  void _scrollActiveTabIntoView({
    Duration duration = kDefaultAppAnimationsDuration,
  }) {
    final context =
        _tabKeys[ref.read(homeTabProvider.notifier).index].currentContext;
    if (context == null) return;
    Scrollable.ensureVisible(
      context,
      alignment: 0.5,
      duration: duration,
      curve: Curves.easeOutCubic,
    );
  }

  Widget _buildCachedPage(int index) {
    // Lazy loading con cache
    _pageCache[index] ??= AppRoute.values[index].buildPage;
    return _pageCache[index]!;
  }

  PreferredSizeWidget _buildAppBar(ColorScheme colorScheme) {
    return PreferredSize(
      preferredSize: Size.fromHeight(kToolbarHeight.h),
      child: AnimatedContainer(
        duration: kDefaultAppAnimationsDuration,
        curve: Curves.easeInOutQuint,
        decoration: BoxDecoration(
          color: Color.alphaBlend(
            AppRoute.values[ref.read(homeTabProvider.notifier).index].color
                .withValues(alpha: 0.35),
            colorScheme.surfaceContainer,
          ),
          boxShadow: [
            BoxShadow(
              color: AppRoute
                  .values[ref.read(homeTabProvider.notifier).index]
                  .color
                  .withValues(alpha: 0.1),
              blurRadius: 8.r,
              offset: Offset(0, 2.h),
            ),
          ],
          borderRadius: BorderRadius.vertical(bottom: Radius.circular(8.r)),
        ),
        child: SafeArea(
          child: Center(
            child: Text(
              'Beauty Center',
              style: TextStyle(
                color: colorScheme.onSurface,
                fontSize: 18.sp,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    // COMPACT: AppBar + Inline offline banner + PageView (25% screen swipe left/right) + Bottom Navigation.
    return Scaffold(
      extendBody: true,
      appBar: _buildAppBar(colorScheme),
      body: Column(
        children: [
          InlineConnectivityBanner(),
          Expanded(
            child: SafeArea(
              top: false,
              bottom: false,
              child: LayoutBuilder(
                builder: (context, constraints) {
                  return Stack(
                    children: [
                      PageView.builder(
                        controller: _pageController,
                        physics: const BouncingScrollPhysics(),
                        itemCount: AppRoute.values.length,
                        onPageChanged: _onPageChanged,
                        itemBuilder: (context, index) =>
                            _buildCachedPage(index),
                      ),
                      Positioned(
                        left: 0.25.sw,
                        right: 0.25.sw,
                        top: 0,
                        bottom: 0,
                        child: GestureDetector(
                          behavior: HitTestBehavior.translucent,
                          onHorizontalDragStart: (_) {},
                          onHorizontalDragUpdate: (_) {},
                          onHorizontalDragEnd: (_) {},
                        ),
                      ),
                    ],
                  );
                },
              ),
            ),
          ),
        ],
      ),
      bottomNavigationBar: Consumer(
        builder: (context, ref, _) {
          final selectedIndex = ref.watch(homeTabProvider).index;
          return SafeArea(
            child: BottomNav(
              selectedIndex: selectedIndex,
              onTabChange: _onBottomNavTabChanged,
              navScrollController: _navScrollController,
              tabKeys: _tabKeys,
            ),
          );
        },
      ),
    );
  }
}
