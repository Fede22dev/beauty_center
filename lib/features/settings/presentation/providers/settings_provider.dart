import 'package:flutter/material.dart' show Color, TimeOfDay;
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/database/app_database.dart';
import '../../data/repositories/settings_repository.dart';

// ========================================================================

// CORE PROVIDERS
/// Database instance provider (Singleton)
/// Automatically closed when provider is disposed
final appDatabaseProvider = Provider<AppDatabase>((final ref) {
  final db = AppDatabase();
  ref.onDispose(db.close);
  return db;
});

/// Repository provider
/// Depends on database provider
final settingsRepositoryProvider = Provider<SettingsRepository>(
  (final ref) => SettingsRepository(ref.watch(appDatabaseProvider)),
);

// ========================================================================

// STREAM PROVIDERS (Real-time data)
/// Cabins stream (auto-updates UI when data changes)
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

// FUTURE PROVIDERS (For one-time data fetching)
/// Get cabins count (useful for sliders/counters)
final cabinsCountProvider = FutureProvider<int>(
  (final ref) => ref.watch(settingsRepositoryProvider).getCabinsCount(),
);

/// Get operators count
final operatorsCountProvider = FutureProvider<int>(
  (final ref) => ref.watch(settingsRepositoryProvider).getOperatorsCount(),
);

// ========================================================================

// ACTIONS PROVIDER
/// Actions provider - All write operations
/// Simple pass-through to repository (no business logic here)
final settingsActionsProvider = Provider<SettingsActions>(SettingsActions.new);

class SettingsActions {
  SettingsActions(this._ref);

  final Ref _ref;

  SettingsRepository get _repo => _ref.read(settingsRepositoryProvider);

  // ========================================================================

  // CABINS ACTIONS
  /// Add new cabin with specified color
  Future<int> addCabin({required final int id, required final Color color}) =>
      _repo.addCabin(id: id, color: color);

  /// Update cabin color
  Future<void> updateCabinColor({
    required final int id,
    required final Color color,
  }) async {
    await _repo.updateCabinColor(id: id, color: color);
  }

  /// Delete cabin
  Future<void> deleteCabin({required final int id}) async {
    await _repo.deleteCabin(id);
  }

  /// Set cabins count (add or remove to match target)
  /// Business logic handled in repository
  Future<void> setCabinsCount(final int targetCount) async {
    await _repo.setCabinsCount(targetCount);

    // Invalidate count provider to refresh UI
    _ref.invalidate(cabinsCountProvider);
  }

  // ========================================================================

  // OPERATORS ACTIONS
  /// Add new operator
  Future<int> addOperator({
    required final int id,
    required final String name,
  }) => _repo.addOperator(id: id, name: name);

  /// Update operator name
  Future<void> updateOperatorName({
    required final int id,
    required final String name,
  }) async {
    await _repo.updateOperatorName(id: id, name: name);
  }

  /// Delete operator
  Future<void> deleteOperator({required final int id}) async {
    await _repo.deleteOperator(id);
  }

  /// Set operators count (add or remove to match target)
  Future<void> setOperatorsCount(final int targetCount) async {
    await _repo.setOperatorsCount(targetCount);

    // Invalidate count provider to refresh UI
    _ref.invalidate(operatorsCountProvider);
  }

  // ========================================================================

  // WORK HOURS ACTIONS
  /// Update work hours
  Future<void> updateWorkHours({
    required final TimeOfDay startTime,
    required final TimeOfDay endTime,
  }) async {
    await _repo.updateWorkHours(startTime: startTime, endTime: endTime);
  }
}
