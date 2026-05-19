import 'package:beauty_center/home/presentation/desktop/widgets/navigations/toggle_button.dart';
import 'package:flutter/material.dart';
import 'package:sidebarx/sidebarx.dart';

import '../../../../../core/constants/app_constants.dart';
import '../../../../../core/tabs/app_tabs.dart';
import '../../../widgets/animated_rotation_icon.dart';

class SideNav extends StatefulWidget {
  const SideNav({
    required this.selectedIndex,
    required this.controller,
    super.key,
  });

  final int selectedIndex;
  final SidebarXController controller;

  @override
  State<SideNav> createState() => _SideNavState();
}

class _SideNavState extends State<SideNav> {
  late final List<GlobalKey> _sidebarItemKeys;

  @override
  void initState() {
    super.initState();

    _sidebarItemKeys = List.generate(AppTabs.values.length, (_) => GlobalKey());

    widget.controller.addListener(_handleScroll);

    WidgetsBinding.instance.addPostFrameCallback((_) {
      _handleScroll();
    });
  }

  @override
  void dispose() {
    widget.controller.removeListener(_handleScroll);
    super.dispose();
  }

  void _handleScroll() {
    final index = widget.controller.selectedIndex;
    if (index >= 0 && index < _sidebarItemKeys.length) {
      final context = _sidebarItemKeys[index].currentContext;
      if (context != null) {
        Scrollable.ensureVisible(
          context,
          duration: kDefaultAppAnimationsDuration,
          curve: Curves.easeInOut,
          alignment: 0.5,
        );
      }
    }
  }

  @override
  Widget build(final BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return SidebarX(
      controller: widget.controller,
      animationDuration: kDefaultAppAnimationsDuration,
      theme: SidebarXTheme(
        width: 100,
        margin: const EdgeInsets.fromLTRB(4, 20, 4, 20),
        padding: const EdgeInsets.symmetric(vertical: 4, horizontal: 2),
        decoration: BoxDecoration(
          color: Color.alphaBlend(
            AppTabs.values[widget.selectedIndex].color.withValues(alpha: 0.1),
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
          color: AppTabs.values[widget.selectedIndex].color,
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
            AppTabs.values[widget.selectedIndex].color.withValues(alpha: 0.1),
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
          color: AppTabs.values[widget.selectedIndex].color,
          fontSize: 16,
          fontWeight: FontWeight.w600,
        ),
        itemTextPadding: const EdgeInsets.only(left: 8),
        selectedItemTextPadding: const EdgeInsets.only(left: 8),
      ),
      items: [
        for (int i = 0; i < AppTabs.values.length; i++)
          SidebarXItem(
            label: AppTabs.values[i].label(context),
            iconBuilder: (final selected, final hovered) => Container(
              key: _sidebarItemKeys[i],
              alignment: Alignment.center,
              child: AnimatedRotationIcon(
                key: ValueKey(AppTabs.values[i]),
                icon: AppTabs.values[i].icon,
                color: selected
                    ? AppTabs.values[i].color
                    : (hovered
                          ? AppTabs.values[i].color.withValues(alpha: 0.65)
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
        onToggle: widget.controller.toggleExtended,
      ),
    );
  }
}
