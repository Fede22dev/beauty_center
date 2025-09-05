import 'package:flutter/widgets.dart';

/// A lazy, keep-alive host for tabbed UIs on wide layouts.
/// - Builds a child only when its index is selected the first time (on-demand).
/// - Caches built children and reuses them (state preserved).
/// - Uses Offstage + TickerMode so only the selected one lays out/paints/animates.
class LazyKeepAliveStack extends StatefulWidget {
  const LazyKeepAliveStack({
    super.key,
    required this.index,
    required this.itemCount,
    required this.itemBuilder,
  });

  final int index;
  final int itemCount;
  final Widget Function(BuildContext context, int index) itemBuilder;

  @override
  State<LazyKeepAliveStack> createState() => _LazyKeepAliveStackState();
}

class _LazyKeepAliveStackState extends State<LazyKeepAliveStack> {
  late List<Widget?> _pageCache;

  @override
  void initState() {
    super.initState();
    _pageCache = List<Widget?>.filled(widget.itemCount, null, growable: false);
  }

  @override
  void didUpdateWidget(covariant LazyKeepAliveStack oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.itemCount != oldWidget.itemCount) {
      final newCache = List<Widget?>.filled(
        widget.itemCount,
        null,
        growable: false,
      );
      final minLen = newCache.length < _pageCache.length
          ? newCache.length
          : _pageCache.length;

      for (var i = 0; i < minLen; i++) {
        newCache[i] = _pageCache[i];
      }

      _pageCache = newCache;
    }
  }

  Widget _buildAndCacheItem(int index) {
    if (_pageCache[index] == null) {
      _pageCache[index] = widget.itemBuilder(context, index);
    }

    return _pageCache[index]!;
  }

  @override
  Widget build(BuildContext context) {
    final children = List<Widget>.generate(widget.itemCount, (index) {
      if (index == widget.index) {
        // Build on first selection (lazy).
        final child = _buildAndCacheItem(index);
        
        return Offstage(
          offstage: false,
          child: TickerMode(
            enabled: true,
            child: KeyedSubtree(key: ValueKey('lazy_tab_$index'), child: child),
          ),
        );
      } else {
        final cached = _pageCache[index];
        if (cached == null) {
          return const SizedBox.shrink();
        }

        return Offstage(
          offstage: true,
          child: TickerMode(
            enabled: false,
            child: KeyedSubtree(
              key: ValueKey('lazy_tab_$index'),
              child: cached,
            ),
          ),
        );
      }
    });

    return Stack(children: children);
  }
}
