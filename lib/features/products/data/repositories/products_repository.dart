import 'package:drift/drift.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:uuid/uuid.dart';

import '../../../../core/constants/app_constants.dart';
import '../../../../core/database/app_database.dart';
import '../../../../core/database/repositories/base_repository.dart';
import '../../../../core/database/supabase_schema.dart';
import '../../../../core/logging/app_logger.dart';

/// Repository for products catalog management
/// Implements offline-first pattern with Supabase sync
class ProductsRepository extends BaseRepository {
  ProductsRepository({
    required super.db,
    required super.supabase,
    required super.isOnline,
  });

  static final _log = AppLogger.getLogger(name: 'ProductsRepository');

  List<OrderingTerm Function(ProductsTable)> get _defaultOrdering => [
    (final t) => OrderingTerm.asc(t.name),
  ];

  // ========================================================================
  // PRODUCTS - QUERIES (Read operations - always from local DB)
  // ========================================================================

  /// Get all active products ordered by name
  Future<List<ProductData>> getAllActiveProducts() =>
      (db.select(db.productsTable)
            ..where((final t) => t.isActive.equals(true))
            ..orderBy(_defaultOrdering))
          .get();

  /// Watch all active products stream for reactive UI updates
  Stream<List<ProductData>> watchAllActiveProducts() =>
      (db.select(db.productsTable)
            ..where((final t) => t.isActive.equals(true))
            ..orderBy(_defaultOrdering))
          .watch();

  /// Get product by ID
  Future<ProductData?> getProductById(final String id) => (db.select(
    db.productsTable,
  )..where((final t) => t.id.equals(id))).getSingleOrNull();

  /// Watch product by ID for reactive UI updates
  Stream<ProductData?> watchProductById(final String id) => (db.select(
    db.productsTable,
  )..where((final t) => t.id.equals(id))).watchSingleOrNull();

  /// Search products by name or description
  Future<List<ProductData>> searchProducts(final String query) {
    final searchTerm = '%${query.trim().toLowerCase()}%';
    return (db.select(db.productsTable)
          ..where(
            (final t) =>
                t.isActive.equals(true) &
                (t.name.lower().like(searchTerm) |
                    t.description.lower().like(searchTerm)),
          )
          ..orderBy(_defaultOrdering))
        .get();
  }

  /// Get total active products count
  Future<int> getActiveProductsCount() async {
    final countExp = db.productsTable.id.count();
    final query = db.selectOnly(db.productsTable)
      ..addColumns([countExp])
      ..where(db.productsTable.isActive.equals(true));
    return await query.map((final row) => row.read(countExp)).getSingle() ?? 0;
  }

  // ========================================================================
  // PRODUCTS - CRUD (Write operations - sync with Supabase)
  // ========================================================================

  /// Create new product
  /// Returns product ID or null if offline (read-only mode)
  Future<String?> createProduct({
    required final String name,
    required final double price,
    final String? description,
  }) async {
    if (!isOnline) {
      _log.warning('Cannot create product: offline mode (read-only)');
      return null;
    }

    final now = DateTime.now().toUtc();

    final insertedProduct = await db
        .into(db.productsTable)
        .insertReturning(
          ProductsTableCompanion.insert(
            id: Value(const Uuid().v7()),
            name: name.trim(),
            price: Value(price),
            description: Value(description?.trim()),
            createdAt: Value(now),
            updatedAt: Value(now),
            isActive: const Value(true),
          ),
        );

    syncAsync(
      'product_${insertedProduct.id}',
      () => _syncProductToSupabase(insertedProduct.id),
    );

    return insertedProduct.id;
  }

  /// Update product information
  /// Returns true if successful, false if offline (read-only mode)
  Future<bool> updateProduct({
    required final String id,
    required final String name,
    required final double price,
    final String? description,
  }) async {
    if (!isOnline) {
      _log.warning('Cannot update product: offline mode (read-only)');
      return false;
    }

    final companion = ProductsTableCompanion(
      name: Value(name.trim()),
      price: Value(price),
      description: Value(description?.trim()),
      updatedAt: Value(DateTime.now().toUtc()),
    );

    await (db.update(
      db.productsTable,
    )..where((final t) => t.id.equals(id))).write(companion);

    syncAsync('product_$id', () => _syncProductToSupabase(id));
    return true;
  }

  /// Soft delete product
  /// Returns true if successful, false if offline (read-only mode)
  Future<bool> deleteProduct(final String id) async {
    if (!isOnline) {
      _log.warning('Cannot delete product: offline mode (read-only)');
      return false;
    }

    final companion = ProductsTableCompanion(
      isActive: const Value(false),
      updatedAt: Value(DateTime.now().toUtc()),
    );

    await (db.update(
      db.productsTable,
    )..where((final t) => t.id.equals(id))).write(companion);

    syncAsync('product_$id', () => _syncProductToSupabase(id));

    return true;
  }

  // ========================================================================
  // SYNC IMPLEMENTATION (BaseRepository overrides)
  // ========================================================================

  @override
  Future<void> pullSupabaseToLocal() async {
    if (!isOnline) return;

    try {
      final lastSync = await getLastSyncTime(kLastSyncTimeProductsKey);

      var query = supabase!.from(SupabaseSchema.products.tableName).select();

      if (lastSync != null) {
        final adjustedTime = lastSync.subtract(kLastSyncBufferDuration);
        query = query.gt(
          SupabaseProductsTable.updatedAt,
          adjustedTime.toIso8601String(),
        );
      }

      final updatesData = await query;

      final allRemoteIdsData = await supabase!
          .from(SupabaseSchema.products.tableName)
          .select(SupabaseProductsTable.id);

      final remoteIds = List<Map<String, dynamic>>.from(
        allRemoteIdsData,
      ).map((final e) => e[SupabaseProductsTable.id] as String).toSet();

      await db.transaction(() async {
        if (updatesData.isNotEmpty) {
          await db.batch((final batch) {
            final companions = updatesData.map(_mapSupabaseDataToCompanion);
            batch.insertAllOnConflictUpdate(db.productsTable, companions);
          });
          _log.info('Synced ${updatesData.length} updated/new products.');
        }

        if (remoteIds.isNotEmpty) {
          await (db.delete(
            db.productsTable,
          )..where((final t) => t.id.isNotIn(remoteIds))).go();
        } else if (updatesData.isEmpty) {
          await db.delete(db.productsTable).go();
        }
      });

      await updateLastSyncTime(kLastSyncTimeProductsKey);
    } catch (e, stackTrace) {
      _log.warning('Pull from Supabase failed', e, stackTrace);
    }
  }

  @override
  void startRealtimeSync() {
    if (!isOnline) return;

    subscribeToChannel(
      table: SupabaseSchema.products,
      onEvent: _handleProductChange,
    );

    _log.info('Realtime sync started for products');
  }

  // ========================================================================
  // REALTIME EVENT HANDLER
  // ========================================================================

  Future<void> _handleProductChange(final PostgresChangePayload payload) async {
    try {
      switch (payload.eventType) {
        case PostgresChangeEvent.insert:
        case PostgresChangeEvent.update:
          final data = payload.newRecord;

          await db
              .into(db.productsTable)
              .insertOnConflictUpdate(_mapSupabaseDataToCompanion(data));

          _log.finest(
            'Product ${data[SupabaseProductsTable.id]} synced from realtime',
          );

        case PostgresChangeEvent.delete:
          final oldData = payload.oldRecord;
          final id = oldData[SupabaseProductsTable.id] as String;

          await (db.delete(
            db.productsTable,
          )..where((final t) => t.id.equals(id))).go();
          _log.finest('Product $id deleted from realtime');

        case PostgresChangeEvent.all:
          throw UnimplementedError('PostgresChangeEvent.all not supported');
      }
    } catch (e, stackTrace) {
      _log.warning('Failed to handle product change', e, stackTrace);
    }
  }

  // ========================================================================
  // PRIVATE SYNC HELPERS
  // ========================================================================

  ProductsTableCompanion _mapSupabaseDataToCompanion(
    final Map<String, dynamic> data,
  ) => ProductsTableCompanion.insert(
    id: Value(data[SupabaseProductsTable.id] as String),
    name: data[SupabaseProductsTable.name] as String,
    description: Value(data[SupabaseProductsTable.description] as String?),
    price: Value((data[SupabaseProductsTable.price] as num?)?.toDouble() ?? 0),
    createdAt: Value(
      DateTime.parse(data[SupabaseProductsTable.createdAt] as String).toLocal(),
    ),
    updatedAt: Value(
      DateTime.parse(data[SupabaseProductsTable.updatedAt] as String).toLocal(),
    ),
    isActive: Value(data[SupabaseProductsTable.isActive] as bool? ?? true),
  );

  Future<void> _syncProductToSupabase(final String id) async {
    try {
      final product = await getProductById(id);
      if (product == null) return;

      await supabase?.from(SupabaseSchema.products.tableName).upsert({
        SupabaseProductsTable.id: product.id,
        SupabaseProductsTable.name: product.name,
        SupabaseProductsTable.description: product.description,
        SupabaseProductsTable.price: product.price,
        SupabaseProductsTable.createdAt: product.createdAt
            .toUtc()
            .toIso8601String(),
        SupabaseProductsTable.updatedAt: product.updatedAt
            .toUtc()
            .toIso8601String(),
        SupabaseProductsTable.isActive: product.isActive,
      });
    } catch (e, stackTrace) {
      _log.warning('Failed to sync product $id to Supabase', e, stackTrace);
    }
  }
}
