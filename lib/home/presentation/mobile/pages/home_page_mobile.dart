import 'package:beauty_center/home/presentation/widgets/common_app_bar.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/constants/app_constants.dart';
import '../../../../core/tabs/app_tabs.dart';
import '../../../providers/home_tab_provider.dart';
import '../widgets/navigations/bottom_nav.dart';

class HomePageMobile extends ConsumerStatefulWidget {
  const HomePageMobile({super.key});

  @override
  ConsumerState<HomePageMobile> createState() => _HomePageMobileState();
}

class _HomePageMobileState extends ConsumerState<HomePageMobile> {
  late final List<GlobalKey> _tabKeys;
  late final PageController _pageController;
  late final ScrollController _navScrollController;

  //static final log = AppLogger.getLogger(name: 'HomeMobile');

  @override
  void initState() {
    super.initState();

    final initialTabIndex = AppTabs.defaultTab.index;

    _tabKeys = List.generate(AppTabs.values.length, (_) => GlobalKey());
    _pageController = PageController(initialPage: initialTabIndex);
    _navScrollController = ScrollController();

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      _scrollActiveTabIntoView(duration: Duration.zero);
    });
  }

  @override
  void dispose() {
    _pageController.dispose();
    _navScrollController.dispose();
    super.dispose();
  }

  void _onPageChanged(final int newIndex) {
    ref.read(homeTabProvider.notifier).setIndex(newIndex);
    _scrollActiveTabIntoView();
  }

  void _scrollActiveTabIntoView({
    final Duration duration = kDefaultAppAnimationsDuration,
  }) {
    final context = _tabKeys[ref.read(homeTabProvider).index].currentContext;
    if (context == null) return;

    Scrollable.ensureVisible(
      context,
      duration: duration,
      curve: Curves.easeOutCubic,
      alignment: 0.5,
    );
  }

  @override
  Widget build(final BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    ref.listen(homeTabProvider, (_, final next) {
      if (_pageController.hasClients &&
          _pageController.page?.round() != next.index) {
        _pageController.jumpToPage(next.index);
        _scrollActiveTabIntoView();
      }
    });

    return Scaffold(
      backgroundColor: colorScheme.surfaceContainerLow,
      extendBody: true,
      appBar: const CommonAppBar(),
      body: PageView(
        controller: _pageController,
        physics: const BouncingScrollPhysics(),
        onPageChanged: _onPageChanged,
        children: AppTabs.values.map((final tab) => tab.buildPage).toList(),
      ),
      bottomNavigationBar: SafeArea(
        child: BottomNav(
          selectedIndex: ref.watch(homeTabProvider).index,
          onTabChange: _pageController.jumpToPage,
          navScrollController: _navScrollController,
          tabKeys: _tabKeys,
        ),
      ),
    );
  }
}
