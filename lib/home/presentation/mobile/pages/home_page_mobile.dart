import 'package:beauty_center/core/localizations/extensions/l10n_extensions.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:material_symbols_icons/symbols.dart';

import '../../../../core/constants/app_constants.dart';
import '../../../../core/logging/app_logger.dart';
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
  late final List<Widget> _pages;

  static final log = AppLogger.getLogger(name: 'HomeMobile');

  @override
  void initState() {
    super.initState();

    final initialTabIndex = AppTabs.defaultTab.index;

    _tabKeys = List.generate(AppTabs.values.length, (_) => GlobalKey());
    _pageController = PageController(initialPage: initialTabIndex);
    _navScrollController = ScrollController();
    _pages = AppTabs.values.map((final tab) => tab.buildPage).toList();

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      ref.read(homeTabProvider.notifier).setIndex(initialTabIndex);
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
      alignment: 0.5,
      duration: duration,
      curve: Curves.easeOutCubic,
    );
  }

  void _syncAllCloudData() {
    log.fine('Sync all cloud data');
  }

  PreferredSizeWidget _buildAppBar(final ColorScheme colorScheme) {
    final currentTabColor =
        AppTabs.values[ref.read(homeTabProvider).index].color;

    return PreferredSize(
      preferredSize: Size.fromHeight(kToolbarHeight.h),
      child: AnimatedContainer(
        duration: kDefaultAppAnimationsDuration,
        curve: Curves.easeInOutQuint,
        decoration: BoxDecoration(
          color: Color.alphaBlend(
            currentTabColor.withValues(alpha: 0.35),
            colorScheme.surfaceContainer,
          ),
          boxShadow: [
            BoxShadow(
              color: currentTabColor.withValues(alpha: 0.1),
              blurRadius: 8.r,
              offset: Offset(0, 2.h),
            ),
          ],
          borderRadius: BorderRadius.vertical(bottom: Radius.circular(8.r)),
        ),
        child: SafeArea(
          child: Padding(
            padding: EdgeInsets.fromLTRB(16.w, 0, 0, 0),
            child: Row(
              children: [
                Expanded(
                  child: Text(
                    'Beauty Center',
                    style: TextStyle(
                      color: colorScheme.onSurface,
                      fontSize: 18.sp,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
                PopupMenuButton<String>(
                  elevation: 9,
                  icon: Icon(
                    Symbols.more_vert,
                    size: 20.sp,
                    opticalSize: 32.sp,
                    weight: 700,
                    color: colorScheme.onSurface,
                  ),
                  offset: Offset(-8.w, (kToolbarHeight / 2 + 5.sp).h),
                  shadowColor: currentTabColor.withValues(alpha: 0.2),
                  color: colorScheme.surfaceContainerHighest,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(16.r),
                    side: BorderSide(
                      color: currentTabColor.withValues(alpha: 0.15),
                    ),
                  ),
                  splashRadius: 20.r,
                  itemBuilder: (final context) => [
                    PopupMenuItem<String>(
                      child: InkWell(
                        borderRadius: BorderRadius.circular(12.r),
                        splashColor: currentTabColor.withValues(alpha: 0.1),
                        highlightColor: currentTabColor.withValues(alpha: 0.05),
                        hoverColor: currentTabColor.withValues(alpha: 0.05),
                        focusColor: currentTabColor.withValues(alpha: 0.05),
                        onTap: () {
                          Navigator.of(context).pop();
                          _syncAllCloudData();
                        },
                        child: Padding(
                          padding: EdgeInsets.symmetric(
                            horizontal: 8.w,
                            vertical: 6.h,
                          ),
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Container(
                                padding: EdgeInsets.all(6.w),
                                decoration: BoxDecoration(
                                  color: currentTabColor.withValues(
                                    alpha: 0.15,
                                  ),
                                  borderRadius: BorderRadius.circular(10.r),
                                ),
                                child: Icon(
                                  Symbols.cloud_sync_rounded,
                                  size: 20.sp,
                                  color: currentTabColor,
                                ),
                              ),
                              SizedBox(width: 12.w),
                              Text(
                                context.l10n.syncAllCloudData,
                                style: TextStyle(
                                  fontSize: 14.sp,
                                  fontWeight: FontWeight.w500,
                                  color: colorScheme.onSurface,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  @override
  Widget build(final BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return Scaffold(
      backgroundColor: colorScheme.surfaceContainerLow,
      extendBody: true,
      appBar: _buildAppBar(colorScheme),
      body: PageView(
        controller: _pageController,
        physics: const BouncingScrollPhysics(),
        onPageChanged: _onPageChanged,
        children: _pages,
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
