import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:sidebarx/sidebarx.dart';

import '../../../../../core/app_routes.dart';
import '../../../../../core/constants/app_constants.dart';
import '../../../../state/app_route_ui.dart';

class SideNav extends StatelessWidget {
  const SideNav({super.key, required this.controller});

  final SidebarXController controller;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return SidebarX(
      controller: controller,
      animationDuration: kDefaultAppAnimationsDuration,
      theme: SidebarXTheme(
        width: 30.w,
        margin: EdgeInsets.fromLTRB(2.w, 20.h, 2.w, 20.h),
        padding: EdgeInsets.symmetric(vertical: 4.h, horizontal: 1.w),
        decoration: BoxDecoration(
          color: colorScheme.surfaceContainerHigh,
          borderRadius: BorderRadius.circular(18.r),
          border: Border.all(
            color: colorScheme.outlineVariant.withValues(alpha: 0.4),
          ),
        ),
        itemPadding: EdgeInsets.symmetric(vertical: 20.h, horizontal: 4.w),
        selectedItemPadding: EdgeInsets.symmetric(
          vertical: 20.h,
          horizontal: 4.w,
        ),
        textStyle: TextStyle(
          color: colorScheme.onSurfaceVariant,
          fontSize: 7.sp,
          fontWeight: FontWeight.w600,
        ),
        hoverTextStyle: TextStyle(
          color: colorScheme.primary.withValues(alpha: 0.85),
          fontSize: 7.sp,
          fontWeight: FontWeight.w600,
        ),
        selectedTextStyle: TextStyle(
          color: colorScheme.onPrimaryContainer,
          fontSize: 7.sp,
          fontWeight: FontWeight.w600,
        ),
        itemTextPadding: EdgeInsets.only(left: 8.w),
        selectedItemTextPadding: EdgeInsets.only(left: 8.w),
        itemDecoration: BoxDecoration(
          borderRadius: BorderRadius.circular(14.r),
        ),
        selectedItemDecoration: BoxDecoration(
          color: colorScheme.primary.withValues(alpha: 0.12),
          borderRadius: BorderRadius.circular(12.r),
          border: Border.all(
            color: colorScheme.primary.withValues(alpha: 0.08),
          ),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.08),
              blurRadius: 20.r,
              offset: Offset(0, 4),
            ),
          ],
        ),
      ),
      extendedTheme: SidebarXTheme(
        width: 85.w,
        margin: EdgeInsets.fromLTRB(1.w, 4.h, 1.w, 4.h),
        padding: EdgeInsets.symmetric(vertical: 4.h, horizontal: 1.w),
        decoration: BoxDecoration(
          color: colorScheme.surfaceContainerHigh,
          borderRadius: BorderRadius.circular(8.r),
          border: Border.all(
            color: colorScheme.outlineVariant.withValues(alpha: 0.4),
          ),
        ),
        itemDecoration: BoxDecoration(borderRadius: BorderRadius.circular(6.r)),
        selectedItemDecoration: BoxDecoration(
          color: colorScheme.primaryContainer.withValues(alpha: 0.12),
          borderRadius: BorderRadius.circular(6.r),
          border: Border.all(
            color: colorScheme.primary.withValues(alpha: 0.08),
          ),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.08),
              blurRadius: 20.r,
              offset: Offset(0, 4),
            ),
          ],
        ),
        textStyle: TextStyle(
          color: colorScheme.onSurfaceVariant,
          fontSize: 7.sp,
          fontWeight: FontWeight.w600,
        ),
        hoverTextStyle: TextStyle(
          color: colorScheme.primary.withValues(alpha: 0.85),
          fontSize: 7.sp,
          fontWeight: FontWeight.w600,
        ),
        selectedTextStyle: TextStyle(
          color: colorScheme.onPrimaryContainer,
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
            iconBuilder: (selected, hovered) => Center(
              child: Icon(
                tab.icon,
                size: 12.sp,
                color: selected
                    ? tab.color
                    : (hovered
                          ? colorScheme.primary.withValues(alpha: 0.5)
                          : colorScheme.onSurfaceVariant.withValues(
                              alpha: 0.8,
                            )),
                weight: 600,
              ),
            ),
          ),
      ],
      footerDivider: Divider(height: 1.h, color: colorScheme.outlineVariant),
    );
  }
}
