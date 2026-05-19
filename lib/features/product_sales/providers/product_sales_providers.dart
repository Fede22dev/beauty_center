import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

import '../../../core/connectivity/connectivity_providers.dart';
import '../../../core/database/app_database.dart';
import '../../../core/database/providers/app_database_provider.dart';
import '../../../core/providers/background_provider.dart';
import '../../../core/providers/supabase_auth_provider.dart';
import '../data/repositories/product_sales_repository.dart';

part 'product_sales_providers.g.dart';

// ========================================================================
// CORE PROVIDERS
// ========================================================================

/// Product sales repository with automatic client management
@riverpod
ProductSalesRepository productSalesRepository(final Ref ref) {
  final db = ref.watch(appDatabaseProvider);
  final supabase = ref.watch(supabaseClientProvider);

  final supabaseAuthState = ref.watch(supabaseAuthProvider);
  final isOffline = ref.watch(isConnectionUnusableProvider);
  final isInForeground = ref.watch(appIsInForegroundProvider);

  final isOnline =
      !isOffline && supabaseAuthState.isConnected && isInForeground;

  final repo = ProductSalesRepository(
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

/// Product sales stream - automatically updates UI when data changes
final productSalesStreamProvider = StreamProvider<List<ProductSaleData>>(
  (final ref) => ref.watch(productSalesRepositoryProvider).watchAllProductSales(),
);

/// Product sales by client stream
final productSalesByClientStreamProvider = StreamProvider.family<List<ProductSaleData>, String>(
  (final ref, final clientId) =>
      ref.watch(productSalesRepositoryProvider).watchProductSalesByClientId(clientId),
);

/// Single product sale stream by ID
final productSaleStreamProvider = StreamProvider.family<ProductSaleData?, String>(
  (final ref, final saleId) =>
      ref.watch(productSalesRepositoryProvider).watchProductSaleById(saleId),
);

// ========================================================================
// ACTIONS PROVIDER
// ========================================================================

/// Actions provider - All write operations go through here
@riverpod
ProductSalesActions productSalesActions(final Ref ref) {
  final repo = ref.watch(productSalesRepositoryProvider);
  return ProductSalesActions(repo);
}

class ProductSalesActions {
  ProductSalesActions(this._repo);

  final ProductSalesRepository _repo;

  // CREATE
  Future<String?> createProductSale({
    required final String clientId,
    required final String productId,
    required final String lockedProductName,
    required final double lockedPrice,
    final int quantity = 1,
  }) => _repo.createProductSale(
    clientId: clientId,
    productId: productId,
    lockedProductName: lockedProductName,
    lockedPrice: lockedPrice,
    quantity: quantity,
  );

  // READ
  Future<ProductSaleData?> getProductSaleById(final String id) => _repo.getProductSaleById(id);

  Future<List<ProductSaleData>> getAllProductSales() => _repo.getAllProductSales();

  Future<List<ProductSaleData>> getProductSalesByClientId(final String clientId) =>
      _repo.getProductSalesByClientId(clientId);

  // DELETE
  Future<void> deleteProductSale(final String id) => _repo.deleteProductSale(id);

  // SYNC
  Future<void> syncWithSupabase() => _repo.syncWithSupabase();
}
