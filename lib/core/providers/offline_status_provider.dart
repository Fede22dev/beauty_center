import 'package:riverpod_annotation/riverpod_annotation.dart';

import '../connectivity/connectivity_providers.dart';
import 'supabase_auth_provider.dart';

part 'offline_status_provider.g.dart';

/// Stato della modalità operativa dell'app
enum AppOperationalMode {
  /// Online completo - tutte le operazioni consentite
  online,

  /// Offline - solo lettura consentita
  offlineReadOnly,

  /// Connessione scarsa - operazioni limitate
  poorConnection,
}

/// Provider che determina se l'app è in modalità read-only
/// Quando offline, tutte le operazioni di scrittura devono essere bloccate
@riverpod
class OfflineStatus extends _$OfflineStatus {
  @override
  AppOperationalMode build() {
    final isOffline = ref.watch(isConnectionUnusableProvider);
    final authState = ref.watch(supabaseAuthProvider);

    // Se offline OPPURE non autenticati → read-only
    if (isOffline || authState.isDisconnected) {
      return AppOperationalMode.offlineReadOnly;
    }

    return AppOperationalMode.online;
  }

  /// Verifica se le operazioni di scrittura sono consentite
  bool get isWriteAllowed => state == AppOperationalMode.online;

  /// Verifica se siamo in modalità read-only
  bool get isReadOnly => state == AppOperationalMode.offlineReadOnly;
}

/// Provider derivato per semplificare i check nell'UI
@riverpod
bool isOfflineReadOnly(Ref ref) {
  return ref.watch(offlineStatusProvider.notifier).isReadOnly;
}

/// Provider che espone un messaggio appropriato per lo stato offline
@riverpod
String? offlineMessage(Ref ref) {
  final mode = ref.watch(offlineStatusProvider);

  return switch (mode) {
    AppOperationalMode.offlineReadOnly =>
      'Modalità offline - Solo visualizzazione',
    AppOperationalMode.poorConnection =>
      'Connessione instabile - Alcune operazioni potrebbero fallire',
    AppOperationalMode.online => null,
  };
}
