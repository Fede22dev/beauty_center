import 'package:beauty_center/features/clients/providers/clients_providers.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

import '../../features/appointments/providers/appointments_providers.dart';
import '../../features/appointments/providers/operator_blocked_slots_providers.dart';
import '../../features/fidelity/providers/fidelity_providers.dart';
import '../../features/packages/providers/packages_providers.dart';
import '../../features/payments/providers/payments_providers.dart';
import '../../features/product_sales/providers/product_sales_providers.dart';
import '../../features/products/providers/products_providers.dart';
import '../../features/quotes/providers/quotes_providers.dart';
import '../../features/settings/providers/settings_providers.dart';
import '../../features/treatments/providers/treatments_providers.dart';
import '../connectivity/connectivity_providers.dart';
import '../logging/app_logger.dart';
import '../providers/background_provider.dart';
import '../providers/supabase_auth_provider.dart';

part 'app_sync_manager.g.dart';

@riverpod
class AppSyncStatus extends _$AppSyncStatus {
  @override
  bool build() => false;

  void markAsSynced() => state = true;

  void markAsUnsynced() => state = false;
}

@riverpod
void appSyncManager(final Ref ref) {
  final isOffline = ref.watch(isConnectionUnusableProvider);
  final supabaseAuthState = ref.watch(supabaseAuthProvider);
  final isInForeground = ref.watch(appIsInForegroundProvider);

  final repos = [
    ref.watch(clientsRepositoryProvider),
    ref.watch(settingsRepositoryProvider),
    ref.watch(appointmentsRepositoryProvider),
    ref.watch(operatorBlockedSlotsRepositoryProvider),
    ref.watch(servicesRepositoryProvider),
    ref.watch(quotesRepositoryProvider),
    ref.watch(packagesRepositoryProvider),
    ref.watch(fidelityRepositoryProvider),
    ref.watch(paymentsRepositoryProvider),
    ref.watch(productSalesRepositoryProvider),
    ref.watch(productsRepositoryProvider),
  ];

  Future<void> performSyncIfNeeded() async {
    try {
      // 1. Tabelle base (nessuna dipendenza) in parallelo
      await Future.wait([
        ref.read(settingsRepositoryProvider).syncWithSupabase(),
        ref.read(clientsRepositoryProvider).syncWithSupabase(),
        ref.read(servicesRepositoryProvider).syncWithSupabase(),
        ref.read(productsRepositoryProvider).syncWithSupabase(),
      ]);

      // 2. Tabelle che dipendono da Operatori e Clienti
      await ref.read(operatorBlockedSlotsRepositoryProvider).syncWithSupabase();
      await ref.read(appointmentsRepositoryProvider).syncWithSupabase();

      // 3. Tabelle correlate ai clienti (preventivi, pacchetti, fidelity)
      await Future.wait([
        ref.read(quotesRepositoryProvider).syncWithSupabase(),
        ref.read(packagesRepositoryProvider).syncWithSupabase(),
        ref.read(fidelityRepositoryProvider).syncWithSupabase(),
      ]);

      // 4. Tabelle di pagamenti e vendite (dipendono da clienti/pacchetti/appuntamenti)
      await Future.wait([
        ref.read(paymentsRepositoryProvider).syncWithSupabase(),
        ref.read(productSalesRepositoryProvider).syncWithSupabase(),
      ]);

      ref.read(appSyncStatusProvider.notifier).markAsSynced();
    } catch (e, stackTrace) {
      AppLogger.getLogger(
        name: 'AppSyncManager',
      ).severe('Massive sync failed', e, stackTrace);
      ref.read(appSyncStatusProvider.notifier).markAsUnsynced();
    }
  }

  // CONNECTIVITY LISTENER
  ref
    ..listen<bool>(isConnectionUnusableProvider, (
      final prev,
      final next,
    ) async {
      if (prev == null) return;

      if (prev && !next && supabaseAuthState.isConnected) {
        await performSyncIfNeeded();
      } else if (!prev && next) {
        await Future.wait(repos.map((final repo) => repo.stopRealtimeSync()));
        ref.read(appSyncStatusProvider.notifier).markAsUnsynced();
      }
    })
    // AUTHENTICATION LISTENER
    ..listen<SupabaseAuthState>(supabaseAuthProvider, (
      final prev,
      final next,
    ) async {
      if (prev?.isDisconnected == true && next.isConnected && !isOffline) {
        await performSyncIfNeeded();
      } else if (prev?.isConnected == true && next.isDisconnected) {
        await Future.wait(repos.map((final repo) => repo.stopRealtimeSync()));
        ref.read(appSyncStatusProvider.notifier).markAsUnsynced();
      }
    })
    // APP LIFECYCLE LISTENER
    ..listen<bool>(appIsInForegroundProvider, (final prev, final next) async {
      if (prev == null) return;

      if (prev && !next) {
        await Future.wait(repos.map((final repo) => repo.stopRealtimeSync()));
        ref.read(appSyncStatusProvider.notifier).markAsUnsynced();
      } else if (!prev && next && !isOffline && supabaseAuthState.isConnected) {
        await performSyncIfNeeded();
      }
    });

  // INITIAL SYNC
  if (!ref.read(appSyncStatusProvider) &&
      !isOffline &&
      supabaseAuthState.isConnected &&
      isInForeground) {
    Future.microtask(performSyncIfNeeded);
  }
}
