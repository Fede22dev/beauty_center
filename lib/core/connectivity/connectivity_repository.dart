import 'package:connectivity_plus/connectivity_plus.dart';

class ConnectivityRepository {
  ConnectivityRepository._();

  static final instance = ConnectivityRepository._();

  final _connectivity = Connectivity();

  Stream<bool> get isOfflineStream async* {
    final initial = await _connectivity.checkConnectivity();
    yield _isDisconnected(initial);

    yield* _connectivity.onConnectivityChanged.map(_isDisconnected);
  }

  bool _isDisconnected(final Iterable<ConnectivityResult> results) =>
      !results.any(
        (final result) =>
            result == ConnectivityResult.wifi ||
            result == ConnectivityResult.mobile ||
            result == ConnectivityResult.ethernet,
      );
}
