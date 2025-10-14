import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'connectivity_repository.dart';

/// Singleton repository
final connectivityRepositoryProvider = Provider<ConnectivityRepository>(
  (final ref) => ConnectivityRepository.instance,
);

final isOfflineStreamProvider = StreamProvider<bool>((final ref) {
  final repo = ref.watch(connectivityRepositoryProvider);
  return repo.isOfflineStream;
});

final isOfflineProvider = Provider<bool>((final ref) {
  final asyncValue = ref.watch(isOfflineStreamProvider);
  return asyncValue.value ?? false;
});
