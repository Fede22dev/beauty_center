import 'package:beauty_center/home/providers/app_route_ui_provider.dart';
import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:google_nav_bar/google_nav_bar.dart';

import '../../../../../core/constants/app_constants.dart';
import '../../../../../core/router/app_routes.dart';

class BottomNav extends StatelessWidget {
  const BottomNav({
    required this.selectedIndex,
    required this.onTabChange,
    required this.navScrollController,
    required this.tabKeys,
    super.key,
  });

  final int selectedIndex;
  final ValueChanged<int> onTabChange;
  final ScrollController navScrollController;
  final List<GlobalKey> tabKeys;

  @override
  Widget build(final BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final showLabels = MediaQuery.of(context).size.width >= 360.w;

    return AnimatedContainer(
      duration: kDefaultAppAnimationsDuration,
      curve: Curves.easeInOutQuint,
      margin: EdgeInsets.symmetric(horizontal: 16.w, vertical: 8.h),
      decoration: BoxDecoration(
        color: Color.alphaBlend(
          AppRoute.values[selectedIndex].color.withValues(alpha: 0.075),
          colorScheme.surfaceContainer,
        ),
        borderRadius: BorderRadius.all(Radius.circular(20.r)),
        boxShadow: [
          BoxShadow(
            spreadRadius: -10.r,
            blurRadius: 60.r,
            color: Colors.black.withValues(alpha: 0.08),
            offset: Offset(0.w, 25.w),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.all(Radius.circular(20.r)),
        child: Padding(
          padding: EdgeInsets.symmetric(horizontal: 3.w, vertical: 3.h),
          child: LayoutBuilder(
            builder: (final context, final constraints) =>
                SingleChildScrollView(
                  controller: navScrollController,
                  scrollDirection: Axis.horizontal,
                  physics: const BouncingScrollPhysics(),
                  child: ConstrainedBox(
                    constraints: BoxConstraints(minWidth: constraints.maxWidth),
                    child: GNav(
                      selectedIndex: selectedIndex,
                      onTabChange: onTabChange,
                      duration: kDefaultAppAnimationsDuration,
                      curve: Curves.easeInOutQuint,
                      tabs: [
                        for (final tab in AppRoute.values)
                          GButton(
                            key: tabKeys[tab.index],
                            gap: 10.w,
                            padding: EdgeInsets.symmetric(
                              horizontal: 12.w,
                              vertical: 12.h,
                            ),
                            borderRadius: BorderRadius.all(
                              Radius.circular(16.r),
                            ),
                            leading: AnimatedLeadingIcon(
                              icon: tab.icon,
                              color: tab.color,
                              isSelected: selectedIndex == tab.index,
                              size: 24.sp,
                            ),
                            icon: tab.icon,
                            text: showLabels ? tab.label(context) : '',
                            textStyle: TextStyle(
                              fontSize: 12.sp,
                              color: colorScheme.onSurface,
                              fontWeight: FontWeight.w700,
                              letterSpacing: 0.1.sp,
                            ),
                            backgroundColor: tab.color.withValues(alpha: 0.20),
                            rippleColor: tab.color.withValues(alpha: 0.14),
                            hoverColor: tab.color.withValues(alpha: 0.06),
                          ),
                      ],
                    ),
                  ),
                ),
          ),
        ),
      ),
    );
  }
}

class AnimatedLeadingIcon extends StatelessWidget {
  const AnimatedLeadingIcon({
    required this.icon,
    required this.color,
    required this.isSelected,
    required this.size,
    super.key,
  });

  final IconData icon;
  final Color color;
  final bool isSelected;
  final double size;

  @override
  Widget build(final BuildContext context) => Stack(
    alignment: Alignment.center,
    children: [
      // Rotation + fill/weight animation
      AnimatedRotation(
        // 0 turns -> 1 turn (360°). On deselect it rotates back.
        turns: isSelected ? 1 : 0,
        duration: Duration(
          milliseconds: isSelected
              ? kDefaultAppAnimationsDuration.inMilliseconds * 2
              : 0,
        ),
        curve: Curves.easeInOutCubic,
        child: TweenAnimationBuilder<double>(
          // t goes 0 -> 1 when selected, 1 -> 0 when deselected
          tween: Tween<double>(begin: 0, end: isSelected ? 1 : 0),
          duration: Duration(
            milliseconds: kDefaultAppAnimationsDuration.inMilliseconds * 2,
          ),
          curve: Curves.easeInOutCubic,
          // Smoothly morph outline -> filled, and inverse
          builder: (final context, final tick, _) => Icon(
            icon,
            size: size,
            weight: 400 + (700 - 400) * tick,
            fill: tick,
            color: color,
          ),
        ),
      ),
    ],
  );
}
