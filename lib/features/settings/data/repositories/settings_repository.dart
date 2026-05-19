import 'package:drift/drift.dart';
import 'package:flutter/material.dart' as material;
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../../core/constants/app_constants.dart';
import '../../../../core/database/app_database.dart';
import '../../../../core/database/repositories/base_repository.dart';
import '../../../../core/database/supabase_schema.dart';
import '../../../../core/logging/app_logger.dart';

/// Repository for settings management (cabins, operators, work hours)
/// Implements offline-first pattern with Supabase sync
class SettingsRepository extends BaseRepository {
  SettingsRepository({
    required super.db,
    required super.supabase,
    required super.isOnline,
  });

  static final _log = AppLogger.getLogger(name: 'SettingsRepository');

  // ========================================================================
  // CABINS - QUERIES (Read operations - always from local DB)
  // ========================================================================

  /// Watch active cabins stream for reactive UI updates
  Stream<List<Cabin>> watchAllActiveCabins() =>
      (db.select(db.cabinsTable)
            ..where((t) => t.isActive.equals(true))
            ..orderBy([(final t) => OrderingTerm.asc(t.id)]))
          .watch();

  /// Watch cabins count stream for reactive UI updates
  Stream<int> watchAllCabinsCount() {
    final query = db.selectOnly(db.cabinsTable)
      ..addColumns([db.cabinsTable.id.count()]);

    return query
        .map((row) => row.read(db.cabinsTable.id.count()) ?? 0)
        .watchSingle();
  }

  /// Get count of all cabins
  Future<int> getAllCabinsCount() {
    final query = db.selectOnly(db.cabinsTable)
      ..addColumns([db.cabinsTable.id.count()]);

    return query.map((row) => row.read(db.cabinsTable.id.count())!).getSingle();
  }

  // ========================================================================
  // CABINS - CRUD (Write operations - sync with Supabase)
  // ========================================================================

  /// Update cabin color
  /// Returns true if successful, false if offline (read-only mode)
  Future<bool> updateCabinColor({
    required final int id,
    required final material.Color color,
  }) async {
    if (!isOnline) {
      _log.warning('Cannot update cabin color: offline mode (read-only)');
      return false;
    }

    // Update local DB
    final cabin =
        await (db.update(
          db.cabinsTable,
        )..where((final t) => t.id.equals(id))).writeReturning(
          CabinsTableCompanion(color: Value(color.toARGB32())),
        );

    // Sync to Supabase
    syncAsync('cabin_${cabin.first.id}', () => _syncCabinColorToSupabase(cabin.first));
    return true;
  }

  /// Set cabins count (add or remove to match target)
  /// Returns true if successful, false if offline (read-only mode)
  Future<bool> setCabinsCount(final int targetCount) async {
    if (!isOnline) {
      _log.warning('Cannot set cabins count: offline mode (read-only)');
      return false;
    }

    final maxCabinsCount = await getAllCabinsCount();

    if (targetCount < 0 || targetCount > maxCabinsCount) {
      throw Exception(
        'Il numero di cabine deve essere tra 0 e $maxCabinsCount',
      );
    }

    // 1. Aggiorna DB LOCALE (Drift) - Attiva
    await (db.update(db.cabinsTable)
          ..where((t) => t.id.isSmallerOrEqualValue(targetCount)))
        .write(const CabinsTableCompanion(isActive: Value(true)));

    // 2. Aggiorna DB LOCALE (Drift) - Disattiva
    await (db.update(db.cabinsTable)
          ..where((t) => t.id.isBiggerThanValue(targetCount)))
        .write(const CabinsTableCompanion(isActive: Value(false)));

    // 3. Lancia il Sync verso Supabase passando solo il targetCount (il pivot)
    syncAsync('cabins_activation_$targetCount', () => _syncCabinsActivationToSupabase(targetCount));
    return true;
  }

  // ========================================================================
  // OPERATORS - QUERIES
  // ========================================================================

  Stream<List<Operator>> watchAllActiveOperators() =>
      (db.select(db.operatorsTable)
            ..where((t) => t.isActive.equals(true))
            ..orderBy([(final t) => OrderingTerm.asc(t.id)]))
          .watch();

  Stream<int> watchAllOperatorsCount() {
    final query = db.selectOnly(db.operatorsTable)
      ..addColumns([db.operatorsTable.id.count()]);

    return query
        .map((row) => row.read(db.operatorsTable.id.count()) ?? 0)
        .watchSingle();
  }

  // ========================================================================
  // OPERATORS - CRUD
  // ========================================================================

  /// Aggiunge un nuovo operatore (Trova il primo inattivo e lo riattiva)
  /// Returns true if successful, false if offline (read-only mode)
  Future<bool> addOperator() async {
    if (!isOnline) {
      _log.warning('Cannot add operator: offline mode (read-only)');
      return false;
    }

    // Cerca il primo operatore libero (inattivo) ordinato per ID
    final inactiveOperator =
        await (db.select(db.operatorsTable)
              ..where((t) => t.isActive.equals(false))
              ..orderBy([(t) => OrderingTerm.asc(t.id)])
              ..limit(1))
            .getSingleOrNull();

    // Se non ci sono operatori inattivi, abbiamo raggiunto il limite di Supabase
    if (inactiveOperator == null) {
      throw Exception(
        'Numero massimo di operatori raggiunto. Aggiungi righe nel Cloud.',
      );
    }

    // Aggiorna DB LOCALE: lo riattiva mantenendo il nome attuale
    final operator =
        await (db.update(
          db.operatorsTable,
        )..where((t) => t.id.equals(inactiveOperator.id))).writeReturning(
          const OperatorsTableCompanion(isActive: Value(true)),
        );

    // Sync verso Supabase (Sincronizza solo l'attivazione)
    syncAsync('operator_${operator.first.id}', () => _syncOperatorActivationToSupabase(operator.first));
    return true;
  }

  Future<void> updateOperatorName({
    required final int id,
    required final String name,
  }) async {
    if (name.trim().isEmpty) {
      throw ArgumentError('Il nome operatore non può essere vuoto');
    }

    final operator =
        await (db.update(db.operatorsTable)
              ..where((final t) => t.id.equals(id)))
            .writeReturning(OperatorsTableCompanion(name: Value(name)));

    syncAsync('operator_name_${operator.first.id}', () => _syncOperatorNameToSupabase(operator.first));
  }

  /// Elimina un operatore (Soft Delete: isActive = false)
  /// Returns true if successful, false if offline (read-only mode)
  Future<bool> deleteOperator(final int id) async {
    if (!isOnline) {
      _log.warning('Cannot delete operator: offline mode (read-only)');
      return false;
    }

    final operator =
        await (db.update(
          db.operatorsTable,
        )..where((final t) => t.id.equals(id))).writeReturning(
          const OperatorsTableCompanion(isActive: Value(false)),
        );

    syncAsync('delete_operator_${operator.first.id}', () => _syncOperatorDeletionToSupabase(operator.first));
    return true;
  }

  // ========================================================================
  // WORK HOURS
  // ========================================================================

  Future<WorkHours> getWorkHours() => (db.select(
    db.workHoursTable,
  )..where((final t) => t.id.equals(kIdWorkHours))).getSingle();

  Stream<WorkHours?> watchWorkHours() => (db.select(
    db.workHoursTable,
  )..where((final t) => t.id.equals(kIdWorkHours))).watchSingleOrNull();

  /// Ensures default work hours exist in local DB (called at app startup)
  /// This is needed when user is not logged in or offline
  Future<void> ensureDefaultWorkHours() async {
    try {
      final existing = await (db.select(db.workHoursTable)
            ..where((t) => t.id.equals(kIdWorkHours)))
          .getSingleOrNull();

      if (existing == null) {
        await db.into(db.workHoursTable).insert(
          WorkHoursTableCompanion.insert(
            id: const Value(1),
            startHr: 9,
            startMin: 0,
            endHr: 20,
            endMin: 0,
          ),
        );
        _log.info('Initialized default work hours (9:00-20:00) in local DB');
      }
    } catch (e, stackTrace) {
      _log.warning('Failed to ensure default work hours', e, stackTrace);
    }
  }

  Future<void> updateWorkHours({
    required final material.TimeOfDay startTime,
    required final material.TimeOfDay endTime,
  }) async {
    final workHours =
        await (db.update(
          db.workHoursTable,
        )..where((final t) => t.id.equals(kIdWorkHours))).writeReturning(
          WorkHoursTableCompanion(
            startHr: Value(startTime.hour),
            startMin: Value(startTime.minute),
            endHr: Value(endTime.hour),
            endMin: Value(endTime.minute),
          ),
        );

    syncAsync('workhours_$kIdWorkHours', () => _syncWorkHoursToSupabase(workHours.first));
  }

  // ========================================================================
  // SYNC IMPLEMENTATION (BaseRepository overrides)
  // ========================================================================

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
                    isActive: cabin[SupabaseOperatorsTable.isActive] as bool,
                  ),
                );
          }

          _log.info('Pulled ${cabinsData.length} cabins from Supabase');
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
                    isActive: operator[SupabaseOperatorsTable.isActive] as bool,
                  ),
                );
          }

          _log.info('Pulled ${operatorsData.length} operators from Supabase');
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
          _log.info('Pulled work hours from Supabase');
        } else {
          // Insert default work hours if not found in Supabase
          await ensureDefaultWorkHours();
        }
      });
    } catch (e, stackTrace) {
      _log.warning('Pull from Supabase failed', e, stackTrace);
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

    _log.info('Realtime sync started');
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
                  isActive: data[SupabaseOperatorsTable.isActive] as bool,
                ),
              );

          _log.finest(
            'Cabin ${data[SupabaseCabinsTable.id]} synced from realtime',
          );

        // case PostgresChangeEvent.delete:
        //   final id = payload.oldRecord[SupabaseCabinsTable.id] as int;
        //   await (db.delete(
        //     db.cabinsTable,
        //   )..where((final t) => t.id.equals(id))).go();
        //   _log.finest('Cabin $id deleted from realtime');

        // Non viene fatta mai delete, si usa soft delete con isActive
        case PostgresChangeEvent.delete:
        case PostgresChangeEvent.all:
          throw UnimplementedError('${payload.eventType} not supported');
      }
    } catch (e, stackTrace) {
      _log.warning('Failed to handle cabin change', e, stackTrace);
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
                  isActive: data[SupabaseOperatorsTable.isActive] as bool,
                ),
              );

          _log.finest(
            'Operator ${data[SupabaseOperatorsTable.id]} synced from realtime',
          );

        // case PostgresChangeEvent.delete:
        //   final id = payload.oldRecord[SupabaseOperatorsTable.id] as int;
        //   await (db.delete(
        //     db.operatorsTable,
        //   )..where((final t) => t.id.equals(id))).go();
        //
        //   _log.finest('Operator $id deleted from realtime');

        // Non viene fatta mai delete, si usa soft delete con isActive
        case PostgresChangeEvent.delete:
        case PostgresChangeEvent.all:
          throw UnimplementedError('${payload.eventType} not supported');
      }
    } catch (e, stackTrace) {
      _log.warning('Failed to handle operator change', e, stackTrace);
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

        _log.finest('Work hours synced from realtime');
      }
    } catch (e, stackTrace) {
      _log.warning('Failed to handle work hours change', e, stackTrace);
    }
  }

  // ========================================================================
  // PRIVATE SYNC HELPERS
  // ========================================================================

  Future<void> _syncCabinColorToSupabase(final Cabin cabin) async {
    try {
      await supabase
          ?.from(SupabaseSchema.cabins.tableName)
          .update({SupabaseCabinsTable.color: cabin.color})
          .eq(SupabaseCabinsTable.id, cabin.id);
    } catch (e, stackTrace) {
      _log.warning(
        'Failed to sync cabin ${cabin.id} to Supabase',
        e,
        stackTrace,
      );
    }
  }

  Future<void> _syncCabinsActivationToSupabase(final int targetCount) async {
    try {
      final table = SupabaseSchema.cabins.tableName;

      // 1. Attiva su Supabase tutte le cabine con ID <= targetCount
      await supabase
          ?.from(table)
          .update({SupabaseCabinsTable.isActive: true})
          .lte(SupabaseCabinsTable.id, targetCount);

      // 2. Disattiva su Supabase tutte le cabine con ID > targetCount
      await supabase
          ?.from(table)
          .update({SupabaseCabinsTable.isActive: false})
          .gt(SupabaseCabinsTable.id, targetCount);
    } catch (e, stackTrace) {
      _log.warning('Failed to sync cabins state to Supabase', e, stackTrace);
    }
  }

  Future<void> _syncOperatorActivationToSupabase(
    final Operator operator,
  ) async {
    try {
      await supabase
          ?.from(SupabaseSchema.operators.tableName)
          .update({
            SupabaseOperatorsTable.isActive:
                true, // Accende l'operatore sul cloud
          })
          .eq(SupabaseOperatorsTable.id, operator.id);
    } catch (e, stackTrace) {
      _log.warning(
        'Failed to sync operator activation to Supabase',
        e,
        stackTrace,
      );
    }
  }

  Future<void> _syncOperatorNameToSupabase(final Operator operator) async {
    try {
      await supabase
          ?.from(SupabaseSchema.operators.tableName)
          .update({SupabaseOperatorsTable.name: operator.name})
          .eq(SupabaseOperatorsTable.id, operator.id);
    } catch (e, stackTrace) {
      _log.warning(
        'Failed to sync operator ${operator.id} to Supabase',
        e,
        stackTrace,
      );
    }
  }

  Future<void> _syncOperatorDeletionToSupabase(final Operator operator) async {
    try {
      await supabase
          ?.from(SupabaseSchema.operators.tableName)
          .update({
            SupabaseOperatorsTable.isActive:
                false, // Spegne l'operatore sul cloud (soft delete)
          })
          .eq(SupabaseOperatorsTable.id, operator.id);
    } catch (e, stackTrace) {
      _log.warning(
        'Failed to delete operator ${operator.id} from Supabase',
        e,
        stackTrace,
      );
    }
  }

  Future<void> _syncWorkHoursToSupabase(final WorkHours workHours) async {
    try {
      await supabase
          ?.from(SupabaseSchema.workHours.tableName)
          .update({
            SupabaseWorkHoursTable.startHr: workHours.startHr,
            SupabaseWorkHoursTable.startMin: workHours.startMin,
            SupabaseWorkHoursTable.endHr: workHours.endHr,
            SupabaseWorkHoursTable.endMin: workHours.endMin,
          })
          .eq(SupabaseWorkHoursTable.id, kIdWorkHours);
    } catch (e, stackTrace) {
      _log.warning('Failed to sync work hours to Supabase', e, stackTrace);
    }
  }
}
