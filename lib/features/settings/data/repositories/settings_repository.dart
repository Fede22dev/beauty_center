import 'package:drift/drift.dart';
import 'package:flutter/material.dart' as material;
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../../core/constants/app_constants.dart';
import '../../../../core/database/app_database.dart';
import '../../../../core/database/repositories/base_repository.dart';
import '../../../../core/database/supabase_schema.dart';

/// Repository for settings management (cabins, operators, work hours)
/// Implements offline-first pattern with Supabase sync
class SettingsRepository extends BaseRepository {
  SettingsRepository({
    required super.db,
    required super.supabase,
    required super.isOnline,
  });

  // ========================================================================
  // VALIDATION HELPERS
  // ========================================================================

  void _validateCabinId(final int id) {
    if (id < kMinCabinsCount || id > kMaxCabinsCount) {
      throw ArgumentError(
        'Cabin ID must be between $kMinCabinsCount and $kMaxCabinsCount, got $id',
      );
    }
  }

  void _validateOperatorId(final int id) {
    if (id < kMinOperatorsCount || id > kMaxOperatorsCount) {
      throw ArgumentError(
        'Operator ID must be between $kMinOperatorsCount and $kMaxOperatorsCount, got $id',
      );
    }
  }

  void _validateCabinsCount(final int count) {
    if (count < kMinCabinsCount || count > kMaxCabinsCount) {
      throw ArgumentError(
        'Cabins count must be between $kMinCabinsCount and $kMaxCabinsCount, got $count',
      );
    }
  }

  void _validateOperatorsCount(final int count) {
    if (count < kMinOperatorsCount || count > kMaxOperatorsCount) {
      throw ArgumentError(
        'Operators count must be between $kMinOperatorsCount and $kMaxOperatorsCount, got $count',
      );
    }
  }

  // ========================================================================
  // CABINS - QUERIES (Read operations - always from local DB)
  // ========================================================================

  /// Get all cabins ordered by ID
  Future<List<Cabin>> getAllCabins() => (db.select(
    db.cabinsTable,
  )..orderBy([(final t) => OrderingTerm.asc(t.id)])).get();

  /// Watch cabins stream for reactive UI updates
  Stream<List<Cabin>> watchCabins() => (db.select(
    db.cabinsTable,
  )..orderBy([(final t) => OrderingTerm.asc(t.id)])).watch();

  /// Get cabin by ID
  Future<Cabin?> getCabinById(final int id) {
    _validateCabinId(id);
    return (db.select(
      db.cabinsTable,
    )..where((final t) => t.id.equals(id))).getSingleOrNull();
  }

  /// Get cabins count
  Future<int> getCabinsCount() async => (await getAllCabins()).length;

  // ========================================================================
  // CABINS - CRUD (Write operations - sync with Supabase)
  // ========================================================================

  /// Add new cabin
  Future<int> addCabin({
    required final int id,
    required final material.Color color,
  }) async {
    _validateCabinId(id);

    // Write to local DB first (offline-first)
    final result = await db
        .into(db.cabinsTable)
        .insert(
          CabinsTableCompanion.insert(id: Value(id), color: color.toARGB32()),
        );

    // Non-blocking sync to Supabase
    syncAsync(() => _syncCabinToSupabase(id, color.toARGB32()));

    return result;
  }

  /// Update cabin color
  Future<void> updateCabinColor({
    required final int id,
    required final material.Color color,
  }) async {
    _validateCabinId(id);

    // Update local DB
    await (db.update(db.cabinsTable)..where((final t) => t.id.equals(id)))
        .write(CabinsTableCompanion(color: Value(color.toARGB32())));

    // Sync to Supabase
    syncAsync(() => _syncCabinToSupabase(id, color.toARGB32()));
  }

  /// Delete cabin
  Future<void> deleteCabin(final int id) async {
    _validateCabinId(id);

    // Delete from local DB
    await (db.delete(db.cabinsTable)..where((final t) => t.id.equals(id))).go();

    // Delete from Supabase
    syncAsync(() => _deleteCabinFromSupabase(id));
  }

  /// Set cabins count (add or remove to match target)
  Future<void> setCabinsCount(final int targetCount) async {
    _validateCabinsCount(targetCount);

    final currentCabins = await getAllCabins();
    final currentCount = currentCabins.length;

    if (targetCount > currentCount) {
      // Add new cabins
      final newCabins = <Map<String, dynamic>>[];

      for (var newId = currentCount + 1; newId <= targetCount; newId++) {
        final color =
            kDefaultCabinsColors[newId - 1 % kDefaultCabinsColors.length];

        await db
            .into(db.cabinsTable)
            .insert(
              CabinsTableCompanion.insert(id: Value(newId), color: color),
            );

        newCabins.add({
          SupabaseCabinsTable.id: newId,
          SupabaseCabinsTable.color: color,
        });
      }

      // Batch upsert to Supabase with explicit type
      if (newCabins.isNotEmpty) {
        syncAsync(
          () => batchUpsert(table: SupabaseSchema.cabins, records: newCabins),
        );
      }
    } else if (targetCount < currentCount) {
      // Remove cabins from the end
      final toDeleteIds = currentCabins
          .skip(targetCount)
          .map((final c) => c.id)
          .toList();

      for (final id in toDeleteIds) {
        await (db.delete(
          db.cabinsTable,
        )..where((final t) => t.id.equals(id))).go();
      }

      // Batch delete from Supabase
      syncAsync(
        () => batchDelete(table: SupabaseSchema.cabins, ids: toDeleteIds),
      );
    }
  }

  // ========================================================================
  // OPERATORS - QUERIES
  // ========================================================================

  Future<List<Operator>> getAllOperators() => (db.select(
    db.operatorsTable,
  )..orderBy([(final t) => OrderingTerm.asc(t.id)])).get();

  Stream<List<Operator>> watchOperators() => (db.select(
    db.operatorsTable,
  )..orderBy([(final t) => OrderingTerm.asc(t.id)])).watch();

  Future<Operator?> getOperatorById(final int id) {
    _validateOperatorId(id);
    return (db.select(
      db.operatorsTable,
    )..where((final t) => t.id.equals(id))).getSingleOrNull();
  }

  Future<int> getOperatorsCount() async => (await getAllOperators()).length;

  // ========================================================================
  // OPERATORS - CRUD
  // ========================================================================

  Future<int> addOperator({
    required final int id,
    required final String name,
  }) async {
    _validateOperatorId(id);
    if (name.trim().isEmpty) return 0;

    final result = await db
        .into(db.operatorsTable)
        .insert(OperatorsTableCompanion.insert(id: Value(id), name: name));

    syncAsync(() => _syncOperatorToSupabase(id, name));

    return result;
  }

  Future<void> updateOperatorName({
    required final int id,
    required final String name,
  }) async {
    _validateOperatorId(id);
    if (name.trim().isEmpty) return;

    await (db.update(db.operatorsTable)..where((final t) => t.id.equals(id)))
        .write(OperatorsTableCompanion(name: Value(name)));

    syncAsync(() => _syncOperatorToSupabase(id, name));
  }

  Future<void> deleteOperator(final int id) async {
    _validateOperatorId(id);

    await (db.delete(
      db.operatorsTable,
    )..where((final t) => t.id.equals(id))).go();

    syncAsync(() => _deleteOperatorFromSupabase(id));
  }

  Future<void> setOperatorsCount(final int targetCount) async {
    _validateOperatorsCount(targetCount);

    final currentOperators = await getAllOperators();
    final currentCount = currentOperators.length;

    if (targetCount > currentCount) {
      final newOperators = <Map<String, dynamic>>[];

      for (var newId = currentCount + 1; newId <= targetCount; newId++) {
        final name =
            kDefaultOperatorNames[newId - 1 % kDefaultOperatorNames.length];

        await db
            .into(db.operatorsTable)
            .insert(
              OperatorsTableCompanion.insert(id: Value(newId), name: name),
            );

        newOperators.add({
          SupabaseOperatorsTable.id: newId,
          SupabaseOperatorsTable.name: name,
        });
      }

      if (newOperators.isNotEmpty) {
        syncAsync(
          () => batchUpsert(
            table: SupabaseSchema.operators,
            records: newOperators,
          ),
        );
      }
    } else if (targetCount < currentCount) {
      final toDeleteIds = currentOperators
          .skip(targetCount)
          .map((final o) => o.id)
          .toList();

      for (final id in toDeleteIds) {
        await (db.delete(
          db.operatorsTable,
        )..where((final t) => t.id.equals(id))).go();
      }

      syncAsync(
        () => batchDelete(table: SupabaseSchema.operators, ids: toDeleteIds),
      );
    }
  }

  // ========================================================================
  // WORK HOURS
  // ========================================================================

  Future<WorkHours> getWorkHours() => (db.select(
    db.workHoursTable,
  )..where((final t) => t.id.equals(kIdWorkHours))).getSingle();

  Stream<WorkHours> watchWorkHours() => (db.select(
    db.workHoursTable,
  )..where((final t) => t.id.equals(kIdWorkHours))).watchSingle();

  Future<void> updateWorkHours({
    required final material.TimeOfDay startTime,
    required final material.TimeOfDay endTime,
  }) async {
    await (db.update(
      db.workHoursTable,
    )..where((final t) => t.id.equals(kIdWorkHours))).write(
      WorkHoursTableCompanion(
        startHr: Value(startTime.hour),
        startMin: Value(startTime.minute),
        endHr: Value(endTime.hour),
        endMin: Value(endTime.minute),
      ),
    );

    syncAsync(() => _syncWorkHoursToSupabase(startTime, endTime));
  }

  // ========================================================================
  // SYNC IMPLEMENTATION (BaseRepository overrides)
  // ========================================================================

  @override
  Future<void> pushLocalToSupabase() async {
    if (!isOnline) return;

    try {
      // Check if Supabase tables are empty (first setup scenario)
      final cabinsEmpty = await isSupabaseTableEmpty(SupabaseSchema.cabins);
      final operatorsEmpty = await isSupabaseTableEmpty(
        SupabaseSchema.operators,
      );
      final workHoursEmpty = await isSupabaseTableEmpty(
        SupabaseSchema.workHours,
      );

      // Push local default data only if Supabase is empty
      if (cabinsEmpty) {
        final localCabins = await getAllCabins();
        await batchUpsert(
          table: SupabaseSchema.cabins,
          records: localCabins
              .map(
                (final c) => {
                  SupabaseCabinsTable.id: c.id,
                  SupabaseCabinsTable.color: c.color,
                },
              )
              .toList(),
        );
        log.info('Pushed default ${localCabins.length} cabins to Supabase');
      }

      if (operatorsEmpty) {
        final localOperators = await getAllOperators();
        await batchUpsert(
          table: SupabaseSchema.operators,
          records: localOperators
              .map(
                (final o) => {
                  SupabaseOperatorsTable.id: o.id,
                  SupabaseOperatorsTable.name: o.name,
                },
              )
              .toList(),
        );
        log.info(
          'Pushed default ${localOperators.length} operators to Supabase',
        );
      }

      if (workHoursEmpty) {
        final localWorkHours = await getWorkHours();
        await supabase!.from(SupabaseSchema.workHours.tableName).insert({
          SupabaseWorkHoursTable.id: localWorkHours.id,
          SupabaseWorkHoursTable.startHr: localWorkHours.startHr,
          SupabaseWorkHoursTable.startMin: localWorkHours.startMin,
          SupabaseWorkHoursTable.endHr: localWorkHours.endHr,
          SupabaseWorkHoursTable.endMin: localWorkHours.endMin,
        });
        log.info('Pushed default work hours to Supabase');
      }
    } catch (e, stackTrace) {
      log.warning('Push to Supabase failed', e, stackTrace);
    }
  }

  @override
  Future<void> pullSupabaseToLocal() async {
    if (!isOnline) return;

    try {
      await db.transaction(() async {
        // Pull cabins (Supabase is source of truth)
        final cabinsData = await supabase!
            .from(SupabaseSchema.cabins.tableName)
            .select();
        if (cabinsData.isNotEmpty) {
          await db.delete(db.cabinsTable).go();
          for (final cabin in cabinsData) {
            await db
                .into(db.cabinsTable)
                .insertOnConflictUpdate(
                  CabinsTableCompanion.insert(
                    id: Value(cabin[SupabaseCabinsTable.id] as int),
                    color: cabin[SupabaseCabinsTable.color] as int,
                  ),
                );
          }
          log.info('Pulled ${cabinsData.length} cabins from Supabase');
        }

        // Pull operators
        final operatorsData = await supabase!
            .from(SupabaseSchema.operators.tableName)
            .select();
        if (operatorsData.isNotEmpty) {
          await db.delete(db.operatorsTable).go();
          for (final operator in operatorsData) {
            await db
                .into(db.operatorsTable)
                .insertOnConflictUpdate(
                  OperatorsTableCompanion.insert(
                    id: Value(operator[SupabaseOperatorsTable.id] as int),
                    name: operator[SupabaseOperatorsTable.name] as String,
                  ),
                );
          }
          log.info('Pulled ${operatorsData.length} operators from Supabase');
        }

        // Pull work hours
        final workHoursData = await supabase!
            .from(SupabaseSchema.workHours.tableName)
            .select()
            .eq(SupabaseWorkHoursTable.id, kIdWorkHours)
            .maybeSingle();

        if (workHoursData != null) {
          await db
              .into(db.workHoursTable)
              .insertOnConflictUpdate(
                WorkHoursTableCompanion.insert(
                  id: Value(workHoursData[SupabaseWorkHoursTable.id] as int),
                  startHr: workHoursData[SupabaseWorkHoursTable.startHr] as int,
                  startMin:
                      workHoursData[SupabaseWorkHoursTable.startMin] as int,
                  endHr: workHoursData[SupabaseWorkHoursTable.endHr] as int,
                  endMin: workHoursData[SupabaseWorkHoursTable.endMin] as int,
                ),
              );
          log.info('Pulled work hours from Supabase');
        }
      });
    } catch (e, stackTrace) {
      log.warning('Pull from Supabase failed', e, stackTrace);
    }
  }

  @override
  void startRealtimeSync() {
    if (!isOnline) return;

    // Subscribe to realtime changes
    subscribeToChannel(
      table: SupabaseSchema.cabins,
      onEvent: _handleCabinChange,
    );

    subscribeToChannel(
      table: SupabaseSchema.operators,
      onEvent: _handleOperatorChange,
    );

    subscribeToChannel(
      table: SupabaseSchema.workHours,
      onEvent: _handleWorkHoursChange,
    );

    log.info('Realtime sync started');
  }

  // ========================================================================
  // REALTIME EVENT HANDLERS
  // ========================================================================

  Future<void> _handleCabinChange(final PostgresChangePayload payload) async {
    try {
      switch (payload.eventType) {
        case PostgresChangeEvent.insert:
        case PostgresChangeEvent.update:
          final data = payload.newRecord;
          await db
              .into(db.cabinsTable)
              .insertOnConflictUpdate(
                CabinsTableCompanion.insert(
                  id: Value(data[SupabaseCabinsTable.id] as int),
                  color: data[SupabaseCabinsTable.color] as int,
                ),
              );
          log.fine(
            'Cabin ${data[SupabaseCabinsTable.id]} synced from realtime',
          );

        case PostgresChangeEvent.delete:
          final id = payload.oldRecord[SupabaseCabinsTable.id] as int;
          await (db.delete(
            db.cabinsTable,
          )..where((final t) => t.id.equals(id))).go();
          log.fine('Cabin $id deleted from realtime');

        case PostgresChangeEvent.all:
          throw UnimplementedError('PostgresChangeEvent.all not supported');
      }
    } catch (e, stackTrace) {
      log.warning('Failed to handle cabin change', e, stackTrace);
    }
  }

  Future<void> _handleOperatorChange(
    final PostgresChangePayload payload,
  ) async {
    try {
      switch (payload.eventType) {
        case PostgresChangeEvent.insert:
        case PostgresChangeEvent.update:
          final data = payload.newRecord;
          await db
              .into(db.operatorsTable)
              .insertOnConflictUpdate(
                OperatorsTableCompanion.insert(
                  id: Value(data[SupabaseOperatorsTable.id] as int),
                  name: data[SupabaseOperatorsTable.name] as String,
                ),
              );
          log.fine(
            'Operator ${data[SupabaseOperatorsTable.id]} synced from realtime',
          );

        case PostgresChangeEvent.delete:
          final id = payload.oldRecord[SupabaseOperatorsTable.id] as int;
          await (db.delete(
            db.operatorsTable,
          )..where((final t) => t.id.equals(id))).go();
          log.fine('Operator $id deleted from realtime');

        case PostgresChangeEvent.all:
          throw UnimplementedError('PostgresChangeEvent.all not supported');
      }
    } catch (e, stackTrace) {
      log.warning('Failed to handle operator change', e, stackTrace);
    }
  }

  Future<void> _handleWorkHoursChange(
    final PostgresChangePayload payload,
  ) async {
    try {
      if (payload.eventType == PostgresChangeEvent.update) {
        final data = payload.newRecord;
        await db
            .into(db.workHoursTable)
            .insertOnConflictUpdate(
              WorkHoursTableCompanion.insert(
                id: Value(data[SupabaseWorkHoursTable.id] as int),
                startHr: data[SupabaseWorkHoursTable.startHr] as int,
                startMin: data[SupabaseWorkHoursTable.startMin] as int,
                endHr: data[SupabaseWorkHoursTable.endHr] as int,
                endMin: data[SupabaseWorkHoursTable.endMin] as int,
              ),
            );
        log.fine('Work hours synced from realtime');
      }
    } catch (e, stackTrace) {
      log.warning('Failed to handle work hours change', e, stackTrace);
    }
  }

  // ========================================================================
  // PRIVATE SYNC HELPERS
  // ========================================================================

  Future<void> _syncCabinToSupabase(final int id, final int color) async {
    try {
      await supabase?.from(SupabaseSchema.cabins.tableName).upsert({
        SupabaseCabinsTable.id: id,
        SupabaseCabinsTable.color: color,
      });
    } catch (e, stackTrace) {
      log.warning('Failed to sync cabin $id to Supabase', e, stackTrace);
    }
  }

  Future<void> _deleteCabinFromSupabase(final int id) async {
    try {
      await supabase
          ?.from(SupabaseSchema.cabins.tableName)
          .delete()
          .eq(SupabaseCabinsTable.id, id);
    } catch (e, stackTrace) {
      log.warning('Failed to delete cabin $id from Supabase', e, stackTrace);
    }
  }

  Future<void> _syncOperatorToSupabase(final int id, final String name) async {
    try {
      await supabase?.from(SupabaseSchema.operators.tableName).upsert({
        SupabaseOperatorsTable.id: id,
        SupabaseOperatorsTable.name: name,
      });
    } catch (e, stackTrace) {
      log.warning('Failed to sync operator $id to Supabase', e, stackTrace);
    }
  }

  Future<void> _deleteOperatorFromSupabase(final int id) async {
    try {
      await supabase
          ?.from(SupabaseSchema.operators.tableName)
          .delete()
          .eq(SupabaseOperatorsTable.id, id);
    } catch (e, stackTrace) {
      log.warning('Failed to delete operator $id from Supabase', e, stackTrace);
    }
  }

  Future<void> _syncWorkHoursToSupabase(
    final material.TimeOfDay startTime,
    final material.TimeOfDay endTime,
  ) async {
    try {
      await supabase
          ?.from(SupabaseSchema.workHours.tableName)
          .update({
            SupabaseWorkHoursTable.startHr: startTime.hour,
            SupabaseWorkHoursTable.startMin: startTime.minute,
            SupabaseWorkHoursTable.endHr: endTime.hour,
            SupabaseWorkHoursTable.endMin: endTime.minute,
          })
          .eq(SupabaseWorkHoursTable.id, kIdWorkHours);
    } catch (e, stackTrace) {
      log.warning('Failed to sync work hours to Supabase', e, stackTrace);
    }
  }
}
