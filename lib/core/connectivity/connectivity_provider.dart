import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'connectivity_repository.dart';

final connectivityRepositoryProvider = Provider<ConnectivityRepository>((
  final ref,
) {
  final repo = ConnectivityRepository();
  ref.onDispose(repo.dispose);
  return repo;
});

final connectionQualityStreamProvider = StreamProvider<ConnectionQuality>((
  final ref,
) {
  final repo = ref.watch(connectivityRepositoryProvider);
  return repo.connectionQualityStream;
});

final connectionQualityProvider = Provider<ConnectionQuality>((final ref) {
  final asyncValue = ref.watch(connectionQualityStreamProvider);
  return asyncValue.value ?? ConnectionQuality.offline;
});

final isConnectionUnusableProvider = Provider<bool>((final ref) {
  final quality = ref.watch(connectionQualityProvider);
  return quality == ConnectionQuality.offline ||
      quality == ConnectionQuality.poor;
});
