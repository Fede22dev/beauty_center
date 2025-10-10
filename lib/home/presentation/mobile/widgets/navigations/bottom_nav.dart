import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:google_nav_bar/google_nav_bar.dart';

import '../../../../../core/constants/app_constants.dart';
import '../../../../../core/tabs/app_tabs.dart';
import '../../../widgets/animated_rotation_icon.dart';

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

    return Padding(
      padding: EdgeInsets.fromLTRB(16.w, 0, 16.w, 8.h),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(20.r),
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 2, sigmaY: 2),
          child: AnimatedContainer(
            duration: kDefaultAppAnimationsDuration,
            curve: Curves.easeInOutQuint,
            decoration: BoxDecoration(
              color: AppTabs.values[selectedIndex].color.withValues(
                alpha: 0.15,
              ),
              borderRadius: BorderRadius.circular(20.r),
              boxShadow: [
                BoxShadow(
                  spreadRadius: -10.r,
                  blurRadius: 60.r,
                  color: colorScheme.primary.withValues(alpha: 0.1),
                  offset: Offset(0.w, 25.h),
                ),
              ],
            ),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(20.r),
              child: Padding(
                padding: EdgeInsets.symmetric(horizontal: 3.w, vertical: 3.h),
                child: LayoutBuilder(
                  builder: (final context, final constraints) => Scrollbar(
                    controller: navScrollController,
                    thumbVisibility: true,
                    thickness: 3.h,
                    radius: Radius.circular(20.r),
                    child: SizedBox(
                      height: 45.h,
                      child: ListView(
                        controller: navScrollController,
                        scrollDirection: Axis.horizontal,
                        physics: const BouncingScrollPhysics(),
                        children: [
                          ConstrainedBox(
                            constraints: BoxConstraints(
                              minWidth: constraints.maxWidth,
                            ),
                            child: GNav(
                              selectedIndex: selectedIndex,
                              onTabChange: onTabChange,
                              duration: kDefaultAppAnimationsDuration,
                              curve: Curves.easeInOutQuint,
                              tabs: [
                                for (final tab in AppTabs.values)
                                  GButton(
                                    key: tabKeys[tab.index],
                                    gap: 10.w,
                                    padding: EdgeInsets.symmetric(
                                      horizontal: 10.w,
                                      vertical: 10.h,
                                    ),
                                    borderRadius: BorderRadius.circular(16.r),
                                    shadow: [
                                      BoxShadow(
                                        spreadRadius: -10.r,
                                        blurRadius: 60.r,
                                        color: colorScheme.primary.withValues(
                                          alpha: 0.1,
                                        ),
                                        offset: Offset(0.w, 25.h),
                                      ),
                                    ],
                                    leading: AnimatedRotationIcon(
                                      icon: tab.icon,
                                      color: tab.color,
                                      isSelected: selectedIndex == tab.index,
                                      size: 24.sp,
                                    ),
                                    icon: tab.icon,
                                    text:
                                        MediaQuery.of(context).size.width >=
                                            360.w
                                        ? tab.label(context)
                                        : '',
                                    textStyle: TextStyle(
                                      fontSize: 12.sp,
                                      color: colorScheme.onSurface,
                                      fontWeight: FontWeight.w700,
                                      letterSpacing: 0.1.sp,
                                    ),
                                    backgroundColor: tab.color.withValues(
                                      alpha: 0.3,
                                    ),
                                    rippleColor: tab.color.withValues(
                                      alpha: 0.16,
                                    ),
                                    hoverColor: tab.color.withValues(
                                      alpha: 0.08,
                                    ),
                                  ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
