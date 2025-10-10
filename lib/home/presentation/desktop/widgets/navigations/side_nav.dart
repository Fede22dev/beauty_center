import 'package:beauty_center/home/presentation/desktop/widgets/navigations/toggle_button.dart';
import 'package:flutter/material.dart';
import 'package:sidebarx/sidebarx.dart';

import '../../../../../core/constants/app_constants.dart';
import '../../../../../core/tabs/app_tabs.dart';
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
        width: 100,
        margin: const EdgeInsets.fromLTRB(4, 20, 4, 20),
        padding: const EdgeInsets.symmetric(vertical: 4, horizontal: 2),
        decoration: BoxDecoration(
          color: Color.alphaBlend(
            AppTabs.values[selectedIndex].color.withValues(alpha: 0.1),
            colorScheme.surfaceContainerHigh,
          ),
          borderRadius: BorderRadius.circular(18),
          border: Border.all(
            color: colorScheme.outlineVariant.withValues(alpha: 0.4),
          ),
        ),
        itemPadding: const EdgeInsets.symmetric(vertical: 20, horizontal: 4),
        itemDecoration: BoxDecoration(borderRadius: BorderRadius.circular(14)),
        hoverColor: colorScheme.primary.withValues(alpha: 0.12),
        selectedItemPadding: const EdgeInsets.symmetric(
          vertical: 20,
          horizontal: 4,
        ),
        selectedItemDecoration: BoxDecoration(
          color: colorScheme.primary.withValues(alpha: 0.1),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: colorScheme.primary.withValues(alpha: 0.4)),
          boxShadow: [
            BoxShadow(
              color: colorScheme.primary.withValues(alpha: 0.04),
              blurRadius: 20,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        textStyle: TextStyle(
          color: colorScheme.onSurfaceVariant,
          fontSize: 16,
          fontWeight: FontWeight.w600,
        ),
        hoverTextStyle: TextStyle(
          color: colorScheme.onSurface.withValues(alpha: 0.85),
          fontSize: 16,
          fontWeight: FontWeight.w600,
        ),
        selectedTextStyle: TextStyle(
          color: AppTabs.values[selectedIndex].color,
          fontSize: 16,
          fontWeight: FontWeight.w600,
        ),
        itemTextPadding: const EdgeInsets.only(left: 8),
        selectedItemTextPadding: const EdgeInsets.only(left: 8),
      ),
      extendedTheme: SidebarXTheme(
        width: 185,
        margin: const EdgeInsets.fromLTRB(4, 4, 4, 4),
        padding: const EdgeInsets.symmetric(vertical: 4, horizontal: 2),
        decoration: BoxDecoration(
          color: Color.alphaBlend(
            AppTabs.values[selectedIndex].color.withValues(alpha: 0.1),
            colorScheme.surfaceContainerHigh,
          ),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: colorScheme.outlineVariant.withValues(alpha: 0.4),
          ),
        ),
        itemDecoration: BoxDecoration(borderRadius: BorderRadius.circular(10)),
        hoverColor: colorScheme.primary.withValues(alpha: 0.12),
        selectedItemDecoration: BoxDecoration(
          color: colorScheme.primary.withValues(alpha: 0.1),
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: colorScheme.primary.withValues(alpha: 0.4)),
          boxShadow: [
            BoxShadow(
              color: colorScheme.primary.withValues(alpha: 0.04),
              blurRadius: 20,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        textStyle: TextStyle(
          color: colorScheme.onSurfaceVariant,
          fontSize: 16,
          fontWeight: FontWeight.w600,
        ),
        hoverTextStyle: TextStyle(
          color: colorScheme.onSurface.withValues(alpha: 0.85),
          fontSize: 16,
          fontWeight: FontWeight.w600,
        ),
        selectedTextStyle: TextStyle(
          color: AppTabs.values[selectedIndex].color,
          fontSize: 16,
          fontWeight: FontWeight.w600,
        ),
        itemTextPadding: const EdgeInsets.only(left: 8),
        selectedItemTextPadding: const EdgeInsets.only(left: 8),
      ),
      items: [
        for (final tab in AppTabs.values)
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
                size: 42,
              ),
            ),
          ),
      ],
      footerDivider: Divider(
        height: 2,
        color: colorScheme.onSurfaceVariant.withValues(alpha: 0.2),
      ),
      toggleButtonBuilder: (final context, final extended) => ToggleButton(
        isExtended: extended,
        onToggle: controller.toggleExtended,
      ),
    );
  }
}
