import 'package:flutter/material.dart' show Color, TimeOfDay;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

import '../../../../core/connectivity/connectivity_providers.dart';
import '../../../../core/database/app_database.dart';
import '../../../../core/database/providers/app_database_provider.dart';
import '../../../../core/providers/background_provider.dart';
import '../../../../core/providers/supabase_auth_provider.dart';
import '../data/repositories/settings_repository.dart';

part 'settings_providers.g.dart';

typedef CabinList = List<Cabin>;
typedef OperatorList = List<Operator>;
typedef AppWorkHours = WorkHours;

// ========================================================================
// CORE PROVIDERS
// ========================================================================

/// Settings repository with automatic client management
@riverpod
SettingsRepository settingsRepository(final Ref ref) {
  final db = ref.watch(appDatabaseProvider);
  final supabase = ref.watch(supabaseClientProvider);

  final supabaseAuthState = ref.watch(supabaseAuthProvider);
  final isOffline = ref.watch(isConnectionUnusableProvider);
  final isInForeground = ref.watch(appIsInForegroundProvider);

  final isOnline =
      !isOffline && supabaseAuthState.isConnected && isInForeground;

  final repo = SettingsRepository(
    db: db,
    supabase: supabase,
    isOnline: isOnline,
  );

  // Ensure default work hours exist in local DB (for offline/unauthenticated users)
  // Fire-and-forget: we don't await since this is optional initialization
  repo.ensureDefaultWorkHours();

  // Automatic cleanup
  ref.onDispose(() async {
    await repo.stopRealtimeSync();
  });

  return repo;
}

// ========================================================================
// STREAM PROVIDERS (Reactive UI updates) - LEGACY SYNTAX PER ERRORI TIPI DRIFT
// ========================================================================

/// Active cabins stream - automatically updates UI when data changes
final activeCabinsStreamProvider = StreamProvider<List<Cabin>>(
      (final ref) =>
      ref.watch(settingsRepositoryProvider).watchAllActiveCabins(),
);

/// All cabins count stream - automatically updates UI when data changes
final maxCabinsStreamProvider = StreamProvider<int>((ref) {
  final repo = ref.watch(settingsRepositoryProvider);
  return repo.watchAllCabinsCount();
});

/// Active operators stream - automatically updates UI when data changes
final operatorsStreamProvider = StreamProvider<List<Operator>>(
      (final ref) =>
      ref.watch(settingsRepositoryProvider).watchAllActiveOperators(),
);

/// All operators count stream - automatically updates UI when data changes
final maxOperatorsStreamProvider = StreamProvider<int>((ref) {
  final repo = ref.watch(settingsRepositoryProvider);
  return repo.watchAllOperatorsCount();
});

/// Work hours stream - automatically updates UI when data changes
final workHoursStreamProvider = StreamProvider<WorkHours?>(
      (final ref) => ref.watch(settingsRepositoryProvider).watchWorkHours(),
);

// ========================================================================
// ACTIONS PROVIDER
// ========================================================================

/// Actions provider - All write operations go through here
@riverpod
SettingsActions settingsActions(final Ref ref) {
  final repo = ref.watch(settingsRepositoryProvider);
  return SettingsActions(repo);
}

class SettingsActions {
  SettingsActions(this._repo);

  final SettingsRepository _repo;

  // CABINS
  Future<int> getAllCabinsCount() => _repo.getAllCabinsCount();

  Future<void> updateCabinColor({
    required final int id,
    required final Color color,
  }) => _repo.updateCabinColor(id: id, color: color);

  Future<void> setCabinsCount(final int targetCount) =>
      _repo.setCabinsCount(targetCount);

  // OPERATORS
  Future<void> addOperator() => _repo.addOperator();

  Future<void> updateOperatorName({
    required final int id,
    required final String name,
  }) => _repo.updateOperatorName(id: id, name: name);

  Future<void> deleteOperator({required final int id}) =>
      _repo.deleteOperator(id);

  // WORK HOURS
  Future<void> updateWorkHours({
    required final TimeOfDay startTime,
    required final TimeOfDay endTime,
  }) => _repo.updateWorkHours(startTime: startTime, endTime: endTime);
}
