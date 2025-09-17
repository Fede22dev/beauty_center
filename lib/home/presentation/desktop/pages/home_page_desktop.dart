import 'package:beauty_center/core/tabs/app_tabs.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:sidebarx/sidebarx.dart';

import '../../../../core/constants/app_constants.dart';
import '../../../../core/widgets/lazy_keep_alive_stack.dart';
import '../../../../core/widgets/offline_banner.dart';
import '../../../providers/home_tab_provider.dart';
import '../widgets/navigations/side_nav.dart';

class HomePageDesktop extends ConsumerStatefulWidget {
  const HomePageDesktop({super.key});

  @override
  ConsumerState<HomePageDesktop> createState() => _HomePageDesktopState();
}

class _HomePageDesktopState extends ConsumerState<HomePageDesktop> {
  late final SidebarXController _railController;

  @override
  void initState() {
    super.initState();

    final initialTabIndex = AppTabs.defaultTab.index;

    _railController = SidebarXController(selectedIndex: initialTabIndex);
    _railController.addListener(_onRailSelectionChanged);

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      ref.read(homeTabProvider.notifier).setIndex(initialTabIndex);
    });
  }

  @override
  void dispose() {
    _railController
      ..removeListener(_onRailSelectionChanged)
      ..dispose();

    super.dispose();
  }

  void _onRailSelectionChanged() => ref
      .read(homeTabProvider.notifier)
      .setIndex(_railController.selectedIndex);

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
                    itemCount: AppTabs.values.length,
                    itemBuilder:
                        (final BuildContext context, final int index) =>
                            AppTabs.values[index].buildPage,
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
