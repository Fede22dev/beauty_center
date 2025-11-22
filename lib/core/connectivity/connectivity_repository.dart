import 'dart:async';
import 'dart:io';

import 'package:connectivity_plus/connectivity_plus.dart';

enum ConnectionQuality { offline, poor, good }

class ConnectivityRepository {
  ConnectivityRepository() {
    _init();
  }

  final _connectivity = Connectivity();

  // Configuration
  static const _checkTimeout = Duration(seconds: 5);
  static const _periodicCheckInterval = Duration(seconds: 30);
  static const _periodicCheckIntervalBackground = Duration(minutes: 2);

  // Added more reliable hosts (OpenDNS) to the rotation.
  static const _checkHosts = [
    ('google.com', 443),
    ('1.1.1.1', 443), // Cloudflare
    ('208.67.222.222', 443), // OpenDNS
  ];

  Timer? _periodicTimer;

  final _controller = StreamController<ConnectionQuality>.broadcast();
  StreamSubscription<List<ConnectivityResult>>? _connectivitySubscription;

  var _isInBackground = false;

  // Cache the last known quality to emit immediately to new listeners
  ConnectionQuality _lastKnownQuality =
      ConnectionQuality.good; // Optimistic start

  Stream<ConnectionQuality> get connectionQualityStream => _controller.stream;

  Stream<bool> get isOfflineStream =>
      _controller.stream.map((final q) => q == ConnectionQuality.offline);

  void _init() {
    // Emit initial state
    _checkAndEmit();

    // Listen to hardware connectivity changes (Wifi/Mobile on/off)
    _connectivitySubscription = _connectivity.onConnectivityChanged.listen((_) {
      // Debounce could be added here if needed, but force check is usually fine
      _checkAndEmit();
    });

    _startPeriodicChecks();
  }

  void _startPeriodicChecks() {
    _periodicTimer?.cancel();
    final interval = _isInBackground
        ? _periodicCheckIntervalBackground
        : _periodicCheckInterval;

    _periodicTimer = Timer.periodic(interval, (_) => _checkAndEmit());
  }

  Future<void> _checkAndEmit() async {
    // Don't spam checks if the controller has no listeners
    if (!_controller.hasListener) return;

    final quality = await _getConnectionQuality();

    // Only add if changed
    if (_lastKnownQuality != quality) {
      _lastKnownQuality = quality;
      _controller.add(quality);
    } else {
      _controller.add(quality);
    }
  }

  void setBackground({required final bool isBackground}) {
    if (_isInBackground == isBackground) return;
    _isInBackground = isBackground;
    _startPeriodicChecks();
  }

  // Check hardware first, then Ping.
  Future<ConnectionQuality> _getConnectionQuality() async {
    final results = await _connectivity.checkConnectivity();

    if (_isPhysicallyDisconnected(results)) {
      return ConnectionQuality.offline;
    }

    // Parallel Execution.
    // Instead of checking hosts one by one (sequential), check all at once.
    // The first one to succeed returns the result.
    final latency = await _measureLatencyParallel();

    if (latency == null) {
      return ConnectionQuality.offline;
    }

    // Threshold for "Good" vs "Poor"
    return latency < 300 ? ConnectionQuality.good : ConnectionQuality.poor;
  }

  bool _isPhysicallyDisconnected(final Iterable<ConnectivityResult> results) =>
      !results.any(
        (final result) =>
            result == ConnectivityResult.wifi ||
            result == ConnectivityResult.mobile ||
            result == ConnectivityResult.ethernet,
      );

  // Parallel socket checks
  Future<int?> _measureLatencyParallel() async {
    final stopwatch = Stopwatch()..start();

    // Create a list of futures where each attempts to connect
    final futures = _checkHosts.map((final hostData) async {
      final (host, port) = hostData;
      try {
        // Create a dedicated stopwatch for this specific connection
        // to measure accurate latency
        // independent of when the others started.
        final innerStopwatch = Stopwatch()..start();
        final socket = await Socket.connect(host, port, timeout: _checkTimeout);
        innerStopwatch.stop();
        await socket.close();
        return innerStopwatch.elapsedMilliseconds;
      } catch (_) {
        return null;
      }
    });

    try {
      // Stream.fromFutures allows us to listen to completions as they happen.
      // We want the *first* successful non-null result.
      final firstSuccess = await Stream.fromFutures(
        futures,
      ).firstWhere((final latency) => latency != null);

      stopwatch.stop();
      return firstSuccess;
    } catch (_) {
      // If firstWhere fails (no elements found matching condition),
      // it means all failed.
      return null;
    }
  }

  void dispose() {
    _periodicTimer?.cancel();
    _connectivitySubscription?.cancel();
    _controller.close();
  }
}
