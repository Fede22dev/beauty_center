import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

import '../../../../core/connectivity/connectivity_providers.dart';
import '../../../../core/database/app_database.dart';
import '../../../../core/database/providers/app_database_provider.dart';
import '../../../../core/providers/background_provider.dart';
import '../../../../core/providers/supabase_auth_provider.dart';
import '../data/repositories/products_repository.dart';

part 'products_providers.g.dart';

// ========================================================================
// CORE PROVIDERS
// ========================================================================

/// Products repository with automatic lifecycle management
@riverpod
ProductsRepository productsRepository(final Ref ref) {
  final db = ref.watch(appDatabaseProvider);
  final supabase = ref.watch(supabaseClientProvider);

  final supabaseAuthState = ref.watch(supabaseAuthProvider);
  final isOffline = ref.watch(isConnectionUnusableProvider);
  final isInForeground = ref.watch(appIsInForegroundProvider);

  final isOnline =
      !isOffline && supabaseAuthState.isConnected && isInForeground;

  final repo = ProductsRepository(
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

/// Active products stream - automatically updates UI when data changes
final productsStreamProvider = StreamProvider<List<ProductData>>(
  (final ref) =>
      ref.watch(productsRepositoryProvider).watchAllActiveProducts(),
);

/// Single product stream by ID
final productStreamProvider = StreamProvider.family<ProductData?, String>(
  (final ref, final productId) =>
      ref.watch(productsRepositoryProvider).watchProductById(productId),
);

// ========================================================================
// ACTIONS PROVIDER
// ========================================================================

/// Actions provider - All write operations go through here
@riverpod
ProductsActions productsActions(final Ref ref) {
  final repo = ref.watch(productsRepositoryProvider);
  return ProductsActions(repo);
}

class ProductsActions {
  ProductsActions(this._repo);

  final ProductsRepository _repo;

  // CREATE
  Future<String?> createProduct({
    required final String name,
    required final double price,
    final String? description,
  }) =>
      _repo.createProduct(
        name: name,
        price: price,
        description: description,
      );

  // READ
  Future<ProductData?> getProductById(final String id) =>
      _repo.getProductById(id);

  Future<List<ProductData>> getAllActiveProducts() =>
      _repo.getAllActiveProducts();

  Future<List<ProductData>> searchProducts(final String query) =>
      _repo.searchProducts(query);

  Future<int> getActiveProductsCount() => _repo.getActiveProductsCount();

  // UPDATE
  Future<void> updateProduct({
    required final String id,
    required final String name,
    required final double price,
    final String? description,
  }) =>
      _repo.updateProduct(
        id: id,
        name: name,
        price: price,
        description: description,
      );

  // DELETE
  Future<void> deleteProduct(final String id) => _repo.deleteProduct(id);

  // SYNC
  Future<void> syncWithSupabase() => _repo.syncWithSupabase();
}
