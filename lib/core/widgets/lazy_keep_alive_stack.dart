import 'package:flutter/widgets.dart';

/// A lazy, keep-alive host for tabbed UIs on wide layouts (Windows).
/// - Builds a child only when its index is selected the first time (on-demand).
/// - Caches built children and reuses them (state preserved).
/// - Uses Offstage + TickerMode so only the selected one lays out/paints/animates.
class LazyKeepAliveStack extends StatefulWidget {
  const LazyKeepAliveStack({
    required this.index,
    required this.itemCount,
    required this.itemBuilder,
    super.key,
  });

  final int index;
  final int itemCount;
  final Widget Function(BuildContext context, int index) itemBuilder;

  @override
  State<LazyKeepAliveStack> createState() => _LazyKeepAliveStackState();
}

class _LazyKeepAliveStackState extends State<LazyKeepAliveStack> {
  final Map<int, Widget> _cache = {};

  @override
  void didUpdateWidget(covariant final LazyKeepAliveStack oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.itemCount != oldWidget.itemCount ||
        widget.itemBuilder != oldWidget.itemBuilder) {
      _cache.clear();
    }
  }

  Widget _buildOrGet(final int index) =>
      _cache.putIfAbsent(index, () => widget.itemBuilder(context, index));

  @override
  Widget build(final BuildContext context) => Stack(
    fit: StackFit.expand,
    children: List.generate(widget.itemCount, (final index) {
      final isActive = index == widget.index;

      if (!isActive && _cache[index] == null) {
        return const SizedBox.shrink();
      }

      return Offstage(
        offstage: !isActive,
        child: TickerMode(
          enabled: isActive,
          child: KeyedSubtree(
            key: ValueKey('lazy_tab_$index'),
            child: _buildOrGet(index),
          ),
        ),
      );
    }),
  );
}
