import 'package:riverpod_annotation/riverpod_annotation.dart';

import 'connectivity_repository.dart';

part 'connectivity_providers.g.dart';

/// Repository per la connettività (Singleton)
@Riverpod(keepAlive: true)
ConnectivityRepository connectivityRepository(final Ref ref) {
  final repo = ConnectivityRepository();
  ref.onDispose(repo.dispose);
  return repo;
}

/// Trasforma il flusso di dati in un AsyncValue gestito da Riverpod
@Riverpod(keepAlive: true)
Stream<ConnectionQuality> connectionQualityStream(final Ref ref) async* {
  final repo = ref.watch(connectivityRepositoryProvider);

  // 1. Emette IMMEDIATAMENTE l'ultimo stato noto (es. good)
  // Evita che lo schermo mostri "offline" durante i millisecondi del riavvio
  yield repo.currentQuality;

  // 2. Continua ad ascoltare lo stream in tempo reale
  yield* repo.connectionQualityStream;
}

/// Provider sincrono che espone il valore attuale (o un default)
@Riverpod(keepAlive: true)
ConnectionQuality connectionQuality(final Ref ref) {
  final asyncValue = ref.watch(connectionQualityStreamProvider);
  return asyncValue.value ??
      ref.read(connectivityRepositoryProvider).currentQuality;
}

/// Logica derivata: connessione utilizzabile o meno
@Riverpod(keepAlive: true)
bool isConnectionUnusable(final Ref ref) {
  final quality = ref.watch(connectionQualityProvider);
  return quality == ConnectionQuality.offline ||
      quality == ConnectionQuality.poor;
}
