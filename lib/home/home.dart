import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import 'package:go_router/go_router.dart';
import 'package:google_nav_bar/google_nav_bar.dart';
import 'package:sidebarx/sidebarx.dart';

import '../features/appointments/presentation/pages/appointments_page.dart';
import '../features/clients/presentation/pages/clients_page.dart';
import '../features/settings/presentation/pages/settings_page.dart';
import '../features/statistics/presentation/pages/statistics_page.dart';
import '../features/treatments/presentation/pages/treatments_page.dart';
import '../generated/l10n.dart';

enum HomeTab { appointments, clients, treatments, stats, settings }

extension HomeTabX on HomeTab {
  String get segment => name;

  String get path => '/$segment';

  IconData get icon => switch (this) {
    HomeTab.appointments => FontAwesomeIcons.calendarDays,
    HomeTab.clients => FontAwesomeIcons.addressBook,
    HomeTab.treatments => FontAwesomeIcons.spa,
    HomeTab.stats => FontAwesomeIcons.chartLine,
    HomeTab.settings => FontAwesomeIcons.gear,
  };

  String label(BuildContext context) => switch (this) {
    HomeTab.appointments => S.of(context).appointments,
    HomeTab.clients => S.of(context).clients,
    HomeTab.treatments => S.of(context).treatments,
    HomeTab.stats => S.of(context).statistics,
    HomeTab.settings => S.of(context).settings,
  };

  static HomeTab fromSegment(String? segment) {
    if (segment == null) return HomeTab.appointments;
    return HomeTab.values.firstWhere(
      (tab) => tab.segment == segment,
      orElse: () => HomeTab.appointments,
    );
  }
}

enum _NavSource { rail, pageView }

class Home extends StatefulWidget {
  // Provide initial tab segment to display. e.g. "appointments"
  final String? initialSegment;

  const Home({super.key, this.initialSegment});

  @override
  State<Home> createState() => _HomeState();
}

class _HomeState extends State<Home> {
  static const _animationsDuration = Duration(milliseconds: 350);
  late int _index;
  late final SidebarXController _railController;
  late final PageController _pageController;
  late final ScrollController _navScrollController = ScrollController();

  late final List<GlobalKey> _tabKeys = List<GlobalKey>.generate(
    HomeTab.values.length,
    (_) => GlobalKey(),
  );

  late final List<Widget?> _pageCache = List<Widget?>.filled(
    HomeTab.values.length,
    null,
    growable: false,
  );

  VoidCallback? _railListener;

  bool get _screenIsWide => MediaQuery.of(context).size.width >= 920.0;

  bool get _showNavBottomLabels => MediaQuery.of(context).size.width >= 360;

  @override
  void initState() {
    super.initState();
    _index = HomeTabX.fromSegment(widget.initialSegment).index;

    _railController = SidebarXController(
      selectedIndex: _index,
      extended: false,
    );

    _pageController = PageController(initialPage: _index);

    _railListener = () {
      final newIndex = _railController.selectedIndex;
      if (newIndex != _index) {
        _setIndex(newIndex, source: _NavSource.rail);
      }
    };
    _railController.addListener(_railListener!);

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted && !_screenIsWide) {
        _scrollActiveTabIntoView(duration: Duration.zero);
      }
    });
  }

  @override
  void dispose() {
    if (_railListener != null) {
      _railController.removeListener(_railListener!);
    }
    _railController.dispose();
    _pageController.dispose();
    _navScrollController.dispose();
    super.dispose();
  }

  // Unified setter to avoid double updates/loops across rail, page, router
  void _setIndex(int newIndex, {required _NavSource source}) {
    if (newIndex == _index) return;
    setState(() => _index = newIndex);

    if (source != _NavSource.rail &&
        _railController.selectedIndex != newIndex) {
      _railController.selectIndex(newIndex);
    }

    if (mounted) {
      context.go(HomeTab.values[newIndex].path);
    }
    // Scroll the bottom bar only in compact layout
    if (!_screenIsWide) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) _scrollActiveTabIntoView();
      });
    }
  }

  void _onBottomNavTabChanged(int newIndex) {
    _pageController.jumpToPage(newIndex);
  }

  void _onPageChanged(int newIndex) {
    _setIndex(newIndex, source: _NavSource.pageView);
  }

  void _scrollActiveTabIntoView({Duration duration = _animationsDuration}) {
    Scrollable.ensureVisible(
      _tabKeys[_index].currentContext!,
      alignment: 0.5,
      duration: duration,
      curve: Curves.easeOutCubic,
    );
  }

  Color _accentFor(HomeTab tab, ColorScheme colorScheme) => switch (tab) {
    HomeTab.appointments => colorScheme.primary,
    HomeTab.clients => Colors.blue,
    HomeTab.treatments => Colors.amber.shade500,
    HomeTab.stats => Colors.teal,
    HomeTab.settings => colorScheme.tertiary,
  };

  Widget _buildPage(HomeTab tab) => switch (tab) {
    HomeTab.appointments => const AppointmentsPage(),
    HomeTab.clients => const ClientsPage(),
    HomeTab.treatments => const TreatmentsPage(),
    HomeTab.stats => const StatisticsPage(),
    HomeTab.settings => const SettingsPage(),
  };

  Widget _getPage(int index) {
    final cachedPage = _pageCache[index];
    if (cachedPage != null) return cachedPage;
    final builtPage = _buildPage(HomeTab.values[index]);
    _pageCache[index] = builtPage;
    return builtPage;
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    if (_screenIsWide) {
      // WIDE: SidebarX (navigation rail)
      return Scaffold(
        backgroundColor: colorScheme.surfaceContainer,
        body: Row(
          children: [
            SafeArea(
              child: LayoutBuilder(
                builder: (context, constraints) {
                  final iconSize = 11.sp;

                  return SidebarX(
                    controller: _railController,
                    animationDuration: _animationsDuration,
                    theme: SidebarXTheme(
                      width: 32.w,
                      margin: EdgeInsets.fromLTRB(2.w, 20.h, 2.w, 20.h),
                      padding: EdgeInsets.symmetric(
                        vertical: 2.h,
                        horizontal: 1.w,
                      ),
                      decoration: BoxDecoration(
                        color: colorScheme.surfaceContainerHigh,
                        borderRadius: BorderRadius.circular(18.r),
                        border: Border.all(color: colorScheme.outlineVariant),
                      ),
                      itemPadding: EdgeInsets.symmetric(
                        vertical: 20.h,
                        horizontal: 4.w,
                      ),
                      selectedItemPadding: EdgeInsets.symmetric(
                        vertical: 20.h,
                        horizontal: 4.w,
                      ),
                      textStyle: TextStyle(
                        color: colorScheme.onSurfaceVariant,
                        fontSize: 9.sp,
                        fontWeight: FontWeight.w600,
                      ),
                      hoverTextStyle: TextStyle(
                        color: colorScheme.onSurfaceVariant,
                        fontSize: 9.sp,
                        fontWeight: FontWeight.w600,
                      ),
                      selectedTextStyle: TextStyle(
                        color: colorScheme.onPrimaryContainer,
                        fontSize: 9.sp,
                        fontWeight: FontWeight.w600,
                      ),
                      itemTextPadding: EdgeInsets.only(left: 8.w),
                      selectedItemTextPadding: EdgeInsets.only(left: 8.w),
                      itemDecoration: BoxDecoration(
                        border: Border.all(color: colorScheme.outlineVariant),
                        borderRadius: BorderRadius.circular(12.r),
                      ),
                      selectedItemDecoration: BoxDecoration(
                        color: colorScheme.primaryContainer.withValues(
                          alpha: 0.5,
                        ),
                        borderRadius: BorderRadius.circular(12.r),
                        border: Border.all(
                          color: colorScheme.primary.withValues(alpha: 0.5),
                        ),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withValues(alpha: 0.5),
                            blurRadius: 30,
                          ),
                        ],
                      ),
                      iconTheme: IconThemeData(
                        color: colorScheme.onSurfaceVariant,
                        size: iconSize,
                      ),
                      hoverIconTheme: IconThemeData(
                        color: colorScheme.onSurfaceVariant,
                        size: iconSize,
                      ),
                      selectedIconTheme: IconThemeData(
                        color: colorScheme.onPrimaryContainer,
                        size: iconSize,
                      ),
                    ),
                    extendedTheme: SidebarXTheme(
                      width: 100.w,
                      margin: EdgeInsets.fromLTRB(1.w, 4.h, 1.w, 4.h),
                      padding: EdgeInsets.symmetric(
                        vertical: 2.h,
                        horizontal: 1.w,
                      ),
                      decoration: BoxDecoration(
                        color: colorScheme.surfaceContainerHigh,
                        borderRadius: BorderRadius.circular(8.r),
                        border: Border.all(color: colorScheme.outlineVariant),
                      ),
                    ),
                    items: [
                      for (final t in HomeTab.values)
                        SidebarXItem(
                          icon: t.icon,
                          label: t.label(context),
                          iconBuilder: (selected, hovered) {
                            return Center(
                              child: FaIcon(t.icon, size: iconSize),
                            );
                          },
                        ),
                    ],
                    footerDivider: Divider(
                      height: 1.h,
                      color: colorScheme.outlineVariant,
                    ),
                  );
                },
              ),
            ),
            Padding(
              padding: EdgeInsets.symmetric(vertical: 4.h),
              child: VerticalDivider(
                width: 1.w,
                thickness: 1.h,
                color: colorScheme.outlineVariant,
              ),
            ),
            Expanded(
              child: SafeArea(
                child: IndexedStack(
                  index: _index,
                  children: List<Widget>.generate(
                    HomeTab.values.length,
                    (i) => _getPage(i),
                  ),
                ),
              ),
            ),
          ],
        ),
      );
    }

    // COMPACT: Bottom bar with GNav
    return Scaffold(
      extendBody: true,
      body: SafeArea(
        top: false,
        bottom: false,
        child: PageView.builder(
          controller: _pageController,
          physics: const BouncingScrollPhysics(),
          itemCount: HomeTab.values.length,
          onPageChanged: (index) => _onPageChanged(index),
          itemBuilder: (context, index) => _getPage(index),
        ),
      ),
      bottomNavigationBar: SafeArea(
        child: Container(
          margin: EdgeInsets.symmetric(horizontal: 16.w, vertical: 8.h),
          decoration: BoxDecoration(
            color: colorScheme.surfaceContainer,
            borderRadius: BorderRadius.all(Radius.circular(20.r)),
            boxShadow: [
              BoxShadow(
                spreadRadius: -10,
                blurRadius: 60,
                color: Colors.black.withValues(alpha: 0.5),
                offset: const Offset(0, 25),
              ),
            ],
          ),
          child: Padding(
            padding: EdgeInsets.symmetric(horizontal: 3.w, vertical: 3.h),
            child: LayoutBuilder(
              builder: (context, constraints) {
                return SingleChildScrollView(
                  controller: _navScrollController,
                  scrollDirection: Axis.horizontal,
                  physics: const BouncingScrollPhysics(),
                  child: ConstrainedBox(
                    constraints: BoxConstraints(minWidth: constraints.maxWidth),
                    child: GNav(
                      selectedIndex: _index,
                      onTabChange: _onBottomNavTabChanged,
                      duration: _animationsDuration,
                      curve: Curves.easeInOutQuint,
                      tabs: [
                        for (final tab in HomeTab.values)
                          GButton(
                            key: _tabKeys[tab.index],
                            gap: 10.w,
                            padding: EdgeInsets.symmetric(
                              horizontal: 12.w,
                              vertical: 12.h,
                            ),
                            borderRadius: BorderRadius.all(
                              Radius.circular(20.r),
                            ),
                            icon: tab.icon,
                            iconSize: 24.sp,
                            iconActiveColor: _accentFor(tab, colorScheme),
                            iconColor: colorScheme.onSurface,
                            text: _showNavBottomLabels
                                ? tab.label(context)
                                : '',
                            textColor: _accentFor(tab, colorScheme),
                            textStyle: TextStyle(
                              fontSize: 12.sp,
                              fontWeight: FontWeight.w700,
                              letterSpacing: 0.1,
                            ),
                            backgroundColor: _accentFor(
                              tab,
                              colorScheme,
                            ).withValues(alpha: 0.20),
                            rippleColor: _accentFor(
                              tab,
                              colorScheme,
                            ).withValues(alpha: 0.14),
                            hoverColor: _accentFor(
                              tab,
                              colorScheme,
                            ).withValues(alpha: 0.06),
                          ),
                      ],
                    ),
                  ),
                );
              },
            ),
          ),
        ),
      ),
    );
  }
}
