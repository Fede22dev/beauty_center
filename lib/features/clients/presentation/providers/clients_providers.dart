import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/connectivity/connectivity_provider.dart';
import '../../../../core/database/app_database.dart';
import '../../../../core/database/providers/app_database_provider.dart';
import '../../../../core/providers/background_provider.dart';
import '../../../../core/providers/supabase_auth_provider.dart';
import '../repositories/clients_repository.dart';

// ========================================================================
// CORE PROVIDERS
// ========================================================================

/// Clients repository with automatic client management
final clientsRepositoryProvider = Provider<ClientsRepository>((final ref) {
  final db = ref.watch(appDatabaseProvider);
  final supabase = ref.watch(supabaseClientProvider);

  final supabaseAuthState = ref.watch(supabaseAuthProvider);
  final isOffline = ref.watch(isConnectionUnusableProvider);

  final isOnline = !isOffline && supabaseAuthState.isConnected;

  final repo = ClientsRepository(
    db: db,
    supabase: supabase,
    isOnline: isOnline,
  );

  // Automatic cleanup
  ref.onDispose(() async {
    await repo.stopRealtimeSync();
  });

  return repo;
});

// ========================================================================
// STREAM PROVIDERS (Reactive UI updates)
// ========================================================================

/// Clients stream - automatically updates UI when data changes
final clientsStreamProvider = StreamProvider<List<Client>>(
  (final ref) => ref.watch(clientsRepositoryProvider).watchClients(),
);

/// Single client stream by ID
final clientStreamProvider = StreamProvider.family<Client?, String>(
  (final ref, final clientId) =>
      ref.watch(clientsRepositoryProvider).watchClientById(clientId),
);

// ========================================================================
// ACTIONS PROVIDER
// ========================================================================

/// Actions provider - All write operations go through here
final clientsActionsProvider = Provider<ClientsActions>(ClientsActions.new);

class ClientsActions {
  ClientsActions(this._ref);

  final Ref _ref;

  ClientsRepository get _repo => _ref.read(clientsRepositoryProvider);

  // CREATE
  Future<String> createClient({
    required final String firstName,
    required final String lastName,
    required final String phoneNumber,
    final String? email,
    final DateTime? birthDate,
    final String? address,
    final String? notes,
  }) => _repo.createClient(
    firstName: firstName,
    lastName: lastName,
    phoneNumber: phoneNumber,
    email: email,
    birthDate: birthDate,
    address: address,
    notes: notes,
  );

  // READ
  Future<Client?> getClientById(final String id) => _repo.getClientById(id);

  Future<List<Client>> getAllClients() => _repo.getAllClients();

  Future<List<Client>> searchClients(final String query) =>
      _repo.searchClients(query);

  Future<int> getClientsCount() => _repo.getClientsCount();

  // UPDATE
  Future<void> updateClient({
    required final String id,
    required final String firstName,
    required final String lastName,
    required final String phoneNumber,
    final String? email,
    final DateTime? birthDate,
    final String? address,
    final String? notes,
  }) => _repo.updateClient(
    id: id,
    firstName: firstName,
    lastName: lastName,
    phoneNumber: phoneNumber,
    email: email,
    birthDate: birthDate,
    address: address,
    notes: notes,
  );

  // DELETE
  Future<void> deleteClient(final String id) => _repo.deleteClient(id);

  // SYNC
  Future<void> syncWithSupabase() => _repo.syncWithSupabase();
}

// ========================================================================
// SYNC STATE MANAGEMENT
// ========================================================================

/// Notifier to track sync state
class ClientsSyncNotifier extends Notifier<bool> {
  @override
  bool build() => false;

  void markAsSynced() => state = true;

  void markAsUnsynced() => state = false;
}

final _clientsSyncStateProvider = NotifierProvider<ClientsSyncNotifier, bool>(
  ClientsSyncNotifier.new,
);

// ========================================================================
// SYNC MANAGER (Background-Aware)
// ========================================================================

/// Manages automatic synchronization between local DB and Supabase
/// Handles connectivity changes, authentication state changes, and initial sync
final clientsSyncManagerProvider = Provider<void>((final ref) {
  final repo = ref.watch(clientsRepositoryProvider);
  final supabaseAuthState = ref.watch(supabaseAuthProvider);
  final isOffline = ref.watch(isConnectionUnusableProvider);

  /// Helper to perform sync if conditions are met
  Future<void> performSync() async {
    try {
      await repo.syncWithSupabase();
      ref.read(_clientsSyncStateProvider.notifier).markAsSynced();
    } catch (e) {
      // Sync failed - will retry on next state change
      ref.read(_clientsSyncStateProvider.notifier).markAsUnsynced();
    }
  }

  // CONNECTIVITY LISTENER
  ref
    ..listen<bool>(isConnectionUnusableProvider, (
      final prev,
      final next,
    ) async {
      if (prev == null) return;

      // From offline -> online
      if (prev && !next && supabaseAuthState.isConnected) {
        await performSync();
      } else if (!prev && next) {
        // Gone offline - stop realtime to save resources
        await repo.stopRealtimeSync();
        ref.read(_clientsSyncStateProvider.notifier).markAsUnsynced();
      }
    })
    // AUTHENTICATION LISTENER
    ..listen<SupabaseAuthState>(supabaseAuthProvider, (
      final prev,
      final next,
    ) async {
      if (prev?.isDisconnected == true && next.isConnected) {
        // Just authenticated
        if (!isOffline) {
          await performSync();
        }
      } else if (prev?.isConnected == true && next.isDisconnected) {
        // Just logged out
        await repo.stopRealtimeSync();
        ref.read(_clientsSyncStateProvider.notifier).markAsUnsynced();
      }
    })
    // APP LIFECYCLE LISTENER (Background/Foreground)
    ..listen<bool>(appIsInForegroundProvider, (final prev, final next) async {
      if (prev == null) return;

      // App went to background
      if (prev && !next) {
        // Stop realtime to save battery and avoid Android killing WebSocket
        await repo.stopRealtimeSync();
        ref.read(_clientsSyncStateProvider.notifier).markAsUnsynced();
      }
      // App returned to foreground
      else if (!prev && next) {
        // Reconnect and sync if online and authenticated
        if (!isOffline && supabaseAuthState.isConnected) {
          await performSync();
        }
      }
    });

  // ========================================================================
  // INITIAL SYNC
  // ========================================================================

  // Perform initial sync if already online and authenticated
  final hasSynced = ref.read(_clientsSyncStateProvider);
  final isForeground = ref.read(appIsInForegroundProvider);
  if (!hasSynced &&
      !isOffline &&
      supabaseAuthState.isConnected &&
      isForeground) {
    // Use microtask to avoid sync during provider build
    Future.microtask(performSync);
  }

  return;
});
