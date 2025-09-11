import 'dart:async';

import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:flutter/foundation.dart';

class ConnectivityRepository {
  ConnectivityRepository._();

  static final ConnectivityRepository instance = ConnectivityRepository._();

  final Connectivity _connectivity = Connectivity();
  final ValueNotifier<bool> _isOffline = ValueNotifier<bool>(false);

  ValueListenable<bool> get isOfflineListenable => _isOffline;

  Future<void> init() async {
    final initial = await _connectivity.checkConnectivity();
    _isOffline.value = !initial.any(
      (final r) =>
          r == ConnectivityResult.wifi ||
          r == ConnectivityResult.mobile ||
          r == ConnectivityResult.ethernet,
    );

    _connectivity.onConnectivityChanged.listen((final result) {
      _isOffline.value = !result.any(
        (final r) =>
            r == ConnectivityResult.wifi ||
            r == ConnectivityResult.mobile ||
            r == ConnectivityResult.ethernet,
      );
    });
  }
}
