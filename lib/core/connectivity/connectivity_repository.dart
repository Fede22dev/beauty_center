import 'dart:async';

import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:flutter/foundation.dart';

/// Repository singleton per gestire lo stato di connessione
class ConnectivityRepository {
  ConnectivityRepository._();

  static final ConnectivityRepository instance = ConnectivityRepository._();

  final Connectivity _connectivity = Connectivity();
  final ValueNotifier<bool> _isOffline = ValueNotifier<bool>(false);

  ValueListenable<bool> get isOfflineListenable => _isOffline;

  Future<void> init() async {
    final initial = await _connectivity.checkConnectivity();
    _isOffline.value = !initial.any(
      (r) => r == ConnectivityResult.wifi || r == ConnectivityResult.mobile,
    );

    _connectivity.onConnectivityChanged.listen((result) {
      _isOffline.value = !result.any(
        (r) => r == ConnectivityResult.wifi || r == ConnectivityResult.mobile,
      );
    });
  }
}
