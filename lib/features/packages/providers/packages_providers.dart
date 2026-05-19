import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

import '../../../core/connectivity/connectivity_providers.dart';
import '../../../core/database/app_database.dart';
import '../../../core/database/providers/app_database_provider.dart';
import '../../../core/providers/background_provider.dart';
import '../../../core/providers/supabase_auth_provider.dart';
import '../data/repositories/packages_repository.dart';

part 'packages_providers.g.dart';

// ========================================================================
// CORE PROVIDERS
// ========================================================================

/// Packages repository with automatic client management
@riverpod
PackagesRepository packagesRepository(final Ref ref) {
  final db = ref.watch(appDatabaseProvider);
  final supabase = ref.watch(supabaseClientProvider);

  final supabaseAuthState = ref.watch(supabaseAuthProvider);
  final isOffline = ref.watch(isConnectionUnusableProvider);
  final isInForeground = ref.watch(appIsInForegroundProvider);

  final isOnline =
      !isOffline && supabaseAuthState.isConnected && isInForeground;

  final repo = PackagesRepository(
    db: db,
    supabase: supabase,
    isOnline: isOnline,
  );

  // Automatic cleanup
  ref.onDispose(() async {
    await repo.stopRealtimeSync();
  });

  return repo;
}

// ========================================================================
// STREAM PROVIDERS (Reactive UI updates)
// ========================================================================

/// Packages stream - automatically updates UI when data changes
final packagesStreamProvider = StreamProvider<List<PackageData>>(
  (final ref) => ref.watch(packagesRepositoryProvider).watchAllPackages(),
);

/// Packages by client stream
final packagesByClientStreamProvider = StreamProvider.family<List<PackageData>, String>(
  (final ref, final clientId) =>
      ref.watch(packagesRepositoryProvider).watchPackagesByClientId(clientId),
);

/// Active packages by client stream
final activePackagesByClientStreamProvider = StreamProvider.family<List<PackageData>, String>(
  (final ref, final clientId) =>
      ref.watch(packagesRepositoryProvider).watchActivePackagesByClientId(clientId),
);

/// Single package stream by ID
final packageStreamProvider = StreamProvider.family<PackageData?, String>(
  (final ref, final packageId) =>
      ref.watch(packagesRepositoryProvider).watchPackageById(packageId),
);

/// Package items by package stream
final packageItemsStreamProvider = StreamProvider.family<List<PackageItemData>, String>(
  (final ref, final packageId) =>
      ref.watch(packagesRepositoryProvider).watchPackageItemsByPackageId(packageId),
);

// ========================================================================
// ACTIONS PROVIDER
// ========================================================================

/// Actions provider - All write operations go through here
@riverpod
PackagesActions packagesActions(final Ref ref) {
  final repo = ref.watch(packagesRepositoryProvider);
  return PackagesActions(repo);
}

class PackagesActions {
  PackagesActions(this._repo);

  final PackagesRepository _repo;

  // CREATE
  Future<String?> createPackage({
    required final String clientId,
    required final String name,
    required final double totalPrice,
    final String? quoteId,
    final DateTime? expiresAt,
    final String? notes,
    required final List<PackageItemData> items,
  }) => _repo.createPackage(
    clientId: clientId,
    name: name,
    totalPrice: totalPrice,
    quoteId: quoteId,
    expiresAt: expiresAt,
    notes: notes,
    items: items,
  );

  // READ
  Future<PackageData?> getPackageById(final String id) => _repo.getPackageById(id);

  Future<List<PackageData>> getAllPackages() => _repo.getAllPackages();

  Future<List<PackageData>> getPackagesByClientId(final String clientId) =>
      _repo.getPackagesByClientId(clientId);

  Future<List<PackageData>> getActivePackagesByClientId(final String clientId) =>
      _repo.getActivePackagesByClientId(clientId);

  Future<List<PackageItemData>> getPackageItemsByPackageId(final String packageId) =>
      _repo.getPackageItemsByPackageId(packageId);

  // UPDATE
  Future<void> updatePackageStatus({
    required final String id,
    required final String status,
  }) => _repo.updatePackageStatus(id: id, status: status);

  Future<void> updatePackagePaidAmount({
    required final String id,
    required final double paidAmount,
  }) => _repo.updatePackagePaidAmount(id: id, paidAmount: paidAmount);

  Future<void> incrementUsedSessions(final String packageItemId) =>
      _repo.incrementUsedSessions(packageItemId);

  Future<void> decrementUsedSessions(final String packageItemId) =>
      _repo.decrementUsedSessions(packageItemId);

  // DELETE
  Future<void> deletePackage(final String id) => _repo.deletePackage(id);

  // SYNC
  Future<void> syncWithSupabase() => _repo.syncWithSupabase();
}
