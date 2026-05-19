import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

import '../../../../core/connectivity/connectivity_providers.dart';
import '../../../../core/database/app_database.dart';
import '../../../../core/database/providers/app_database_provider.dart';
import '../../../../core/providers/background_provider.dart';
import '../../../../core/providers/supabase_auth_provider.dart';
import '../data/repositories/services_repository.dart';

part 'treatments_providers.g.dart';

// ========================================================================
// CORE PROVIDERS
// ========================================================================

/// Services repository with automatic lifecycle management
@riverpod
ServicesRepository servicesRepository(final Ref ref) {
  final db = ref.watch(appDatabaseProvider);
  final supabase = ref.watch(supabaseClientProvider);

  final supabaseAuthState = ref.watch(supabaseAuthProvider);
  final isOffline = ref.watch(isConnectionUnusableProvider);
  final isInForeground = ref.watch(appIsInForegroundProvider);

  final isOnline =
      !isOffline && supabaseAuthState.isConnected && isInForeground;

  final repo = ServicesRepository(
    db: db,
    supabase: supabase,
    isOnline: isOnline,
  );

  ref.onDispose(() async {
    await repo.stopRealtimeSync();
  });

  return repo;
}

// ========================================================================
// STREAM PROVIDERS (Reactive UI updates) - LEGACY SYNTAX PER ERRORI TIPI DRIFT
// ========================================================================

/// Active services stream - automatically updates UI when data changes
final servicesStreamProvider = StreamProvider<List<ServiceData>>(
  (final ref) =>
      ref.watch(servicesRepositoryProvider).watchAllActiveServices(),
);

/// Single service stream by ID
final serviceStreamProvider = StreamProvider.family<ServiceData?, String>(
  (final ref, final serviceId) =>
      ref.watch(servicesRepositoryProvider).watchServiceById(serviceId),
);

// ========================================================================
// ACTIONS PROVIDER
// ========================================================================

/// Actions provider - All write operations go through here
@riverpod
ServicesActions servicesActions(final Ref ref) {
  final repo = ref.watch(servicesRepositoryProvider);
  return ServicesActions(repo);
}

class ServicesActions {
  ServicesActions(this._repo);

  final ServicesRepository _repo;

  // CREATE
  Future<String?> createService({
    required final String name,
    required final double price,
    final int durationMinutes = 30,
    final String? description,
  }) =>
      _repo.createService(
        name: name,
        price: price,
        durationMinutes: durationMinutes,
        description: description,
      );

  // READ
  Future<ServiceData?> getServiceById(final String id) =>
      _repo.getServiceById(id);

  Future<List<ServiceData>> getAllActiveServices() =>
      _repo.getAllActiveServices();

  Future<List<ServiceData>> searchServices(final String query) =>
      _repo.searchServices(query);

  Future<int> getActiveServicesCount() => _repo.getActiveServicesCount();

  // UPDATE
  Future<void> updateService({
    required final String id,
    required final String name,
    required final double price,
    required final int durationMinutes,
    final String? description,
  }) =>
      _repo.updateService(
        id: id,
        name: name,
        price: price,
        durationMinutes: durationMinutes,
        description: description,
      );

  // DELETE
  Future<void> deleteService(final String id) => _repo.deleteService(id);

  // SYNC
  Future<void> syncWithSupabase() => _repo.syncWithSupabase();
}
