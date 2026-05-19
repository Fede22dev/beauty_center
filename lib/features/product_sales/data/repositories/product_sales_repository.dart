import 'package:drift/drift.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:uuid/uuid.dart';

import '../../../../core/constants/app_constants.dart';
import '../../../../core/database/app_database.dart';
import '../../../../core/database/repositories/base_repository.dart';
import '../../../../core/database/supabase_schema.dart';
import '../../../../core/logging/app_logger.dart';

/// Repository for product sales management
/// Implements offline-first pattern with Supabase sync
class ProductSalesRepository extends BaseRepository {
  ProductSalesRepository({
    required super.db,
    required super.supabase,
    required super.isOnline,
  });

  static final _log = AppLogger.getLogger(name: 'ProductSalesRepository');

  List<OrderingTerm Function(ProductSalesTable)> get _defaultOrdering => [
    (final t) => OrderingTerm.desc(t.createdAt),
  ];

  // ========================================================================
  // PRODUCT SALES - QUERIES (Read operations - always from local DB)
  // ========================================================================

  /// Get all product sales ordered by creation date
  Future<List<ProductSaleData>> getAllProductSales() =>
      (db.select(db.productSalesTable)
            ..where((final t) => t.isActive.equals(true))
            ..orderBy(_defaultOrdering))
          .get();

  /// Watch all product sales stream for reactive UI updates
  Stream<List<ProductSaleData>> watchAllProductSales() =>
      (db.select(db.productSalesTable)
            ..where((final t) => t.isActive.equals(true))
            ..orderBy(_defaultOrdering))
          .watch();

  /// Get product sales by client ID
  Future<List<ProductSaleData>> getProductSalesByClientId(
    final String clientId,
  ) =>
      (db.select(db.productSalesTable)
            ..where(
              (final t) =>
                  t.clientId.equals(clientId) & t.isActive.equals(true),
            )
            ..orderBy(_defaultOrdering))
          .get();

  /// Watch product sales by client ID for reactive UI updates
  Stream<List<ProductSaleData>> watchProductSalesByClientId(
    final String clientId,
  ) =>
      (db.select(db.productSalesTable)
            ..where(
              (final t) =>
                  t.clientId.equals(clientId) & t.isActive.equals(true),
            )
            ..orderBy(_defaultOrdering))
          .watch();

  /// Get product sale by ID
  Future<ProductSaleData?> getProductSaleById(final String id) => (db.select(
    db.productSalesTable,
  )..where((final t) => t.id.equals(id))).getSingleOrNull();

  /// Watch product sale by ID for reactive UI updates
  Stream<ProductSaleData?> watchProductSaleById(final String id) => (db.select(
    db.productSalesTable,
  )..where((final t) => t.id.equals(id))).watchSingleOrNull();

  // ========================================================================
  // PRODUCT SALES - CRUD (Write operations - sync with Supabase)
  // ========================================================================

  /// Create new product sale
  /// Returns sale ID or null on error
  /// Note: Works offline - sync to Supabase happens in background
  Future<String?> createProductSale({
    required final String clientId,
    required final String productId,
    required final String lockedProductName,
    required final double lockedPrice,
    final int quantity = 1,
  }) async {
    final now = DateTime.now().toUtc();
    final lineTotal = lockedPrice * quantity;

    final insertedSale = await db
        .into(db.productSalesTable)
        .insertReturning(
          ProductSalesTableCompanion.insert(
            id: Value(const Uuid().v7()),
            clientId: Value(clientId),
            productId: productId,
            lockedProductName: lockedProductName.trim(),
            lockedPrice: lockedPrice,
            quantity: Value(quantity),
            lineTotal: lineTotal,
            createdAt: Value(now),
            isActive: const Value(true),
          ),
        );

    _log.info('Product sale ${insertedSale.id} created locally, scheduling sync...');
    
    // Esegui sync in background con retry robusto
    await _triggerSyncWithDebounce(insertedSale.id);

    return insertedSale.id;
  }

  /// Soft delete product sale
  /// Returns true if successful, false on error
  Future<bool> deleteProductSale(final String id) async {
    try {
      final companion = ProductSalesTableCompanion(isActive: const Value(false));

      await (db.update(
        db.productSalesTable,
      )..where((final t) => t.id.equals(id))).write(companion);

      _log.info('Product sale $id deleted locally');
      
      // Sync deletion to Supabase
      if (supabase != null) {
        await _syncProductSaleToSupabase(id);
      }
      return true;
    } catch (e) {
      _log.warning('Failed to delete product sale $id', e);
      return false;
    }
  }

  // ========================================================================
  // SYNC HELPER - Robust sync with retry
  // ========================================================================

  /// Trigger sync con debounce e retry robusto
  Future<void> _triggerSyncWithDebounce(final String productSaleId) async {
    const maxAttempts = 5;
    var attempt = 0;

    while (attempt < maxAttempts) {
      attempt++;
      
      try {
        if (supabase == null) {
          _log.warning('Supabase not available, sync attempt $attempt/$maxAttempts failed');
          await Future.delayed(Duration(seconds: attempt * 2));
          continue;
        }

        _log.finest('Sync attempt $attempt/$maxAttempts for product sale $productSaleId');
        await _syncProductSaleToSupabase(productSaleId);
        
        _log.info('Product sale $productSaleId synced successfully on attempt $attempt');
        return;
        
      } on PostgrestException catch (e) {
        if (e.code == '23503') {
          _log.warning('FK error on attempt $attempt, will retry...');
          await Future.delayed(Duration(seconds: attempt * 3));
        } else {
          _log.warning('Postgrest error on attempt $attempt: ${e.message}');
          await Future.delayed(Duration(seconds: attempt * 2));
        }
      } catch (e) {
        _log.warning('Sync attempt $attempt failed: $e');
        await Future.delayed(Duration(seconds: attempt * 2));
      }
    }

    _log.warning('Product sale $productSaleId failed to sync after $maxAttempts attempts');
  }

  // ========================================================================
  // SYNC IMPLEMENTATION (BaseRepository overrides)
  // ========================================================================

  @override
  Future<void> pullSupabaseToLocal() async {
    // CRITICAL: Verifica che supabase sia disponibile
    if (supabase == null) {
      _log.warning('Cannot pull product sales: Supabase client is null');
      return;
    }

    try {
      final lastSync = await getLastSyncTime(kLastSyncTimeProductSalesKey);

      var query = supabase?.from(SupabaseSchema.productSales.tableName).select();
      if (query == null) {
        _log.warning('Cannot pull product sales: Supabase client is null');
        return;
      }

      if (lastSync != null) {
        final adjustedTime = lastSync.subtract(kLastSyncBufferDuration);
        query = query.gt(
          SupabaseProductSalesTable.createdAt,
          adjustedTime.toIso8601String(),
        );
      }

      final updatesData = await query;

      final allRemoteIdsData = await supabase
          ?.from(SupabaseSchema.productSales.tableName)
          .select(SupabaseProductSalesTable.id) ?? [];

      final remoteIds = List<Map<String, dynamic>>.from(
        allRemoteIdsData,
      ).map((final e) => e[SupabaseProductSalesTable.id] as String).toSet();

      await db.transaction(() async {
        if (updatesData.isNotEmpty) {
          await db.batch((final batch) {
            final companions = updatesData.map(_mapSupabaseDataToCompanion);
            batch.insertAllOnConflictUpdate(db.productSalesTable, companions);
          });
          _log.info('Synced ${updatesData.length} updated/new product sales.');
        }

        // CRITICAL: Non cancellare record creati dopo l'ultimo sync (local-only)
        if (remoteIds.isNotEmpty) {
          final lastSyncThreshold = lastSync ?? DateTime(2000).toUtc();
          await (db.delete(db.productSalesTable)..where(
                (final t) =>
                    t.id.isNotIn(remoteIds) &
                    t.createdAt.isSmallerThan(Variable(lastSyncThreshold)),
              )).go();
        } else if (updatesData.isEmpty && lastSync != null) {
          // Solo se c'è stato almeno un sync prima
          await (db.delete(db.productSalesTable)
            ..where((final t) => t.createdAt.isSmallerThan(Variable(lastSync!)))).go();
        }
      });

      await updateLastSyncTime(kLastSyncTimeProductSalesKey);
    } catch (e, stackTrace) {
      _log.warning('Pull from Supabase failed', e, stackTrace);
    }
  }

  @override
  void startRealtimeSync() {
    if (!isOnline) return;

    subscribeToChannel(
      table: SupabaseSchema.productSales,
      onEvent: _handleProductSaleChange,
    );

    _log.info('Realtime sync started for product sales');
  }

  // ========================================================================
  // REALTIME EVENT HANDLER
  // ========================================================================

  Future<void> _handleProductSaleChange(
    final PostgresChangePayload payload,
  ) async {
    try {
      switch (payload.eventType) {
        case PostgresChangeEvent.insert:
        case PostgresChangeEvent.update:
          final data = payload.newRecord;

          await db
              .into(db.productSalesTable)
              .insertOnConflictUpdate(_mapSupabaseDataToCompanion(data));

          _log.finest(
            'Product sale ${data[SupabaseProductSalesTable.id]} synced from realtime',
          );

        case PostgresChangeEvent.delete:
          final oldData = payload.oldRecord;
          final id = oldData[SupabaseProductSalesTable.id] as String;

          await (db.delete(
            db.productSalesTable,
          )..where((final t) => t.id.equals(id))).go();
          _log.finest('Product sale $id deleted from realtime');

        case PostgresChangeEvent.all:
          throw UnimplementedError('PostgresChangeEvent.all not supported');
      }
    } catch (e, stackTrace) {
      _log.warning('Failed to handle product sale change', e, stackTrace);
    }
  }

  // ========================================================================
  // PRIVATE SYNC HELPERS
  // ========================================================================

  ProductSalesTableCompanion _mapSupabaseDataToCompanion(
    final Map<String, dynamic> data,
  ) => ProductSalesTableCompanion.insert(
    id: Value(data[SupabaseProductSalesTable.id] as String),
    clientId: Value(data[SupabaseProductSalesTable.clientId] as String?),
    productId: data[SupabaseProductSalesTable.productId] as String,
    lockedProductName:
        data[SupabaseProductSalesTable.lockedProductName] as String,
    lockedPrice:
        (data[SupabaseProductSalesTable.lockedPrice] as num?)?.toDouble() ?? 0,
    quantity: Value(data[SupabaseProductSalesTable.quantity] as int? ?? 1),
    lineTotal:
        (data[SupabaseProductSalesTable.lineTotal] as num?)?.toDouble() ?? 0,
    createdAt: Value(
      DateTime.parse(
        data[SupabaseProductSalesTable.createdAt] as String,
      ).toLocal(),
    ),
    isActive: Value(data[SupabaseProductSalesTable.isActive] as bool? ?? true),
  );

  /// Sincronizza forzatamente una vendita prodotto a Supabase
  /// Usato da PaymentsRepository per risolvere dipendenze FK
  Future<void> syncEntityToSupabase(final String id) async {
    try {
      await _syncProductSaleToSupabase(id);
    } catch (e, stackTrace) {
      _log.warning('Failed to sync product sale $id to Supabase', e, stackTrace);
      rethrow; // Rilancia per permettere retry
    }
  }

  Future<void> _syncProductSaleToSupabase(final String id) async {
    try {
      final sale = await getProductSaleById(id);
      if (sale == null) return;

      await supabase?.from(SupabaseSchema.productSales.tableName).upsert({
        SupabaseProductSalesTable.id: sale.id,
        SupabaseProductSalesTable.clientId: sale.clientId,
        SupabaseProductSalesTable.productId: sale.productId,
        SupabaseProductSalesTable.lockedProductName: sale.lockedProductName,
        SupabaseProductSalesTable.lockedPrice: sale.lockedPrice,
        SupabaseProductSalesTable.quantity: sale.quantity,
        SupabaseProductSalesTable.lineTotal: sale.lineTotal,
        SupabaseProductSalesTable.createdAt: sale.createdAt
            .toUtc()
            .toIso8601String(),
        SupabaseProductSalesTable.isActive: sale.isActive,
      });
    } catch (e, stackTrace) {
      _log.warning(
        'Failed to sync product sale $id to Supabase',
        e,
        stackTrace,
      );
    }
  }
}
