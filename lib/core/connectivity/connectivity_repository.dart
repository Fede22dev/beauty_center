import 'dart:async';
import 'dart:io';

import 'package:connectivity_plus/connectivity_plus.dart';

import '../logging/app_logger.dart';

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
  static const _periodicCheckIntervalWindows = Duration(seconds: 10);

  static const _checkHosts = [
    ('google.com', 443),
    ('1.1.1.1', 443), // Cloudflare
  ];

  static final _log = AppLogger.getLogger(name: 'ConnectivityRepository');

  Timer? _periodicTimer;

  late final _controller = StreamController<ConnectionQuality>.broadcast(
    onListen: _checkAndEmit,
  );

  StreamSubscription<List<ConnectivityResult>>? _connectivitySubscription;

  var _isInBackground = false;

  // Cache the last known quality to emit immediately to new listeners
  ConnectionQuality _lastKnownQuality =
      ConnectionQuality.good; // Optimistic start

  ConnectionQuality get currentQuality => _lastKnownQuality;

  Stream<ConnectionQuality> get connectionQualityStream => _controller.stream;

  void _init() {
    // RITARDO INIZIALE: Non eseguiamo il ping immediatamente all'avvio.
    // L'app parte col valore ottimistico "good" e aspetta 2 secondi
    // per dare tempo al sistema di liberare i socket dopo l'Hot Restart
    Future.delayed(const Duration(milliseconds: 2000), _checkAndEmit);

    // connectivity_plus lancia NetworkManager::StartListen Windows
    // Ignoriamo l'iscrizione allo stream su Windows per evitare il log errore
    // ed il crash interno al framework. Il nostro Timer periodico compenserà.
    if (!Platform.isWindows) {
      _connectivitySubscription = _connectivity.onConnectivityChanged.listen((
        _,
      ) {
        Future.delayed(const Duration(milliseconds: 500), _checkAndEmit);
      });
    }

    _startPeriodicChecks();
  }

  void _startPeriodicChecks() {
    _periodicTimer?.cancel();

    Duration interval;
    if (_isInBackground) {
      interval = _periodicCheckIntervalBackground;
    } else {
      interval = Platform.isWindows
          ? _periodicCheckIntervalWindows
          : _periodicCheckInterval;
    }

    _periodicTimer = Timer.periodic(interval, (_) => _checkAndEmit());
  }

  Future<void> _checkAndEmit() async {
    try {
      // Timeout globale per sicurezza, nel caso il plugin si incanti
      final quality = await _getConnectionQuality().timeout(
        const Duration(seconds: 10),
      );

      // Aggiunge allo stream SOLO se è cambiato per evitare spam
      if (_lastKnownQuality != quality) {
        _lastKnownQuality = quality;
        _controller.add(quality);
      }
    } catch (e) {
      // Su Hot Restart i canali nativi possono dare eccezioni temporanee.
      // Le ignoriamo per lasciare che il timer riprovi in modo pulito.
      _log.warning('Connectivity check failed: $e');
    }
  }

  void setBackground({required final bool isBackground}) {
    if (_isInBackground == isBackground) return;
    _isInBackground = isBackground;
    _startPeriodicChecks();
  }

  // Check hardware first, then Ping.
  Future<ConnectionQuality> _getConnectionQuality() async {
    // final results = await _connectivity.checkConnectivity();
    //
    // if (_isPhysicallyDisconnected(results)) {
    //   return ConnectionQuality.offline;
    // }

    // Parallel Execution.
    // Instead of checking hosts one by one (sequential), check all at once.
    // The first one to succeed returns the result.
    var latency = await _measureLatencyParallel();

    if (latency == null) {
      await Future<void>.delayed(const Duration(milliseconds: 500));
      latency = await _measureLatencyParallel();
    }

    if (latency != null) {
      _log.finest('Measured latency: ${latency}ms');
      return latency < 300 ? ConnectionQuality.good : ConnectionQuality.poor;
    }

    return ConnectionQuality.offline;
  }

  // bool _isPhysicallyDisconnected(final Iterable<ConnectivityResult> results) =>
  //     !results.any(
  //       (final result) =>
  //           result == ConnectivityResult.wifi ||
  //           result == ConnectivityResult.mobile ||
  //           result == ConnectivityResult.ethernet,
  //     );

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
        socket.destroy();
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
