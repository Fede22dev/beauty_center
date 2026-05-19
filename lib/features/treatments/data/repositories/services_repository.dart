import 'package:drift/drift.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:uuid/uuid.dart';

import '../../../../core/constants/app_constants.dart';
import '../../../../core/database/app_database.dart';
import '../../../../core/database/repositories/base_repository.dart';
import '../../../../core/database/supabase_schema.dart';
import '../../../../core/logging/app_logger.dart';

/// Repository for services (treatments catalog) management
/// Implements offline-first pattern with Supabase sync
class ServicesRepository extends BaseRepository {
  ServicesRepository({
    required super.db,
    required super.supabase,
    required super.isOnline,
  });

  static final _log = AppLogger.getLogger(name: 'ServicesRepository');

  List<OrderingTerm Function(ServicesTable)> get _defaultOrdering => [
    (final t) => OrderingTerm.asc(t.name),
  ];

  // ========================================================================
  // SERVICES - QUERIES (Read operations - always from local DB)
  // ========================================================================

  /// Get all active services ordered by name
  Future<List<ServiceData>> getAllActiveServices() =>
      (db.select(db.servicesTable)
            ..where((final t) => t.isActive.equals(true))
            ..orderBy(_defaultOrdering))
          .get();

  /// Watch all active services stream for reactive UI updates
  Stream<List<ServiceData>> watchAllActiveServices() =>
      (db.select(db.servicesTable)
            ..where((final t) => t.isActive.equals(true))
            ..orderBy(_defaultOrdering))
          .watch();

  /// Get service by ID
  Future<ServiceData?> getServiceById(final String id) => (db.select(
    db.servicesTable,
  )..where((final t) => t.id.equals(id))).getSingleOrNull();

  /// Watch service by ID for reactive UI updates
  Stream<ServiceData?> watchServiceById(final String id) => (db.select(
    db.servicesTable,
  )..where((final t) => t.id.equals(id))).watchSingleOrNull();

  /// Search services by name or description
  Future<List<ServiceData>> searchServices(final String query) {
    final searchTerm = '%${query.trim().toLowerCase()}%';
    return (db.select(db.servicesTable)
          ..where(
            (final t) =>
                t.isActive.equals(true) &
                (t.name.lower().like(searchTerm) |
                    t.description.lower().like(searchTerm)),
          )
          ..orderBy(_defaultOrdering))
        .get();
  }

  /// Get total active services count
  Future<int> getActiveServicesCount() async {
    final countExp = db.servicesTable.id.count();
    final query = db.selectOnly(db.servicesTable)
      ..addColumns([countExp])
      ..where(db.servicesTable.isActive.equals(true));
    return await query.map((final row) => row.read(countExp)).getSingle() ?? 0;
  }

  // ========================================================================
  // SERVICES - CRUD (Write operations - sync with Supabase)
  // ========================================================================

  /// Create new service
  /// Returns service ID or null if offline (read-only mode)
  Future<String?> createService({
    required final String name,
    required final double price,
    final int durationMinutes = 30,
    final String? description,
  }) async {
    if (!isOnline) {
      _log.warning('Cannot create service: offline mode (read-only)');
      return null;
    }

    final now = DateTime.now().toUtc();

    final insertedService = await db
        .into(db.servicesTable)
        .insertReturning(
          ServicesTableCompanion.insert(
            id: Value(const Uuid().v7()),
            name: name.trim(),
            price: Value(price),
            durationMinutes: Value(durationMinutes),
            description: Value(description?.trim()),
            createdAt: Value(now),
            updatedAt: Value(now),
            isActive: const Value(true),
          ),
        );

    syncAsync(
      'service_${insertedService.id}',
      () => _syncServiceToSupabase(insertedService.id),
    );

    return insertedService.id;
  }

  /// Update service information
  /// Returns true if successful, false if offline (read-only mode)
  Future<bool> updateService({
    required final String id,
    required final String name,
    required final double price,
    required final int durationMinutes,
    final String? description,
  }) async {
    if (!isOnline) {
      _log.warning('Cannot update service: offline mode (read-only)');
      return false;
    }

    final companion = ServicesTableCompanion(
      name: Value(name.trim()),
      price: Value(price),
      durationMinutes: Value(durationMinutes),
      description: Value(description?.trim()),
      updatedAt: Value(DateTime.now().toUtc()),
    );

    await (db.update(
      db.servicesTable,
    )..where((final t) => t.id.equals(id))).write(companion);

    syncAsync('service_$id', () => _syncServiceToSupabase(id));
    return true;
  }

  /// Soft delete service
  /// Returns true if successful, false if offline (read-only mode)
  Future<bool> deleteService(final String id) async {
    if (!isOnline) {
      _log.warning('Cannot delete service: offline mode (read-only)');
      return false;
    }

    final companion = ServicesTableCompanion(
      isActive: const Value(false),
      updatedAt: Value(DateTime.now().toUtc()),
    );

    await (db.update(
      db.servicesTable,
    )..where((final t) => t.id.equals(id))).write(companion);

    syncAsync('service_$id', () => _syncServiceToSupabase(id));

    return true;
  }

  // ========================================================================
  // SYNC IMPLEMENTATION (BaseRepository overrides)
  // ========================================================================

  @override
  Future<void> pullSupabaseToLocal() async {
    if (!isOnline) return;

    try {
      final lastSync = await getLastSyncTime(kLastSyncTimeServicesKey);

      var query = supabase!.from(SupabaseSchema.services.tableName).select();

      if (lastSync != null) {
        final adjustedTime = lastSync.subtract(kLastSyncBufferDuration);
        query = query.gt(
          SupabaseServicesTable.updatedAt,
          adjustedTime.toIso8601String(),
        );
      }

      final updatesData = await query;

      final allRemoteIdsData = await supabase!
          .from(SupabaseSchema.services.tableName)
          .select(SupabaseServicesTable.id);

      final remoteIds = List<Map<String, dynamic>>.from(
        allRemoteIdsData,
      ).map((final e) => e[SupabaseServicesTable.id] as String).toSet();

      await db.transaction(() async {
        if (updatesData.isNotEmpty) {
          await db.batch((final batch) {
            final companions = updatesData.map(_mapSupabaseDataToCompanion);
            batch.insertAllOnConflictUpdate(db.servicesTable, companions);
          });
          _log.info('Synced ${updatesData.length} updated/new services.');
        }

        if (remoteIds.isNotEmpty) {
          await (db.delete(
            db.servicesTable,
          )..where((final t) => t.id.isNotIn(remoteIds))).go();
        } else if (updatesData.isEmpty) {
          await db.delete(db.servicesTable).go();
        }
      });

      await updateLastSyncTime(kLastSyncTimeServicesKey);
    } catch (e, stackTrace) {
      _log.warning('Pull from Supabase failed', e, stackTrace);
    }
  }

  @override
  void startRealtimeSync() {
    if (!isOnline) return;

    subscribeToChannel(
      table: SupabaseSchema.services,
      onEvent: _handleServiceChange,
    );

    _log.info('Realtime sync started for services');
  }

  // ========================================================================
  // REALTIME EVENT HANDLER
  // ========================================================================

  Future<void> _handleServiceChange(final PostgresChangePayload payload) async {
    try {
      switch (payload.eventType) {
        case PostgresChangeEvent.insert:
        case PostgresChangeEvent.update:
          final data = payload.newRecord;

          await db
              .into(db.servicesTable)
              .insertOnConflictUpdate(_mapSupabaseDataToCompanion(data));

          _log.finest(
            'Service ${data[SupabaseServicesTable.id]} synced from realtime',
          );

        case PostgresChangeEvent.delete:
          final oldData = payload.oldRecord;
          final id = oldData[SupabaseServicesTable.id] as String;

          await (db.delete(
            db.servicesTable,
          )..where((final t) => t.id.equals(id))).go();
          _log.finest('Service $id deleted from realtime');

        case PostgresChangeEvent.all:
          throw UnimplementedError('PostgresChangeEvent.all not supported');
      }
    } catch (e, stackTrace) {
      _log.warning('Failed to handle service change', e, stackTrace);
    }
  }

  // ========================================================================
  // PRIVATE SYNC HELPERS
  // ========================================================================

  ServicesTableCompanion _mapSupabaseDataToCompanion(
    final Map<String, dynamic> data,
  ) => ServicesTableCompanion.insert(
    id: Value(data[SupabaseServicesTable.id] as String),
    name: data[SupabaseServicesTable.name] as String,
    durationMinutes: Value(
      data[SupabaseServicesTable.durationMinutes] as int? ?? 30,
    ),
    price: Value((data[SupabaseServicesTable.price] as num?)?.toDouble() ?? 0),
    description: Value(data[SupabaseServicesTable.description] as String?),
    createdAt: Value(
      DateTime.parse(data[SupabaseServicesTable.createdAt] as String).toLocal(),
    ),
    updatedAt: Value(
      DateTime.parse(data[SupabaseServicesTable.updatedAt] as String).toLocal(),
    ),
    isActive: Value(data[SupabaseServicesTable.isActive] as bool? ?? true),
  );

  Future<void> _syncServiceToSupabase(final String id) async {
    try {
      final service = await getServiceById(id);
      if (service == null) return;

      await supabase?.from(SupabaseSchema.services.tableName).upsert({
        SupabaseServicesTable.id: service.id,
        SupabaseServicesTable.name: service.name,
        SupabaseServicesTable.durationMinutes: service.durationMinutes,
        SupabaseServicesTable.price: service.price,
        SupabaseServicesTable.description: service.description,
        SupabaseServicesTable.createdAt: service.createdAt
            .toUtc()
            .toIso8601String(),
        SupabaseServicesTable.updatedAt: service.updatedAt
            .toUtc()
            .toIso8601String(),
        SupabaseServicesTable.isActive: service.isActive,
      });
    } catch (e, stackTrace) {
      _log.warning('Failed to sync service $id to Supabase', e, stackTrace);
    }
  }
}
