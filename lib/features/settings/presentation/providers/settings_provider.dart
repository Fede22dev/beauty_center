import 'package:flutter/material.dart' show Color, TimeOfDay;
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/connectivity/connectivity_provider.dart';
import '../../../../core/database/app_database.dart';
import '../../../../core/supabase/supabase_auth_provider.dart';
import '../../data/repositories/settings_repository.dart';

// ========================================================================
// CORE PROVIDERS
// ========================================================================

/// Database instance provider (Singleton)
final appDatabaseProvider = Provider<AppDatabase>((final ref) {
  final db = AppDatabase();
  ref.onDispose(db.close);
  return db;
});

/// Settings repository with automatic client management
final settingsRepositoryProvider = Provider<SettingsRepository>((final ref) {
  final db = ref.watch(appDatabaseProvider);

  // Use convenience provider for client
  final supabase = ref.watch(supabaseClientProvider);

  final repo = SettingsRepository(db, supabase: supabase);

  // Automatic cleanup
  ref.onDispose(() async {
    await repo.stopRealtimeSync();
  });

  return repo;
});

// ========================================================================
// STREAM PROVIDERS (Reactive UI updates)
// ========================================================================

/// Cabins stream - automatically updates UI when data changes
final cabinsStreamProvider = StreamProvider<List<Cabin>>(
  (final ref) => ref.watch(settingsRepositoryProvider).watchCabins(),
);

/// Operators stream
final operatorsStreamProvider = StreamProvider<List<Operator>>(
  (final ref) => ref.watch(settingsRepositoryProvider).watchOperators(),
);

/// Work hours stream
final workHoursStreamProvider = StreamProvider<WorkHours>(
  (final ref) => ref.watch(settingsRepositoryProvider).watchWorkHours(),
);

// ========================================================================
// ACTIONS PROVIDER
// ========================================================================

/// Actions provider - All write operations go through here
final settingsActionsProvider = Provider<SettingsActions>(SettingsActions.new);

class SettingsActions {
  SettingsActions(this._ref);

  final Ref _ref;

  SettingsRepository get _repo => _ref.read(settingsRepositoryProvider);

  // CABINS
  Future<int> addCabin({required final int id, required final Color color}) =>
      _repo.addCabin(id: id, color: color);

  Future<void> updateCabinColor({
    required final int id,
    required final Color color,
  }) => _repo.updateCabinColor(id: id, color: color);

  Future<void> deleteCabin({required final int id}) => _repo.deleteCabin(id);

  Future<void> setCabinsCount(final int targetCount) =>
      _repo.setCabinsCount(targetCount);

  // OPERATORS
  Future<int> addOperator({
    required final int id,
    required final String name,
  }) => _repo.addOperator(id: id, name: name);

  Future<void> updateOperatorName({
    required final int id,
    required final String name,
  }) => _repo.updateOperatorName(id: id, name: name);

  Future<void> deleteOperator({required final int id}) =>
      _repo.deleteOperator(id);

  Future<void> setOperatorsCount(final int targetCount) =>
      _repo.setOperatorsCount(targetCount);

  // WORK HOURS
  Future<void> updateWorkHours({
    required final TimeOfDay startTime,
    required final TimeOfDay endTime,
  }) => _repo.updateWorkHours(startTime: startTime, endTime: endTime);

  // SYNC
  Future<void> syncWithSupabase() => _repo.syncWithSupabase();
}

// ========================================================================
// Sync manager
// ========================================================================

/// Manages automatic synchronization between local DB and Supabase
/// Handles connectivity changes, authentication state changes, and initial sync
final settingsSyncManagerProvider = Provider<void>((final ref) {
  final repo = ref.watch(settingsRepositoryProvider);
  final supabaseAuthState = ref.watch(supabaseAuthProvider);
  final isOffline = ref.watch(isOfflineProvider);

  // Track sync state
  var hasSyncedThisSession = false;

  /// Helper to perform sync if conditions are met
  Future<void> performSyncIfNeeded() async {
    if (hasSyncedThisSession) return;
    if (isOffline || !supabaseAuthState.isConnected) return;

    try {
      await repo.syncWithSupabase();
      hasSyncedThisSession = true;
    } catch (e) {
      // Sync failed - will retry on next state change
      hasSyncedThisSession = false;
    }
  }

  // CONNECTIVITY LISTENER
  ref
    ..listen<bool>(isOfflineProvider, (final prev, final next) async {
      if (prev == true && next == false) {
        // From offline -> online
        if (supabaseAuthState.isConnected) {
          await performSyncIfNeeded();
        }
      } else if (next == true) {
        // Gone offline - stop realtime to save resources
        await repo.stopRealtimeSync();
        hasSyncedThisSession = false;
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
          await performSyncIfNeeded();
        }
      } else if (prev?.isConnected == true && next.isDisconnected) {
        // Just logged out
        await repo.stopRealtimeSync();
        hasSyncedThisSession = false;
      }
    });

  // ========================================================================
  // INITIAL SYNC
  // ========================================================================

  // Perform initial sync if already online and authenticated
  if (!hasSyncedThisSession && !isOffline && supabaseAuthState.isConnected) {
    // Use microtask to avoid sync during provider build
    Future.microtask(performSyncIfNeeded);
  }

  return;
});
