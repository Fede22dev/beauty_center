import 'dart:math' as math;
import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:go_router/go_router.dart';

import '../core/app_routes.dart';
import '../features/appointments/presentation/pages/appointments_page.dart';
import '../features/clients/presentation/pages/clients_page.dart';
import '../features/settings/presentation/pages/settings_page.dart';
import '../features/stats/presentation/pages/stats_page.dart';
import '../features/treatments/presentation/pages/treatments_page.dart';
import '../generated/l10n.dart';

@immutable
class AppTab {
  final String Function(BuildContext) label;
  final IconData icon;
  final String path;
  final Widget Function() builder;

  const AppTab({
    required this.label,
    required this.icon,
    required this.path,
    required this.builder,
  });
}

class Home extends StatefulWidget {
  final String initialTab;

  const Home({super.key, required this.initialTab});

  @override
  State<Home> createState() => _HomeState();
}

class _HomeState extends State<Home> {
  late int _currentIndex;
  bool _railExtended = false; // Start collapsed; toggle via BrandMark

  late final List<AppTab> _tabs = [
    AppTab(
      label: (ctx) => S.of(ctx).appointments,
      icon: Icons.calendar_month,
      path: AppRoutes.appointments.path,
      builder: () => const AppointmentsPage(),
    ),
    AppTab(
      label: (ctx) => S.of(ctx).clients,
      icon: Icons.people,
      path: AppRoutes.clients.path,
      builder: () => const ClientsPage(),
    ),
    AppTab(
      label: (ctx) => S.of(ctx).treatments,
      icon: Icons.spa,
      path: AppRoutes.treatments.path,
      builder: () => const TreatmentsPage(),
    ),
    AppTab(
      label: (ctx) => S.of(ctx).stats,
      icon: Icons.query_stats,
      path: AppRoutes.stats.path,
      builder: () => const StatsPage(),
    ),
    AppTab(
      label: (ctx) => S.of(ctx).settings,
      icon: Icons.settings,
      path: AppRoutes.settings.path,
      builder: () => const SettingsPage(),
    ),
  ];

  late final List<Widget?> _pages;

  @override
  void initState() {
    super.initState();
    final int idx = _tabs.indexWhere((tab) => tab.path == widget.initialTab);
    _currentIndex = idx == -1 ? 0 : idx;
    _pages = List<Widget?>.filled(_tabs.length, null, growable: false);
  }

  void _onTabSelected(int index) {
    if (index == _currentIndex) return;
    HapticFeedback.selectionClick();
    setState(() => _currentIndex = index);
    context.go('${AppRoutes.home.path}${_tabs[index].path}');
  }

  bool _showLabels(BuildContext context) {
    final screenWidth = MediaQuery.of(context).size.width;
    final estimatedLabelWidth = _tabs.fold<double>(
      0,
      (prev, tab) => prev + tab.label(context).length * 8 + 48,
    );
    return estimatedLabelWidth <= screenWidth;
  }

  Widget _pageAt(int index) {
    final cached = _pages[index];
    if (cached != null) return cached;
    final widget = _tabs[index].builder();
    final page = _FirstMountFade(child: widget);
    _pages[index] = page;
    return page;
  }

  @override
  Widget build(BuildContext context) {
    final isWide = MediaQuery.of(context).size.width >= 920;

    if (isWide) {
      // Auto-extend on very wide screens, keep user toggle thereafter
      return Scaffold(
        extendBody: true,
        body: Row(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(12, 16, 12, 16),
              child: _Glass(
                radius: 20,
                child: _FullHeightRail(
                  tabs: _tabs,
                  currentIndex: _currentIndex,
                  extended: _railExtended,
                  onToggleExtended: () => setState(() {
                    _railExtended = !_railExtended;
                  }),
                  onSelect: _onTabSelected,
                ),
              ),
            ),
            const VerticalDivider(width: 1, indent: 8, endIndent: 8),
            Expanded(
              child: SafeArea(
                child: IndexedStack(
                  index: _currentIndex,
                  children: List<Widget>.generate(_tabs.length, _pageAt),
                ),
              ),
            ),
          ],
        ),
      );
    }

    // Compact layout (NavigationBar)
    return Scaffold(
      extendBody: true,
      body: SafeArea(
        top: false,
        bottom: false,
        child: IndexedStack(
          index: _currentIndex,
          children: List<Widget>.generate(_tabs.length, _pageAt),
        ),
      ),
      bottomNavigationBar: Padding(
        padding: const EdgeInsets.fromLTRB(12, 0, 12, 12),
        child: _Glass(
          radius: 18,
          child: NavigationBar(
            selectedIndex: _currentIndex,
            onDestinationSelected: _onTabSelected,
            labelBehavior: _showLabels(context)
                ? NavigationDestinationLabelBehavior.alwaysShow
                : NavigationDestinationLabelBehavior.alwaysHide,
            destinations: List.generate(_tabs.length, (i) {
              final t = _tabs[i];
              final selected = i == _currentIndex;
              return NavigationDestination(
                icon: _NavIcon(icon: t.icon, selected: selected),
                label: t.label(context),
                tooltip: t.label(context),
              );
            }),
          ),
        ),
      ),
    );
  }
}

class _FullHeightRail extends StatelessWidget {
  final List<AppTab> tabs;
  final int currentIndex;
  final bool extended;
  final VoidCallback onToggleExtended;
  final ValueChanged<int> onSelect;

  const _FullHeightRail({
    required this.tabs,
    required this.currentIndex,
    required this.extended,
    required this.onToggleExtended,
    required this.onSelect,
  });

  @override
  Widget build(BuildContext context) {
    final metrics = _RailMetrics.calculate(context, tabs);
    final targetWidth = extended
        ? metrics.extendedWidth
        : metrics.collapsedWidth;
    return AnimatedContainer(
      duration: const Duration(milliseconds: 180),
      curve: Curves.easeOutCubic,
      width: targetWidth,
      height: double.infinity,
      child: LayoutBuilder(
        builder: (context, constraints) {
          final currentW = constraints.maxWidth;
          final expandT =
              ((currentW - metrics.collapsedWidth) /
                      (metrics.extendedWidth - metrics.collapsedWidth))
                  .clamp(0.0, 1.0);
          final labelStartW = metrics.collapsedWidth + 8.0;
          final labelEndW = metrics.extendedWidth - 4.0;
          final labelRevealT =
              ((currentW - labelStartW) / (labelEndW - labelStartW)).clamp(
                0.0,
                1.0,
              );
          final showBrandDetails =
              extended && currentW + 0.5 >= metrics.brandRevealWidth;
          return Column(
            children: [
              Padding(
                padding: const EdgeInsets.only(
                  top: 10,
                  left: 8,
                  right: 8,
                  bottom: 12,
                ),
                child: _BrandMarkButton(
                  showDetails: showBrandDetails,
                  onTap: onToggleExtended,
                ),
              ),
              Expanded(
                child: Column(
                  children: List.generate(tabs.length, (i) {
                    final t = tabs[i];
                    final selected = i == currentIndex;
                    return Expanded(
                      child: _RailItem(
                        icon: t.icon,
                        labelBuilder: t.label,
                        selected: selected,
                        revealT: labelRevealT,
                        expandT: expandT,
                        onTap: () => onSelect(i),
                      ),
                    );
                  }),
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}

// Measures strings and computes the exact extended width needed.
class _RailMetrics {
  final double collapsedWidth;
  final double extendedWidth;
  final double itemRevealWidth;
  final double brandRevealWidth;

  const _RailMetrics({
    required this.collapsedWidth,
    required this.extendedWidth,
    required this.itemRevealWidth,
    required this.brandRevealWidth,
  });

  static _RailMetrics calculate(BuildContext context, List<AppTab> tabs) {
    // Costanti di layout (coerenti con i widget sottostanti)
    const double collapsed = 96.0; // rail chiusa
    const double outerHPad = 18.0; // Padding esterno per cella
    const double innerHPad =
        36.0; // 18 + 18 padding interno quando label visibile
    const double iconRef =
        40.0; // icona di riferimento per il calcolo larghezza
    const double gap = 18.0; // gap icona-label
    // Brand pill
    const double brandHPad = 24.0; // 12 + 12
    const double brandIcon = 24.0;
    const double brandChevron = 24.0;
    const double brandGap = 10.0;
    final dir = Directionality.of(context);
    final theme = Theme.of(context);
    final labelStyle = (theme.textTheme.titleMedium ?? const TextStyle())
        .copyWith(
          fontSize: 16.0,
          fontWeight: FontWeight.w700,
          letterSpacing: 0.1,
        );
    // Max label width tra le tab
    double maxLabelW = 0;
    for (final t in tabs) {
      final text = t.label(context);
      maxLabelW = math.max(maxLabelW, _measure(text, labelStyle, dir));
    }
    // Larghezza necessaria per una cella item (icona + gap + label + padding)
    final itemWidth = outerHPad + innerHPad + iconRef + gap + maxLabelW;
    // Larghezza necessaria per il Brand ("Menu" + icona + chevron + padding)
    final brandText = S.of(context).menu;
    final brandTextW = _measure(brandText, labelStyle, dir);
    final brandWidth =
        brandHPad + brandIcon + brandGap + brandTextW + brandChevron;
    // Extended width = max(item, brand) clamped a 360
    final extended = math.min(math.max(itemWidth, brandWidth), 360.0);
    return _RailMetrics(
      collapsedWidth: collapsed,
      extendedWidth: extended,
      itemRevealWidth: itemWidth,
      brandRevealWidth: brandWidth,
    );
  }

  static double _measure(String text, TextStyle style, TextDirection dir) {
    final tp = TextPainter(
      text: TextSpan(text: text, style: style),
      maxLines: 1,
      textDirection: dir,
    )..layout();
    return tp.width;
  }
}

class _RailItem extends StatefulWidget {
  final IconData icon;
  final String Function(BuildContext) labelBuilder;
  final bool selected;
  final double revealT; // 0..1: label visibility/width factor
  final double expandT; // 0..1: full rail expansion fraction
  final VoidCallback onTap;

  const _RailItem({
    required this.icon,
    required this.labelBuilder,
    required this.selected,
    required this.revealT,
    required this.expandT,
    required this.onTap,
  });

  @override
  State<_RailItem> createState() => _RailItemState();
}

class _RailItemState extends State<_RailItem> {
  bool _hovered = false;
  bool _pressed = false;

  static const _kAnim = Duration(milliseconds: 1080);
  static const _kCurve = Curves.easeOutCubic;
  static const double _kEps = 0.001;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
      child: LayoutBuilder(
        builder: (context, constraints) {
          final cellH = constraints.maxHeight;
          final cellW = constraints.maxWidth;
          final iconSize = (cellH * 0.44).clamp(30.0, 42.0);
          final gapTarget = (iconSize * 0.45).clamp(10.0, 22.0);
          const double innerHPad = 18.0;
          final double innerW = math.max(0.0, cellW - innerHPad * 2.0);

          // Reveal controlled by parent
          final double t = widget.revealT.clamp(0.0, 1.0);
          final bool collapsed = t <= _kEps;

          // Colors
          final baseBg = widget.selected
              ? cs.primaryContainer.withValues(alpha: 0.72)
              : cs.surface.withValues(alpha: 0.00);
          final hoverTint = cs.primary.withValues(alpha: 0.15);
          final pressedTint = cs.primary.withValues(alpha: 0.10);
          final bg = _pressed
              ? Color.lerp(baseBg, pressedTint, 0.8)!
              : (_hovered ? Color.lerp(baseBg, hoverTint, 0.8)! : baseBg);
          final baseBorder = widget.selected
              ? cs.primary.withValues(alpha: 0.25)
              : cs.outlineVariant.withValues(alpha: 0.40);
          final border = _hovered
              ? Color.lerp(baseBorder, cs.primary.withValues(alpha: 0.5), 0.5)!
              : baseBorder;
          final fg = widget.selected
              ? cs.onPrimaryContainer
              : cs.onSurfaceVariant;

          final double iconAllocW = math.min(iconSize, math.max(0.0, innerW));
          final double rawGap = gapTarget * t;
          final double maxGapThatFits = math.max(
            0.0,
            innerW - iconAllocW - 1.0,
          );
          final double gap = collapsed ? 0.0 : math.min(rawGap, maxGapThatFits);
          final double labelMaxW = math.max(0.0, innerW - iconAllocW - gap) - 2;
          final double labelT = collapsed ? 0.0 : math.min(0.998, t);

          return MouseRegion(
            onEnter: (_) => setState(() => _hovered = true),
            onExit: (_) => setState(() => _hovered = false),
            cursor: SystemMouseCursors.click,
            child: GestureDetector(
              onTapDown: (_) => setState(() => _pressed = true),
              onTapUp: (_) => setState(() => _pressed = false),
              onTapCancel: () => setState(() => _pressed = false),
              onTap: widget.onTap,
              behavior: HitTestBehavior.opaque,
              child: AnimatedContainer(
                duration: _kAnim,
                curve: _kCurve,
                constraints: const BoxConstraints.expand(),
                decoration: BoxDecoration(
                  color: bg,
                  borderRadius: BorderRadius.circular(18),
                  border: Border.all(color: border),
                  boxShadow: (_hovered || widget.selected)
                      ? [
                          BoxShadow(
                            color: Colors.black.withValues(alpha: 0.08),
                            blurRadius: 14,
                            offset: const Offset(0, 6),
                          ),
                        ]
                      : const [],
                ),
                padding: const EdgeInsets.symmetric(horizontal: innerHPad),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.start,
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    // Icon container occupies at most innerW and scales down if needed by a few px
                    SizedBox(
                      width: iconAllocW,
                      height: iconSize, // height controls visual size reference
                      child: FittedBox(
                        fit: BoxFit.scaleDown,
                        // scale the icon only if innerW < iconSize
                        alignment: Alignment.centerLeft,
                        child: Icon(
                          widget.icon,
                          size: iconSize,
                          color: _hovered && !widget.selected
                              ? Color.lerp(fg, cs.primary, 0.12)
                              : fg,
                        ),
                      ),
                    ),
                    SizedBox(width: gap),
                    // Hard bound label width to available space; reveal fractionally
                    SizedBox(
                      width: labelMaxW,
                      child: ClipRect(
                        child: FractionallySizedBox(
                          alignment: Alignment.centerLeft,
                          widthFactor: labelT,
                          child: AnimatedOpacity(
                            opacity: labelT,
                            duration: _kAnim,
                            curve: _kCurve,
                            child: Text(
                              widget.labelBuilder(context),
                              maxLines: 1,
                              overflow: TextOverflow.fade,
                              softWrap: false,
                              style: TextStyle(
                                color: fg,
                                fontSize: widget.selected ? 16.0 : 15.0,
                                fontWeight: FontWeight.w600,
                                letterSpacing: 0.1,
                              ),
                            ),
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          );
        },
      ),
    );
  }
}

class _BrandMarkButton extends StatelessWidget {
  final bool showDetails;
  final VoidCallback onTap;

  const _BrandMarkButton({required this.showDetails, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return InkWell(
      onTap: () {
        HapticFeedback.lightImpact();
        onTap();
      },
      borderRadius: BorderRadius.circular(999),
      child: Container(
        width: double.infinity,
        height: 56,
        padding: const EdgeInsets.symmetric(horizontal: 12),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(999),
          gradient: LinearGradient(
            colors: [cs.primary, cs.secondary],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.10),
              blurRadius: 14,
              offset: const Offset(0, 6),
            ),
          ],
        ),
        child: Row(
          mainAxisAlignment: showDetails
              ? MainAxisAlignment.start
              : MainAxisAlignment.center,
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            Icon(Icons.spa_rounded, color: cs.onPrimary, size: 24),
            if (showDetails) ...[
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  S.of(context).menu,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    color: cs.onPrimary,
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                    letterSpacing: 0.1,
                  ),
                ),
              ),
              Icon(Icons.chevron_left_rounded, color: cs.onPrimary, size: 24),
            ],
          ],
        ),
      ),
    );
  }
}

// -------- Helpers (glass, icon anim, first mount fade) --------
class _Glass extends StatelessWidget {
  final double radius;
  final Widget child;

  const _Glass({required this.radius, required this.child});

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;

    return RepaintBoundary(
      child: ClipRRect(
        borderRadius: BorderRadius.circular(radius),
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 18, sigmaY: 18),
          child: DecoratedBox(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [
                  cs.surface.withValues(alpha: 0.72),
                  cs.surface.withValues(alpha: 0.42),
                ],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              border: Border.all(
                color: cs.outlineVariant.withValues(alpha: 0.55),
              ),
              borderRadius: BorderRadius.circular(radius),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.06),
                  blurRadius: 18,
                  offset: const Offset(0, 8),
                ),
              ],
            ),
            child: child,
          ),
        ),
      ),
    );
  }
}

class _NavIcon extends StatelessWidget {
  final IconData icon;
  final bool selected;

  const _NavIcon({required this.icon, required this.selected});

  @override
  Widget build(BuildContext context) {
    return AnimatedScale(
      scale: selected ? 1.08 : 1.0,
      duration: const Duration(milliseconds: 160),
      curve: Curves.easeOut,
      child: Icon(icon),
    );
  }
}

class _FirstMountFade extends StatefulWidget {
  final Widget child;

  const _FirstMountFade({required this.child});

  @override
  State<_FirstMountFade> createState() => _FirstMountFadeState();
}

class _FirstMountFadeState extends State<_FirstMountFade>
    with SingleTickerProviderStateMixin {
  late final AnimationController _c = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 220),
  )..forward();
  late final Animation<double> _ease = CurvedAnimation(
    parent: _c,
    curve: Curves.easeOutCubic,
  );

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return ScaleTransition(
      scale: Tween(begin: 0.96, end: 1.0).animate(_ease),
      child: FadeTransition(opacity: _ease, child: widget.child),
    );
  }
}
