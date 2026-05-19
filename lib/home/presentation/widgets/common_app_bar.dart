import 'package:adaptive_theme/adaptive_theme.dart';
import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:material_symbols_icons/symbols.dart';
import 'package:talker_flutter/talker_flutter.dart';

import '../../../core/connectivity/connectivity_providers.dart';
import '../../../core/constants/app_constants.dart';
import '../../../core/logging/app_logger.dart';
import '../../../core/providers/supabase_auth_provider.dart';
import '../../../core/tabs/app_tabs.dart';
import '../../../core/widgets/supabase_login_dialog.dart';
import '../../../features/notifications/presentation/widgets/notifications_hub_widget.dart';
import '../../providers/home_tab_provider.dart';

class CommonAppBar extends ConsumerStatefulWidget
    implements PreferredSizeWidget {
  const CommonAppBar({super.key});

  @override
  Size get preferredSize => Size.fromHeight(kIsWindows ? 56 : kToolbarHeight.h);

  @override
  ConsumerState<CommonAppBar> createState() => _CommonAppBarState();
}

class _CommonAppBarState extends ConsumerState<CommonAppBar> {
  var _tapCount = 0;
  DateTime? _lastTap;

  void _handleTitleTap() {
    final now = DateTime.now();
    // Se è passato più di 1 secondo dall'ultimo tap, resetta il contatore
    if (_lastTap != null &&
        now.difference(_lastTap!) > const Duration(seconds: 1)) {
      _tapCount = 0;
    }
    _lastTap = now;
    _tapCount++;

    if (_tapCount >= 3) {
      _tapCount = 0;
      Navigator.of(context).push(
        MaterialPageRoute<void>(
          builder: (context) {
            final colorScheme = Theme.of(context).colorScheme;

            return TalkerScreen(
              talker: AppLogger.talker,
              theme: TalkerScreenTheme(
                cardColor: colorScheme.surfaceContainer,
                backgroundColor: colorScheme.surfaceContainerHighest,
                textColor: colorScheme.onSurface,
              ),
            );
          },
        ),
      );
    }
  }

  @override
  Widget build(final BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final currentTabColor =
        AppTabs.values[ref.watch(homeTabProvider).index].color;

    return PreferredSize(
      preferredSize: widget.preferredSize,
      child: AnimatedContainer(
        duration: kDefaultAppAnimationsDuration,
        curve: Curves.easeInOutCubic,
        decoration: BoxDecoration(
          color: Color.alphaBlend(
            currentTabColor.withValues(alpha: 0.35),
            colorScheme.surfaceContainer,
          ),
          boxShadow: [
            BoxShadow(
              color: currentTabColor.withValues(alpha: 0.1),
              blurRadius: kIsWindows ? 8 : 8.r,
              offset: Offset(0, kIsWindows ? 2 : 2.h),
            ),
          ],
          borderRadius: BorderRadius.vertical(
            bottom: Radius.circular(kIsWindows ? 8 : 8.r),
          ),
        ),
        child: SafeArea(
          left: false,
          right: false,
          bottom: false,
          child: Padding(
            padding: EdgeInsets.only(left: kIsWindows ? 16 : 16.w),
            child: Row(
              children: [
                Expanded(
                  child: GestureDetector(
                    onTap: _handleTitleTap,
                    behavior: HitTestBehavior.opaque,
                    child:
                        Text(
                              'Beauty Center',
                              style: TextStyle(
                                color: colorScheme.onSurface,
                                fontSize: kIsWindows ? 18 : 18.sp,
                                fontWeight: FontWeight.bold,
                              ),
                            )
                            .animate(key: const ValueKey('app_bar_title'))
                            .fadeIn(
                              duration: kDefaultAppAnimationsDuration,
                              delay: 100.ms,
                            )
                            .slideX(
                              begin: -0.1,
                              end: 0,
                              duration: kDefaultAppAnimationsDuration,
                            ),
                  ),
                ),
                _OfflineIndicator(),
                SizedBox(width: kIsWindows ? 12 : 12.w),
                // Notification Bell with badge
                const NotificationBellButton(),
                SizedBox(width: kIsWindows ? 8 : 8.w),
                _ThemeToggleButton(colorScheme: colorScheme),
                SizedBox(width: kIsWindows ? 4 : 4.w),
                _AccountButton(colorScheme: colorScheme),
                SizedBox(width: kIsWindows ? 8 : 4.w),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _OfflineIndicator extends ConsumerWidget {
  @override
  Widget build(final BuildContext context, final WidgetRef ref) {
    final isOffline = ref.watch(isConnectionUnusableProvider);

    return AnimatedSwitcher(
      duration: kDefaultAppAnimationsDuration,
      switchInCurve: Curves.easeOutCubic,
      switchOutCurve: Curves.easeInCubic,
      transitionBuilder: (final child, final animation) => FadeTransition(
        opacity: animation,
        child: ScaleTransition(scale: animation, child: child),
      ),
      child: isOffline
          ? Icon(
                  key: const ValueKey('offline'),
                  Symbols.cloud_off_rounded,
                  color: Colors.red,
                  size: kIsWindows ? 24 : 24.sp,
                  weight: 600,
                )
                .animate(onPlay: (final c) => c.repeat(reverse: true))
                .fade(duration: 1.seconds, begin: 0.25, end: 1)
          : const SizedBox.shrink(key: ValueKey('online')),
    );
  }
}

class _ThemeToggleButton extends StatelessWidget {
  const _ThemeToggleButton({required this.colorScheme});

  final ColorScheme colorScheme;

  @override
  Widget build(final BuildContext context) {
    final theme = AdaptiveTheme.of(context);

    return ValueListenableBuilder<AdaptiveThemeMode>(
      valueListenable: theme.modeChangeNotifier,
      builder: (final context, final mode, final child) {
        final isDark = mode.isDark;

        return IconButton(
          icon: AnimatedSwitcher(
            duration: kDefaultAppAnimationsDuration,
            switchInCurve: Curves.easeOutCubic,
            switchOutCurve: Curves.easeInCubic,
            transitionBuilder: (final child, final animation) => FadeTransition(
              opacity: animation,
              child: RotationTransition(
                turns: Tween<double>(begin: 0.5, end: 1).animate(animation),
                child: ScaleTransition(scale: animation, child: child),
              ),
            ),
            child: Icon(
              isDark ? Symbols.light_mode : Symbols.dark_mode,
              key: ValueKey(isDark),
              color: colorScheme.onSurfaceVariant,
              size: kIsWindows ? 24 : 24.sp,
              weight: 600,
            ),
          ),
          splashColor: colorScheme.primary.withValues(alpha: 0.2),
          hoverColor: colorScheme.primary.withValues(alpha: 0.1),
          onPressed: () {
            if (isDark) {
              theme.setLight();
            } else {
              theme.setDark();
            }
          },
        );
      },
    );
  }
}

class _AccountButton extends ConsumerWidget {
  const _AccountButton({required this.colorScheme});

  final ColorScheme colorScheme;

  @override
  Widget build(final BuildContext context, final WidgetRef ref) {
    final state = ref.watch(supabaseAuthProvider);
    final isOffline = ref.watch(isConnectionUnusableProvider);

    final iconColor = state.isConnected
        ? Colors.green
        : state.isConnecting
        ? Colors.amber
        : Colors.grey;

    return IconButton(
      icon:
          AnimatedContainer(
                duration: 400.ms,
                curve: Curves.easeOutCubic,
                child: Icon(
                  Symbols.bolt,
                  color: iconColor,
                  size: kIsWindows ? 24 : 24.sp,
                  weight: 600,
                ),
              )
              .animate(target: state.isConnecting ? 1 : 0)
              .scale(
                end: const Offset(0, 1),
                duration: 600.ms,
                curve: Curves.easeInOut,
              )
              .then()
              .scale(
                end: const Offset(0, 1),
                duration: 600.ms,
                curve: Curves.easeInOut,
              ),
      splashColor: colorScheme.primary.withValues(alpha: 0.2),
      hoverColor: colorScheme.primary.withValues(alpha: 0.1),
      onPressed: isOffline
          ? null
          : () async {
              await showDialog<void>(
                context: context,
                builder: (_) => const SupabaseLoginDialog(),
              );
            },
    );
  }
}
