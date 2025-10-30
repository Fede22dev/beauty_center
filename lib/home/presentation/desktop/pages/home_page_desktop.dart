import 'package:beauty_center/core/tabs/app_tabs.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:sidebarx/sidebarx.dart';

import '../../../../core/constants/app_constants.dart';
import '../../../../core/widgets/lazy_keep_alive_stack.dart';
import '../../../providers/home_tab_provider.dart';
import '../../widgets/common_app_bar.dart';
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

    return Scaffold(
      body: Column(
        children: [
          const CommonAppBar(),
          Expanded(
            child: Row(
              children: [
                SideNav(
                  selectedIndex: ref.watch(homeTabProvider).index,
                  controller: _railController,
                ),
                AnimatedBuilder(
                  animation: _railController,
                  builder: (final context, _) => AnimatedPadding(
                    duration: kDefaultAppAnimationsDuration,
                    padding: _railController.extended
                        ? const EdgeInsets.symmetric(vertical: 4)
                        : const EdgeInsets.symmetric(vertical: 20),
                    child: VerticalDivider(
                      width: 2,
                      color: colorScheme.outlineVariant,
                    ),
                  ),
                ),
                Expanded(
                  child: LazyKeepAliveStack(
                    index: ref.watch(homeTabProvider).index,
                    itemCount: AppTabs.values.length,
                    itemBuilder: (final context, final index) =>
                        AppTabs.values[index].buildPage,
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
