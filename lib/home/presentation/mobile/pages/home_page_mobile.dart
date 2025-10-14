import 'package:beauty_center/core/widgets/custom_snackbar.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:material_symbols_icons/symbols.dart';

import '../../../../core/connectivity/connectivity_provider.dart';
import '../../../../core/constants/app_constants.dart';
import '../../../../core/supabase/supabase_auth_provider.dart';
import '../../../../core/tabs/app_tabs.dart';
import '../../../../core/widgets/supabase_login_dialog.dart';
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

  var _isDialogLoginSupabase = false;

  //static final log = AppLogger.getLogger(name: 'HomeMobile');

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
            padding: EdgeInsets.only(left: 16.w),
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
                Consumer(
                  builder: (final context, final ref, _) {
                    final isOffline = ref.watch(isOfflineProvider);

                    if (!isOffline) return const SizedBox.shrink();

                    return StatefulBuilder(
                      builder: (final context, final setState) {
                        final controller = AnimationController(
                          vsync: Navigator.of(context),
                          duration: const Duration(seconds: 1),
                        )..repeat(reverse: true);

                        return FadeTransition(
                          opacity: controller,
                          child: Icon(
                            Icons.cloud_off_rounded,
                            color: Colors.red,
                            size: 24.sp,
                            weight: 600,
                          ),
                        );
                      },
                    );
                  },
                ),
                SizedBox(width: kIsWindows ? 8 : 8.w),
                Consumer(
                  builder: (final context, final ref, _) {
                    final state = ref.watch(supabaseAuthProvider);

                    WidgetsBinding.instance.addPostFrameCallback((_) async {
                      if (!state.isInitializing &&
                          state.isDisconnected &&
                          context.mounted &&
                          !_isDialogLoginSupabase) {
                        _isDialogLoginSupabase = true;

                        await showDialog<void>(
                          context: context,
                          barrierDismissible: false,
                          builder: (_) => const SupabaseLoginDialog(),
                        );

                        _isDialogLoginSupabase = false;
                      }

                      if (state.errorMessage != null && context.mounted) {
                        showCustomSnackBar(
                          context: context,
                          message: state.errorMessage!,
                          okColor: colorScheme.primary,
                        );
                      }
                    });

                    return IconButton(
                      icon: Icon(
                        Symbols.account_circle,
                        color: state.isConnected
                            ? Colors.green
                            : state.isConnecting
                            ? Colors.amber
                            : Colors.grey,
                        size: 24.sp,
                        weight: 600,
                      ),
                      onPressed: () async {
                        _isDialogLoginSupabase = true;

                        await showDialog<void>(
                          context: context,
                          builder: (_) => const SupabaseLoginDialog(),
                        );

                        _isDialogLoginSupabase = true;
                      },
                    );
                  },
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
