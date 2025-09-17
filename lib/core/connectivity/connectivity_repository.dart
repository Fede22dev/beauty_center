import 'dart:async';

import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:flutter/foundation.dart';

class ConnectivityRepository {
  ConnectivityRepository._();

  static final instance = ConnectivityRepository._();

  final _connectivity = Connectivity();
  final _isOffline = ValueNotifier<bool>(false);

  ValueListenable<bool> get isOfflineListenable => _isOffline;

  bool _isDisconnected(final Iterable<ConnectivityResult> results) =>
      !results.any(
        (final result) =>
            result == ConnectivityResult.wifi ||
            result == ConnectivityResult.mobile ||
            result == ConnectivityResult.ethernet,
      );

  Future<void> init() async {
    _isOffline.value = _isDisconnected(await _connectivity.checkConnectivity());
    _connectivity.onConnectivityChanged.listen((final results) {
      _isOffline.value = _isDisconnected(results);
    });
  }
}
