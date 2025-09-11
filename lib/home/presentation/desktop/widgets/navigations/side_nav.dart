import 'package:beauty_center/core/providers/app_route_ui_provider.dart';
import 'package:beauty_center/home/presentation/desktop/widgets/navigations/toggle_button.dart';
import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:sidebarx/sidebarx.dart';

import '../../../../../core/constants/app_constants.dart';
import '../../../../../core/router/app_routes.dart';
import '../../../widgets/animated_rotation_icon.dart';

class SideNav extends StatelessWidget {
  const SideNav({
    required this.selectedIndex,
    required this.controller,
    super.key,
  });

  final int selectedIndex;
  final SidebarXController controller;

  @override
  Widget build(final BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return SidebarX(
      controller: controller,
      animationDuration: kDefaultAppAnimationsDuration,
      theme: SidebarXTheme(
        width: 27.w,
        margin: EdgeInsets.fromLTRB(2.w, 20.h, 2.w, 20.h),
        padding: EdgeInsets.symmetric(vertical: 4.h, horizontal: 1.w),
        decoration: BoxDecoration(
          color: Color.alphaBlend(
            AppRoute.values[selectedIndex].color.withValues(alpha: 0.1),
            colorScheme.surfaceContainerHigh,
          ),
          borderRadius: BorderRadius.circular(18.r),
          border: Border.all(
            color: colorScheme.outlineVariant.withValues(alpha: 0.4),
          ),
        ),
        itemPadding: EdgeInsets.symmetric(vertical: 20.h, horizontal: 4.w),
        itemDecoration: BoxDecoration(
          borderRadius: BorderRadius.circular(14.r),
        ),
        hoverColor: colorScheme.primary.withValues(alpha: 0.12),
        selectedItemPadding: EdgeInsets.symmetric(
          vertical: 20.h,
          horizontal: 4.w,
        ),
        selectedItemDecoration: BoxDecoration(
          color: colorScheme.primary.withValues(alpha: 0.1),
          borderRadius: BorderRadius.circular(14.r),
          border: Border.all(
            color: colorScheme.primary.withValues(alpha: 0.4),
            width: 0.7.w,
          ),
          boxShadow: [
            BoxShadow(
              color: colorScheme.primary.withValues(alpha: 0.04),
              blurRadius: 20.r,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        textStyle: TextStyle(
          color: colorScheme.onSurfaceVariant,
          fontSize: 7.sp,
          fontWeight: FontWeight.w600,
        ),
        hoverTextStyle: TextStyle(
          color: colorScheme.onSurface.withValues(alpha: 0.85),
          fontSize: 7.sp,
          fontWeight: FontWeight.w600,
        ),
        selectedTextStyle: TextStyle(
          color: AppRoute.values[selectedIndex].color,
          fontSize: 7.sp,
          fontWeight: FontWeight.w600,
        ),
        itemTextPadding: EdgeInsets.only(left: 8.w),
        selectedItemTextPadding: EdgeInsets.only(left: 8.w),
      ),
      extendedTheme: SidebarXTheme(
        width: 82.w,
        margin: EdgeInsets.fromLTRB(1.w, 4.h, 1.w, 4.h),
        padding: EdgeInsets.symmetric(vertical: 4.h, horizontal: 1.w),
        decoration: BoxDecoration(
          color: Color.alphaBlend(
            AppRoute.values[selectedIndex].color.withValues(alpha: 0.1),
            colorScheme.surfaceContainerHigh,
          ),
          borderRadius: BorderRadius.circular(8.r),
          border: Border.all(
            color: colorScheme.outlineVariant.withValues(alpha: 0.4),
          ),
        ),
        itemDecoration: BoxDecoration(borderRadius: BorderRadius.circular(6.r)),
        hoverColor: colorScheme.primary.withValues(alpha: 0.12),
        selectedItemDecoration: BoxDecoration(
          color: colorScheme.primary.withValues(alpha: 0.1),
          borderRadius: BorderRadius.circular(6.r),
          border: Border.all(
            color: colorScheme.primary.withValues(alpha: 0.4),
            width: 0.7.w,
          ),
          boxShadow: [
            BoxShadow(
              color: colorScheme.primary.withValues(alpha: 0.04),
              blurRadius: 20.r,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        textStyle: TextStyle(
          color: colorScheme.onSurfaceVariant,
          fontSize: 7.sp,
          fontWeight: FontWeight.w600,
        ),
        hoverTextStyle: TextStyle(
          color: colorScheme.onSurface.withValues(alpha: 0.85),
          fontSize: 7.sp,
          fontWeight: FontWeight.w600,
        ),
        selectedTextStyle: TextStyle(
          color: AppRoute.values[selectedIndex].color,
          fontSize: 7.sp,
          fontWeight: FontWeight.w600,
        ),
        itemTextPadding: EdgeInsets.only(left: 8.w),
        selectedItemTextPadding: EdgeInsets.only(left: 8.w),
      ),
      items: [
        for (final tab in AppRoute.values)
          SidebarXItem(
            label: tab.label(context),
            iconBuilder: (final selected, final hovered) => Center(
              child: AnimatedRotationIcon(
                icon: tab.icon,
                color: selected
                    ? tab.color
                    : (hovered
                          ? tab.color.withValues(alpha: 0.65)
                          : colorScheme.onSurfaceVariant.withValues(
                              alpha: 0.9,
                            )),
                isSelected: selected,
                size: 12.sp,
              ),
            ),
          ),
      ],
      footerDivider: Divider(
        height: 1.h,
        color: colorScheme.onSurfaceVariant.withValues(alpha: 0.2),
      ),
      toggleButtonBuilder: (final context, final extended) => ToggleButton(
        isExtended: extended,
        onToggle: controller.toggleExtended,
      ),
    );
  }
}
