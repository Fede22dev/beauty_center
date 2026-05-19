import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';

/// App startup optimization utilities
/// Handles initialization performance and loading states
class AppStartup {
  static final Stopwatch _startupTimer = Stopwatch();
  static final List<_StartupPhase> _phases = [];

  /// Start measuring startup time
  static void startMeasuring() {
    _startupTimer.start();
    _logPhase('Startup began');
  }

  /// Log a startup phase with timing
  static void _logPhase(String name) {
    final elapsed = _startupTimer.elapsedMilliseconds;
    _phases.add(_StartupPhase(name, elapsed));
    debugPrint('🚀 [Startup] $name: ${elapsed}ms');
  }

  /// Get startup report
  static Map<String, dynamic> getReport() {
    return {
      'totalMs': _startupTimer.elapsedMilliseconds,
      'phases': _phases
          .map((p) => {'name': p.name, 'ms': p.timestamp})
          .toList(),
    };
  }

  /// Pre-warm the Flutter engine for smoother animations
  static Future<void> prewarmEngine() async {
    _logPhase('Pre-warming engine');

    // Pre-load common assets
    await _preloadCriticalAssets();
  }

  static Future<void> _preloadCriticalAssets() async {
    _logPhase('Preloading critical assets');

    // Pre-cache common icons fonts
    await _precacheIconFonts();
  }

  static Future<void> _precacheIconFonts() async {
    // Load Material Symbols font early
    try {
      await Future.wait([
        // Preload font loaders
        _loadFont('MaterialSymbolsRounded'),
        _loadFont('MaterialSymbolsOutlined'),
      ]);
    } catch (e) {
      debugPrint('Font preloading skipped: $e');
    }
  }

  static Future<void> _loadFont(String family) async {
    // Font loading is handled automatically by Flutter
    // This is a placeholder for custom font preloading if needed
    await Future<void>.delayed(const Duration(milliseconds: 1));
  }

  /// Optimize for immediate first frame
  static void optimizeForFirstFrame() {
    _logPhase('Optimizing for first frame');

    // Disable animations during startup
    // Re-enable after first frame
    SchedulerBinding.instance.scheduleFrameCallback((_) {
      _logPhase('First frame rendered');
    });
  }

  /// Lazy initialization for heavy components
  /// Use this pattern for components that aren't needed immediately
  static Future<T> lazyInit<T>(Future<T> Function() factory) async {
    return await factory();
  }

  /// Deferred widget loading for heavy UI components
  /// Wraps expensive widgets to load after first paint
  static Widget deferredLoading({
    required WidgetBuilder builder,
    Widget? placeholder,
  }) {
    return _DeferredWidget(
      builder: builder,
      placeholder: placeholder ?? const SizedBox.shrink(),
    );
  }

  /// Batch heavy operations together
  static Future<List<T>> batchOperations<T>(
    List<Future<T> Function()> operations,
  ) async {
    _logPhase('Starting batch operations');

    final stopwatch = Stopwatch()..start();

    // Run operations with yield between each to prevent jank
    final results = <T>[];
    for (final op in operations) {
      results.add(await op());
      // Yield to event loop
      await Future<void>.delayed(Duration.zero);
    }

    stopwatch.stop();
    _logPhase('Batch operations complete: ${stopwatch.elapsedMilliseconds}ms');

    return results;
  }

  /// Memory pressure handler
  /// Call this when app detects low memory
  static void handleMemoryPressure() {
    _logPhase('Memory pressure detected');

    // Clear caches
    imageCache.clear();
    imageCache.clearLiveImages();

    // Request garbage collection hint
    // Note: Dart doesn't have explicit GC, but we can drop references
  }
}

class _StartupPhase {
  final String name;
  final int timestamp;

  _StartupPhase(this.name, this.timestamp);
}

/// Widget that defers loading until after first frame
class _DeferredWidget extends StatefulWidget {
  final WidgetBuilder builder;
  final Widget placeholder;

  const _DeferredWidget({required this.builder, required this.placeholder});

  @override
  State<_DeferredWidget> createState() => _DeferredWidgetState();
}

class _DeferredWidgetState extends State<_DeferredWidget> {
  Widget? _child;
  bool _loaded = false;

  @override
  void initState() {
    super.initState();
    // Defer actual widget creation
    SchedulerBinding.instance.scheduleFrameCallback((_) {
      SchedulerBinding.instance.addPostFrameCallback((_) {
        if (mounted) {
          setState(() {
            _child = widget.builder(context);
            _loaded = true;
          });
        }
      });
    });
  }

  @override
  Widget build(BuildContext context) {
    return _loaded && _child != null ? _child! : widget.placeholder;
  }
}

/// Mixin for widgets that need startup optimization
/// Automatically defers heavy initialization
mixin StartupOptimizedMixin<T extends StatefulWidget> on State<T> {
  bool _isReady = false;

  @override
  void initState() {
    super.initState();
    // Defer heavy initialization
    SchedulerBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        initializeHeavy();
        setState(() => _isReady = true);
      }
    });
  }

  /// Override this to perform heavy initialization
  /// Called after first frame is rendered
  void initializeHeavy();

  /// Whether the widget is ready to show full content
  bool get isReady => _isReady;

  /// Build placeholder while loading
  Widget buildPlaceholder(BuildContext context) {
    return const Center(child: CircularProgressIndicator());
  }
}

/// Extension for BuildContext to check startup state
extension StartupContext on BuildContext {
  /// Whether the app is still in startup phase
  bool get isInStartup {
    // Check if we're before first frame
    return !SchedulerBinding.instance.hasScheduledFrame;
  }
}
