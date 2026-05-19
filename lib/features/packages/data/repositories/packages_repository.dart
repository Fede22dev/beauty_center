import 'package:drift/drift.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:uuid/uuid.dart';

import '../../../../core/constants/app_constants.dart';
import '../../../../core/database/app_database.dart';
import '../../../../core/database/repositories/base_repository.dart';
import '../../../../core/database/supabase_schema.dart';
import '../../../../core/logging/app_logger.dart';
import '../../../quotes/data/repositories/quotes_repository.dart';

/// Repository for packages management
/// Implements offline-first pattern with Supabase sync
class PackagesRepository extends BaseRepository {
  PackagesRepository({
    required super.db,
    required super.supabase,
    required super.isOnline,
  });

  static final _log = AppLogger.getLogger(name: 'PackagesRepository');

  List<OrderingTerm Function(PackagesTable)> get _defaultOrdering => [
    (final t) => OrderingTerm.desc(t.createdAt),
  ];

  // ========================================================================
  // PACKAGES - QUERIES (Read operations - always from local DB)
  // ========================================================================

  /// Get all packages ordered by creation date
  Future<List<PackageData>> getAllPackages() =>
      (db.select(db.packagesTable)
            ..where((final t) => t.isActive.equals(true))
            ..orderBy(_defaultOrdering))
          .get();

  /// Watch all packages stream for reactive UI updates
  Stream<List<PackageData>> watchAllPackages() =>
      (db.select(db.packagesTable)
            ..where((final t) => t.isActive.equals(true))
            ..orderBy(_defaultOrdering))
          .watch();

  /// Get packages by client ID
  Future<List<PackageData>> getPackagesByClientId(final String clientId) =>
      (db.select(db.packagesTable)
            ..where(
              (final t) =>
                  t.clientId.equals(clientId) & t.isActive.equals(true),
            )
            ..orderBy(_defaultOrdering))
          .get();

  /// Watch packages by client ID for reactive UI updates
  Stream<List<PackageData>> watchPackagesByClientId(final String clientId) =>
      (db.select(db.packagesTable)
            ..where(
              (final t) =>
                  t.clientId.equals(clientId) & t.isActive.equals(true),
            )
            ..orderBy(_defaultOrdering))
          .watch();

  /// Get active packages by client ID
  Future<List<PackageData>> getActivePackagesByClientId(
    final String clientId,
  ) =>
      (db.select(db.packagesTable)
            ..where(
              (final t) =>
                  t.clientId.equals(clientId) &
                  t.isActive.equals(true) &
                  t.status.equals('active'),
            )
            ..orderBy(_defaultOrdering))
          .get();

  /// Watch active packages by client ID for reactive UI updates
  Stream<List<PackageData>> watchActivePackagesByClientId(
    final String clientId,
  ) =>
      (db.select(db.packagesTable)
            ..where(
              (final t) =>
                  t.clientId.equals(clientId) &
                  t.isActive.equals(true) &
                  t.status.equals('active'),
            )
            ..orderBy(_defaultOrdering))
          .watch();

  /// Get package by ID
  Future<PackageData?> getPackageById(final String id) => (db.select(
    db.packagesTable,
  )..where((final t) => t.id.equals(id))).getSingleOrNull();

  /// Watch package by ID for reactive UI updates
  Stream<PackageData?> watchPackageById(final String id) => (db.select(
    db.packagesTable,
  )..where((final t) => t.id.equals(id))).watchSingleOrNull();

  /// Get package items by package ID
  Future<List<PackageItemData>> getPackageItemsByPackageId(
    final String packageId,
  ) => (db.select(
    db.packageItemsTable,
  )..where((final t) => t.packageId.equals(packageId))).get();

  /// Watch package items by package ID for reactive UI updates
  Stream<List<PackageItemData>> watchPackageItemsByPackageId(
    final String packageId,
  ) => (db.select(
    db.packageItemsTable,
  )..where((final t) => t.packageId.equals(packageId))).watch();

  // ========================================================================
  // PACKAGES - CRUD (Write operations - sync with Supabase)
  // ========================================================================

  /// Create new package with items
  /// Returns package ID or null if offline (read-only mode)
  /// Create new package with items
  /// Returns package ID or null on error
  /// Note: Works offline - sync to Supabase happens in background
  Future<String?> createPackage({
    required final String clientId,
    required final String name,
    required final double totalPrice,
    final String? quoteId,
    final DateTime? expiresAt,
    final String? notes,
    required final List<PackageItemData> items,
  }) async {
    final now = DateTime.now().toUtc();

    return await db.transaction(() async {
      // Insert package
      final insertedPackage = await db
          .into(db.packagesTable)
          .insertReturning(
            PackagesTableCompanion.insert(
              id: Value(const Uuid().v7()),
              clientId: Value(clientId),
              quoteId: Value(quoteId),
              name: name.trim(),
              status: const Value('active'),
              totalPrice: totalPrice,
              paidAmount: const Value(0),
              expiresAt: Value(expiresAt),
              notes: Value(notes?.trim()),
              createdAt: Value(now),
              updatedAt: Value(now),
              isActive: const Value(true),
            ),
          );

      // Insert package items
      for (final item in items) {
        await db
            .into(db.packageItemsTable)
            .insert(
              PackageItemsTableCompanion.insert(
                id: Value(const Uuid().v7()),
                packageId: insertedPackage.id,
                serviceId: item.serviceId,
                lockedServiceName: item.lockedServiceName,
                lockedUnitPrice: item.lockedUnitPrice,
                totalSessions: item.totalSessions,
                usedSessions: const Value(0),
              ),
            );
      }

      _log.info('Package ${insertedPackage.id} created locally, scheduling sync...');
      
      // Esegui sync in background con retry robusto
      await _triggerSyncWithDebounce(insertedPackage.id);

      return insertedPackage.id;
    });
  }

  /// Update package status
  /// Returns true if successful, false if offline (read-only mode)
  Future<bool> updatePackageStatus({
    required final String id,
    required final String status,
  }) async {
    if (!isOnline) {
      _log.warning('Cannot update package status: offline mode (read-only)');
      return false;
    }

    final companion = PackagesTableCompanion(
      status: Value(status),
      updatedAt: Value(DateTime.now().toUtc()),
    );

    await (db.update(
      db.packagesTable,
    )..where((final t) => t.id.equals(id))).write(companion);

    syncAsync('package_$id', () => _syncPackageToSupabase(id));
    return true;
  }

  /// Update package paid amount
  Future<void> updatePackagePaidAmount({
    required final String id,
    required final double paidAmount,
  }) async {
    final companion = PackagesTableCompanion(
      paidAmount: Value(paidAmount),
      updatedAt: Value(DateTime.now().toUtc()),
    );

    await (db.update(
      db.packagesTable,
    )..where((final t) => t.id.equals(id))).write(companion);

    syncAsync('package_$id', () => _syncPackageToSupabase(id));
  }

  /// Increment used sessions for a package item
  Future<void> incrementUsedSessions(final String packageItemId) async {
    final currentItem = await (db.select(
      db.packageItemsTable,
    )..where((final t) => t.id.equals(packageItemId))).getSingleOrNull();

    if (currentItem == null) return;

    final companion = PackageItemsTableCompanion(
      usedSessions: Value(currentItem.usedSessions + 1),
    );

    await (db.update(
      db.packageItemsTable,
    )..where((final t) => t.id.equals(packageItemId))).write(companion);

    // Sync parent package
    syncAsync(
      'package_${currentItem.packageId}',
      () => _syncPackageToSupabase(currentItem.packageId),
    );
  }

  /// Decrement used sessions for a package item (for appointment cancellation)
  Future<void> decrementUsedSessions(final String packageItemId) async {
    final currentItem = await (db.select(
      db.packageItemsTable,
    )..where((final t) => t.id.equals(packageItemId))).getSingleOrNull();

    if (currentItem == null || currentItem.usedSessions <= 0) return;

    final companion = PackageItemsTableCompanion(
      usedSessions: Value(currentItem.usedSessions - 1),
    );

    await (db.update(
      db.packageItemsTable,
    )..where((final t) => t.id.equals(packageItemId))).write(companion);

    // Sync parent package
    syncAsync(
      'package_${currentItem.packageId}',
      () => _syncPackageToSupabase(currentItem.packageId),
    );
  }

  /// Soft delete package
  /// Returns true if successful, false if offline (read-only mode)
  Future<bool> deletePackage(final String id) async {
    if (!isOnline) {
      _log.warning('Cannot delete package: offline mode (read-only)');
      return false;
    }

    final companion = PackagesTableCompanion(
      isActive: const Value(false),
      updatedAt: Value(DateTime.now().toUtc()),
    );

    await (db.update(
      db.packagesTable,
    )..where((final t) => t.id.equals(id))).write(companion);

    syncAsync('package_$id', () => _syncPackageToSupabase(id));
    return true;
  }

  // ========================================================================
  // SYNC IMPLEMENTATION (BaseRepository overrides)
  // ========================================================================

  // ========================================================================
  // SYNC HELPER - Robust sync with retry
  // ========================================================================

  /// Trigger sync con debounce e retry robusto
  Future<void> _triggerSyncWithDebounce(final String packageId) async {
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

        _log.finest('Sync attempt $attempt/$maxAttempts for package $packageId');
        await _syncPackageToSupabase(packageId);
        
        _log.info('Package $packageId synced successfully on attempt $attempt');
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

    _log.warning('Package $packageId failed to sync after $maxAttempts attempts');
  }

  // ========================================================================
  // SYNC IMPLEMENTATION (BaseRepository overrides)
  // ========================================================================

  @override
  Future<void> pullSupabaseToLocal() async {
    // CRITICAL: Verifica che supabase sia disponibile
    if (supabase == null) {
      _log.warning('Cannot pull packages: Supabase client is null');
      return;
    }

    try {
      final lastSync = await getLastSyncTime(kLastSyncTimePackagesKey);

      var query = supabase?.from(SupabaseSchema.packages.tableName).select();
      if (query == null) {
        _log.warning('Cannot pull packages: Supabase client is null');
        return;
      }

      if (lastSync != null) {
        final adjustedTime = lastSync.subtract(kLastSyncBufferDuration);
        query = query.gt(
          SupabasePackagesTable.updatedAt,
          adjustedTime.toIso8601String(),
        );
      }

      final updatesData = await query;

      final allRemoteIdsData = await supabase
          ?.from(SupabaseSchema.packages.tableName)
          .select(SupabasePackagesTable.id) ?? [];

      final remoteIds = List<Map<String, dynamic>>.from(
        allRemoteIdsData,
      ).map((final e) => e[SupabasePackagesTable.id] as String).toSet();

      await db.transaction(() async {
        if (updatesData.isNotEmpty) {
          await db.batch((final batch) {
            final companions = updatesData.map(_mapSupabaseDataToCompanion);
            batch.insertAllOnConflictUpdate(db.packagesTable, companions);
          });
          _log.info('Synced ${updatesData.length} updated/new packages.');
        }

        // CRITICAL: Non cancellare record creati dopo l'ultimo sync (local-only)
        if (remoteIds.isNotEmpty) {
          final lastSyncThreshold = lastSync ?? DateTime(2000).toUtc();
          await (db.delete(db.packagesTable)..where(
                (final t) =>
                    t.id.isNotIn(remoteIds) &
                    t.createdAt.isSmallerThan(Variable(lastSyncThreshold)),
              )).go();
        } else if (updatesData.isEmpty && lastSync != null) {
          // Solo se c'è stato almeno un sync prima
          await (db.delete(db.packagesTable)
            ..where((final t) => t.createdAt.isSmallerThan(Variable(lastSync!)))).go();
        }

        // Sync Package Items
        await _pullPackageItems();
      });

      await updateLastSyncTime(kLastSyncTimePackagesKey);
    } catch (e, stackTrace) {
      _log.warning('Pull from Supabase failed', e, stackTrace);
    }
  }

  @override
  void startRealtimeSync() {
    if (!isOnline) return;

    subscribeToChannel(
      table: SupabaseSchema.packages,
      onEvent: _handlePackageChange,
    );

    subscribeToChannel(
      table: SupabaseSchema.packageItems,
      onEvent: _handlePackageItemChange,
    );

    _log.info('Realtime sync started for packages and items');
  }

  // ========================================================================
  // REALTIME EVENT HANDLER
  // ========================================================================

  Future<void> _handlePackageChange(final PostgresChangePayload payload) async {
    try {
      switch (payload.eventType) {
        case PostgresChangeEvent.insert:
        case PostgresChangeEvent.update:
          final data = payload.newRecord;

          await db
              .into(db.packagesTable)
              .insertOnConflictUpdate(_mapSupabaseDataToCompanion(data));

          _log.finest(
            'Package ${data[SupabasePackagesTable.id]} synced from realtime',
          );

        case PostgresChangeEvent.delete:
          final oldData = payload.oldRecord;
          final id = oldData[SupabasePackagesTable.id] as String;

          await (db.delete(
            db.packagesTable,
          )..where((final t) => t.id.equals(id))).go();
          _log.finest('Package $id deleted from realtime');

        case PostgresChangeEvent.all:
          throw UnimplementedError('PostgresChangeEvent.all not supported');
      }
    } catch (e, stackTrace) {
      _log.warning('Failed to handle package change', e, stackTrace);
    }
  }

  // ========================================================================
  // PRIVATE SYNC HELPERS
  // ========================================================================

  PackagesTableCompanion _mapSupabaseDataToCompanion(
    final Map<String, dynamic> data,
  ) => PackagesTableCompanion.insert(
    id: Value(data[SupabasePackagesTable.id] as String),
    clientId: Value(data[SupabasePackagesTable.clientId] as String?),
    quoteId: Value(data[SupabasePackagesTable.quoteId] as String?),
    name: data[SupabasePackagesTable.name] as String,
    status: Value(data[SupabasePackagesTable.status] as String? ?? 'active'),
    totalPrice:
        (data[SupabasePackagesTable.totalPrice] as num?)?.toDouble() ?? 0,
    paidAmount: Value(
      (data[SupabasePackagesTable.paidAmount] as num?)?.toDouble() ?? 0,
    ),
    expiresAt: data[SupabasePackagesTable.expiresAt] != null
        ? Value(
            DateTime.parse(
              data[SupabasePackagesTable.expiresAt] as String,
            ).toLocal(),
          )
        : const Value.absent(),
    notes: Value(data[SupabasePackagesTable.notes] as String?),
    createdAt: Value(
      DateTime.parse(data[SupabasePackagesTable.createdAt] as String).toLocal(),
    ),
    updatedAt: Value(
      DateTime.parse(data[SupabasePackagesTable.updatedAt] as String).toLocal(),
    ),
    isActive: Value(data[SupabasePackagesTable.isActive] as bool? ?? true),
  );

  /// Sincronizza forzatamente un pacchetto a Supabase
  /// Usato da PaymentsRepository per risolvere dipendenze FK
  Future<void> syncEntityToSupabase(final String id) async {
    try {
      // Sync pacchetto principale
      await _syncPackageToSupabase(id);
      
      // Sync anche gli items del pacchetto (indipendente dal successo del pacchetto)
      try {
        await _syncPackageItemsToSupabase(id);
      } catch (itemsError) {
        _log.warning('Failed to sync items for package $id', itemsError);
        // Non rilanciare - il pacchetto principale è già stato sincronizzato
      }
    } catch (e, stackTrace) {
      _log.warning('Failed to sync package $id to Supabase', e, stackTrace);
      throw e; // Rilancia per permettere retry
    }
  }

  Future<void> _syncPackageToSupabase(final String id, {int retryCount = 0}) async {
    const maxRetries = 3;

    final package = await getPackageById(id);
    if (package == null) return;

    try {
      await supabase?.from(SupabaseSchema.packages.tableName).upsert({
        SupabasePackagesTable.id: package.id,
        SupabasePackagesTable.clientId: package.clientId,
        SupabasePackagesTable.quoteId: package.quoteId,
        SupabasePackagesTable.name: package.name,
        SupabasePackagesTable.status: package.status,
        SupabasePackagesTable.totalPrice: package.totalPrice,
        SupabasePackagesTable.paidAmount: package.paidAmount,
        SupabasePackagesTable.expiresAt: package.expiresAt
            ?.toUtc()
            .toIso8601String(),
        SupabasePackagesTable.notes: package.notes,
        SupabasePackagesTable.createdAt: package.createdAt
            .toUtc()
            .toIso8601String(),
        SupabasePackagesTable.updatedAt: package.updatedAt
            .toUtc()
            .toIso8601String(),
        SupabasePackagesTable.isActive: package.isActive,
      });
    } on PostgrestException catch (e, stackTrace) {
      // CRITICAL: Gestione errore Foreign Key verso quotes
      if (e.code == '23503' && retryCount < maxRetries && package.quoteId != null) {
        _log.warning(
          'FK constraint failed for package $id (quote ${package.quoteId}), attempting to sync parent quote first (retry ${retryCount + 1}/$maxRetries)',
          e,
        );

        try {
          // Sincronizza il preventivo prima di riprovare
          final quotesRepo = QuotesRepository(
            db: db,
            supabase: supabase,
            isOnline: isOnline,
          );
          await quotesRepo.syncEntityToSupabase(package.quoteId!);
          _log.info('Synced parent quote ${package.quoteId} before package $id');

          // Attendi un momento per permettere a Supabase di processare
          await Future.delayed(Duration(seconds: retryCount + 1));

          // Riprova la sync del pacchetto
          return await _syncPackageToSupabase(id, retryCount: retryCount + 1);
        } catch (quoteError) {
          _log.warning('Failed to sync parent quote for package $id', quoteError);
        }
      }

      _log.warning('Failed to sync package $id to Supabase', e, stackTrace);
      rethrow; // Rilancia per permettere retry dal chiamante
    } catch (e, stackTrace) {
      _log.warning('Failed to sync package $id to Supabase', e, stackTrace);
      rethrow;
    }
  }

  /// Sincronizza gli items di un pacchetto specifico a Supabase
  Future<void> _syncPackageItemsToSupabase(final String packageId, {int retryCount = 0}) async {
    const maxRetries = 3;

    try {
      final items = await getPackageItemsByPackageId(packageId);

      for (final item in items) {
        await supabase?.from(SupabaseSchema.packageItems.tableName).upsert({
          SupabasePackageItemsTable.id: item.id,
          SupabasePackageItemsTable.packageId: item.packageId,
          SupabasePackageItemsTable.serviceId: item.serviceId,
          SupabasePackageItemsTable.lockedServiceName: item.lockedServiceName,
          SupabasePackageItemsTable.lockedUnitPrice: item.lockedUnitPrice,
          SupabasePackageItemsTable.totalSessions: item.totalSessions,
          SupabasePackageItemsTable.usedSessions: item.usedSessions,
        });
      }

      _log.finest('Synced ${items.length} items for package $packageId');
    } on PostgrestException catch (e, stackTrace) {
      // CRITICAL: Gestione errore Foreign Key verso packages
      // Se il pacchetto non esiste ancora su Supabase, attendiamo e riproviamo
      if (e.code == '23503' && retryCount < maxRetries) {
        _log.warning(
          'FK constraint failed for package items (package $packageId not found), waiting and retrying (${retryCount + 1}/$maxRetries)',
          e,
        );

        // Attendi un momento per permettere al pacchetto di essere sincronizzato
        await Future.delayed(Duration(seconds: retryCount + 2));

        // Riprova la sync degli items
        return await _syncPackageItemsToSupabase(packageId, retryCount: retryCount + 1);
      }

      _log.warning('Failed to sync package items for $packageId', e, stackTrace);
    } catch (e, stackTrace) {
      _log.warning('Failed to sync package items for $packageId', e, stackTrace);
    }
  }

  // ========================================================================
  // PACKAGE ITEMS PULL SYNC
  // ========================================================================

  Future<void> _pullPackageItems() async {
    try {
      final lastSync = await getLastSyncTime(kLastSyncTimePackageItemsKey);

      var query = supabase?.from(SupabaseSchema.packageItems.tableName).select();
      if (query == null) {
        _log.warning('Cannot pull package items: Supabase client is null');
        return;
      }

      // Note: package_items doesn't have updated_at, so we pull all data every time
      // This is acceptable as package_items are relatively small in number
      final updatesData = await query;

      final allRemoteIdsData = await supabase
          ?.from(SupabaseSchema.packageItems.tableName)
          .select(SupabasePackageItemsTable.id) ?? [];

      final remoteIds = List<Map<String, dynamic>>.from(
        allRemoteIdsData,
      ).map((final e) => e[SupabasePackageItemsTable.id] as String).toSet();

      if (updatesData.isNotEmpty) {
        await db.batch((final batch) {
          final companions = updatesData.map(_mapPackageItemToCompanion);
          batch.insertAllOnConflictUpdate(db.packageItemsTable, companions);
        });
        _log.info('Synced ${updatesData.length} updated/new package items.');
      }

      if (remoteIds.isNotEmpty) {
        await (db.delete(
          db.packageItemsTable,
        )..where((final t) => t.id.isNotIn(remoteIds))).go();
      } else if (updatesData.isEmpty) {
        await db.delete(db.packageItemsTable).go();
      }

      await updateLastSyncTime(kLastSyncTimePackageItemsKey);
    } catch (e, stackTrace) {
      _log.warning('Failed to pull package items', e, stackTrace);
    }
  }

  PackageItemsTableCompanion _mapPackageItemToCompanion(
    final Map<String, dynamic> data,
  ) => PackageItemsTableCompanion.insert(
    id: Value(data[SupabasePackageItemsTable.id] as String),
    packageId: data[SupabasePackageItemsTable.packageId] as String,
    serviceId: data[SupabasePackageItemsTable.serviceId] as String,
    lockedServiceName:
        data[SupabasePackageItemsTable.lockedServiceName] as String,
    lockedUnitPrice:
        (data[SupabasePackageItemsTable.lockedUnitPrice] as num?)?.toDouble() ??
        0,
    totalSessions: data[SupabasePackageItemsTable.totalSessions] as int,
    usedSessions: Value(
      data[SupabasePackageItemsTable.usedSessions] as int? ?? 0,
    ),
  );

  // ========================================================================
  // PACKAGE ITEMS REALTIME HANDLER
  // ========================================================================

  Future<void> _handlePackageItemChange(
    final PostgresChangePayload payload,
  ) async {
    try {
      switch (payload.eventType) {
        case PostgresChangeEvent.insert:
        case PostgresChangeEvent.update:
          final data = payload.newRecord;
          await db
              .into(db.packageItemsTable)
              .insertOnConflictUpdate(_mapPackageItemToCompanion(data));
          _log.finest(
            'Package item ${data[SupabasePackageItemsTable.id]} synced from realtime',
          );

        case PostgresChangeEvent.delete:
          final oldData = payload.oldRecord;
          final id = oldData[SupabasePackageItemsTable.id] as String;
          await (db.delete(
            db.packageItemsTable,
          )..where((final t) => t.id.equals(id))).go();
          _log.finest('Package item $id deleted from realtime');

        case PostgresChangeEvent.all:
          throw UnimplementedError('PostgresChangeEvent.all not supported');
      }
    } catch (e, stackTrace) {
      _log.warning('Failed to handle package item change', e, stackTrace);
    }
  }
}
