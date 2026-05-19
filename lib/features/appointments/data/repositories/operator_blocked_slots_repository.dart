import 'package:drift/drift.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:uuid/uuid.dart';

import '../../../../core/constants/app_constants.dart';
import '../../../../core/database/app_database.dart';
import '../../../../core/database/repositories/base_repository.dart';
import '../../../../core/database/supabase_schema.dart';
import '../../../../core/logging/app_logger.dart';
import '../../models/blocked_slot_recurrence.dart';

const uuid = Uuid();

// ============================================================================
// REPOSITORY
// ============================================================================

/// Repository for operator blocked slot management.
///
/// Follows the offline-first pattern established by [BaseRepository]:
/// 1. Every write hits the local Drift DB first.
/// 2. A non-blocking async sync pushes the change to Supabase.
/// 3. Realtime subscriptions (started on first sync) propagate remote changes.
class OperatorBlockedSlotRepository extends BaseRepository {
  OperatorBlockedSlotRepository({
    required super.db,
    required super.supabase,
    required super.isOnline,
  });

  static final _log = AppLogger.getLogger(
    name: 'OperatorBlockedSlotRepository',
  );

  // ==========================================================================
  // READ — always from local DB
  // ==========================================================================

  /// Live stream of all blocked slots for all operators.
  Stream<List<OperatorBlockedSlot>> watchAllBlockedSlots() => (db.select(
    db.operatorBlockedSlotsTable,
  )..orderBy([(final t) => OrderingTerm.asc(t.startDateTime)])).watch();

  /// Live stream of operator blocked slots for a single day (inclusive range).
  Stream<List<OperatorBlockedSlot>> watchBlockedSlotsForDay(
    final DateTime day,
  ) {
    final start = DateTime(day.year, day.month, day.day);
    final end = start.add(const Duration(days: 1));
    return (db.select(db.operatorBlockedSlotsTable)
          ..where(
            (final t) =>
                t.isActive.equals(true) &
                t.startDateTime.isBiggerOrEqualValue(start) &
                t.startDateTime.isSmallerThanValue(end),
          )
          ..orderBy([(final t) => OrderingTerm.asc(t.startDateTime)]))
        .watch();
  }

  /// Watch operator blocked slot by ID for reactive UI updates
  Stream<OperatorBlockedSlot?> watchBlockedSlotById(final String id) =>
      (db.select(
        db.operatorBlockedSlotsTable,
      )..where((final t) => t.id.equals(id))).watchSingleOrNull();

  // ==========================================================================
  // CREATE
  // ==========================================================================

  /// Create blocked slot
  /// Returns slot ID or null if offline (read-only mode)
  Future<String?> createBlockedSlot({
    required final int operatorId,
    required final DateTime startDateTime,
    required final DateTime endDateTime,
    final String? reason,
  }) async {
    if (!isOnline) {
      _log.warning('Cannot create blocked slot: offline mode (read-only)');
      return null;
    }

    assert(
      startDateTime.isBefore(endDateTime),
      'OperatorBlockedSlot startDateTime must be before endDateTime',
    );

    final id = uuid.v7();
    final now = DateTime.now().toUtc();

    final blockedSlot = await db
        .into(db.operatorBlockedSlotsTable)
        .insertReturning(
          OperatorBlockedSlotsTableCompanion.insert(
            id: Value(id),
            seriesId: const Value(null),
            operatorId: operatorId,
            startDateTime: startDateTime,
            endDateTime: endDateTime,
            reason: Value(reason),
            createdAt: Value(now),
            updatedAt: Value(now),
            isActive: const Value(true),
          ),
        );

    syncAsync('blocked_slot_${blockedSlot.id}', () => _syncBlockedSlotToSupabase(blockedSlot));
    return blockedSlot.id;
  }

  Future<bool> createRecurrenceBlockedSlots({
    required final int operatorId,
    required final DateTime startDateTime,
    required final DateTime endDateTime,
    required final BlockedSlotRecurrence recurrence,
    required final DateTime until,
    final String? reason,
  }) async {
    if (!isOnline) {
      _log.warning('Cannot create recurrence slots: offline mode (read-only)');
      return false;
    }

    final occurrences = _expandRecurrence(
      start: startDateTime,
      end: endDateTime,
      recurrence: recurrence,
      until: until,
    );

    final now = DateTime.now().toUtc();

    final futures = occurrences
        .map(
          (occ) => db
              .into(db.operatorBlockedSlotsTable)
              .insertReturning(
                OperatorBlockedSlotsTableCompanion.insert(
                  id: Value(uuid.v7()),
                  seriesId: Value(uuid.v7()),
                  operatorId: operatorId,
                  startDateTime: occ.start,
                  endDateTime: occ.end,
                  reason: Value(reason),
                  createdAt: Value(now),
                  updatedAt: Value(now),
                  isActive: const Value(true),
                ),
              ),
        )
        .toList();

    final results = await Future.wait(futures);

    // Sync all in one batch
    syncAsync('blocked_slots_batch_${results.first.id}', () async {
      for (final blockedSlot in results) {
        await _syncBlockedSlotToSupabase(blockedSlot);
      }
    });

    return true;
  }

  List<({DateTime start, DateTime end})> _expandRecurrence({
    required final DateTime start,
    required final DateTime end,
    required final BlockedSlotRecurrence recurrence,
    required final DateTime until,
  }) {
    if (recurrence == BlockedSlotRecurrence.none) {
      return [(start: start, end: end)];
    }

    final duration = end.difference(start);
    final result = <({DateTime start, DateTime end})>[];
    var cursor = start;

    while (!cursor.isAfter(until)) {
      result.add((start: cursor, end: cursor.add(duration)));
      cursor = switch (recurrence) {
        BlockedSlotRecurrence.none => until.add(const Duration(days: 1)),
        BlockedSlotRecurrence.daily => cursor.add(const Duration(days: 1)),
        BlockedSlotRecurrence.weekly => cursor.add(const Duration(days: 7)),
        BlockedSlotRecurrence.monthly => DateTime(
          cursor.year,
          cursor.month + 1,
          cursor.day,
          cursor.hour,
          cursor.minute,
        ),
      };
    }

    return result;
  }

  // ===========================================================================
  // UPDATE
  // ===========================================================================

  Future<bool> updateBlockedSlot({
    required final String id,
    required final int operatorId,
    required final DateTime startDateTime,
    required final DateTime endDateTime,
    final String? reason,
  }) async {
    if (!isOnline) {
      _log.warning('Cannot update blocked slot: offline mode (read-only)');
      return false;
    }

    assert(
      startDateTime.isBefore(endDateTime),
      'startDateTime must be before endDateTime',
    );

    final updateBlockedSlot =
        await (db.update(
          db.operatorBlockedSlotsTable,
        )..where((t) => t.id.equals(id))).writeReturning(
          OperatorBlockedSlotsTableCompanion(
            operatorId: Value(operatorId),
            startDateTime: Value(startDateTime),
            endDateTime: Value(endDateTime),
            reason: Value(reason),
            updatedAt: Value(DateTime.now().toUtc()),
          ),
        );

    syncAsync('blocked_slot_${updateBlockedSlot.first.id}', () => _syncBlockedSlotToSupabase(updateBlockedSlot.first));
    return true;
  }

  Future<bool> updateRecurrenceBlockedSlots({
    required final String seriesId,
    required final int operatorId,
    required final DateTime startDateTime,
    required final DateTime endDateTime,
    final String? reason,
  }) async {
    if (!isOnline) {
      _log.warning('Cannot update recurrence slots: offline mode (read-only)');
      return false;
    }

    assert(
      startDateTime.isBefore(endDateTime),
      'startDateTime must be before endDateTime',
    );

    final updateAllBlockedSlots =
        await (db.update(
          db.operatorBlockedSlotsTable,
        )..where((t) => t.seriesId.equals(seriesId))).writeReturning(
          OperatorBlockedSlotsTableCompanion(
            operatorId: Value(operatorId),
            startDateTime: Value(startDateTime),
            endDateTime: Value(endDateTime),
            reason: Value(reason),
            updatedAt: Value(DateTime.now().toUtc()),
          ),
        );

    syncAsync(
      'blocked_slots_series_$seriesId',
      () => _syncRecurrenceBlockedSlotToSupabase(updateAllBlockedSlots),
    );

    return true;
  }

  // ==========================================================================
  // DELETE
  // ==========================================================================

  /// Delete blocked slot
  /// Returns true if successful, false if offline (read-only mode)
  Future<bool> deleteBlockedSlot(final String id) async {
    if (!isOnline) {
      _log.warning('Cannot delete blocked slot: offline mode (read-only)');
      return false;
    }

    final updateBlockedSlot =
        await (db.update(
          db.operatorBlockedSlotsTable,
        )..where((final t) => t.id.equals(id))).writeReturning(
          OperatorBlockedSlotsTableCompanion(
            isActive: const Value(false),
            updatedAt: Value(DateTime.now().toUtc()),
          ),
        );

    syncAsync('blocked_slot_${updateBlockedSlot.first.id}', () => _deleteBlockedSlotFromSupabase(updateBlockedSlot.first));
    return true;
  }

  /// Delete recurrence blocked slots
  /// Returns true if successful, false if offline (read-only mode)
  Future<bool> deleteRecurrenceBlockedSlots(final String seriesId) async {
    if (!isOnline) {
      _log.warning('Cannot delete recurrence slots: offline mode (read-only)');
      return false;
    }

    final updateBlockedSlots =
        await (db.update(
          db.operatorBlockedSlotsTable,
        )..where((final t) => t.seriesId.equals(seriesId))).writeReturning(
          OperatorBlockedSlotsTableCompanion(
            isActive: const Value(false),
            updatedAt: Value(DateTime.now().toUtc()),
          ),
        );

    syncAsync(
      'blocked_slots_series_$seriesId',
      () => _deleteRecurrenceBlockedSlotFromSupabase(updateBlockedSlots),
    );
    return true;
  }

  // ========================================================================
  // SYNC IMPLEMENTATION (BaseRepository overrides)
  // ========================================================================
  @override
  Future<void> pullSupabaseToLocal() async {
    if (!isOnline) return;

    try {
      // 1. Get the last time we synced
      final lastSync = await getLastSyncTime(
        kLastSyncTimeOperatorsBlockedSlotsKey,
      );

      // 2. Fetch UPDATES/INSERTS (Delta Sync)
      // If lastSync is null, we fetch everything.
      // If lastSync exists, we only fetch what changed since then.
      var query = supabase!
          .from(SupabaseSchema.operatorBlockedSlots.tableName)
          .select();

      if (lastSync != null) {
        // Buffer to ensure we don't miss edge cases with clock skew
        final adjustedTime = lastSync.subtract(kLastSyncBufferDuration);
        query = query.gt(
          SupabaseOperatorBlockedSlotsTable.updatedAt,
          adjustedTime.toIso8601String(),
        );
      }

      final updatesData = await query;

      // 3. Fetch ALL IDs to handle DELETIONS (Hard Delete Check)
      final allRemoteIdsData = await supabase!
          .from(SupabaseSchema.operatorBlockedSlots.tableName)
          .select(SupabaseOperatorBlockedSlotsTable.id);

      final remoteIds = List<Map<String, dynamic>>.from(allRemoteIdsData)
          .map((final e) => e[SupabaseOperatorBlockedSlotsTable.id] as String)
          .toSet();

      await db.transaction(() async {
        // A. Apply Updates/Inserts
        if (updatesData.isNotEmpty) {
          await db.batch((final batch) {
            final companions = updatesData.map(_mapSupabaseDataToCompanion);
            batch.insertAllOnConflictUpdate(
              db.operatorBlockedSlotsTable,
              companions,
            );
          });
          _log.info(
            'Synced ${updatesData.length} updated/new operators blocked slots.',
          );
        }

        // B. Handle Deletions (Orphan Removal)
        if (remoteIds.isNotEmpty) {
          await (db.delete(
            db.operatorBlockedSlotsTable,
          )..where((final t) => t.id.isNotIn(remoteIds))).go();
        } else if (updatesData.isEmpty && allRemoteIdsData.isEmpty) {
          // Edge case: Server is completely empty, and we correctly got 0 remote IDs
          await db.delete(db.operatorBlockedSlotsTable).go();
        }
      });

      // 4. Update timestamp
      await updateLastSyncTime(kLastSyncTimeAppointmentsKey);
    } catch (e, stackTrace) {
      _log.warning('Pull from Supabase failed', e, stackTrace);
      // Important: Do not update timestamp if sync failed
    }
  }

  @override
  void startRealtimeSync() {
    if (!isOnline) return;

    subscribeToChannel(
      table: SupabaseSchema.operatorBlockedSlots,
      onEvent: _handleOperatorBlockedSlotChange,
    );

    _log.info('Realtime sync started for operator blocked slots');
  }

  // ========================================================================
  // REALTIME EVENT HANDLER
  // ========================================================================

  Future<void> _handleOperatorBlockedSlotChange(
    final PostgresChangePayload payload,
  ) async {
    try {
      switch (payload.eventType) {
        case PostgresChangeEvent.insert:
        case PostgresChangeEvent.update:
          final data = payload.newRecord;

          await db
              .into(db.operatorBlockedSlotsTable)
              .insertOnConflictUpdate(_mapSupabaseDataToCompanion(data));

          _log.finest(
            'Operator blocked slot ${data[SupabaseOperatorBlockedSlotsTable.id]} synced from realtime',
          );

        // case PostgresChangeEvent.delete:
        //   final oldData = payload.oldRecord;
        //   final id = oldData[SupabaseOperatorBlockedSlotsTable.id] as String;
        //
        //   await (db.delete(
        //     db.operatorBlockedSlotsTable,
        //   )..where((final t) => t.id.equals(id))).go();
        //   _log.finest('Operator blocked slot $id deleted from realtime');

        // Non viene fatta mai delete, si usa soft delete con isActive
        case PostgresChangeEvent.delete:
        case PostgresChangeEvent.all:
          throw UnimplementedError('PostgresChangeEvent.all not supported');
      }
    } catch (e, stackTrace) {
      _log.warning(
        'Failed to handle operator blocked slot change',
        e,
        stackTrace,
      );
    }
  }

  // ========================================================================
  // PRIVATE SYNC HELPERS
  // ========================================================================

  OperatorBlockedSlotsTableCompanion _mapSupabaseDataToCompanion(
    final Map<String, dynamic> data,
  ) => OperatorBlockedSlotsTableCompanion.insert(
    id: Value(data[SupabaseOperatorBlockedSlotsTable.id] as String),
    seriesId: Value(
      data[SupabaseOperatorBlockedSlotsTable.seriesId] as String?,
    ),
    operatorId: data[SupabaseOperatorBlockedSlotsTable.operatorId] as int,
    startDateTime: DateTime.parse(
      data[SupabaseOperatorBlockedSlotsTable.startDateTime] as String,
    ).toLocal(),
    endDateTime: DateTime.parse(
      data[SupabaseOperatorBlockedSlotsTable.endDateTime] as String,
    ).toLocal(),
    reason: Value(data[SupabaseOperatorBlockedSlotsTable.reason] as String?),
    createdAt: Value(
      DateTime.parse(
        data[SupabaseOperatorBlockedSlotsTable.createdAt] as String,
      ).toLocal(),
    ),
    updatedAt: Value(
      DateTime.parse(
        data[SupabaseOperatorBlockedSlotsTable.updatedAt] as String,
      ).toLocal(),
    ),
    isActive: Value(data[SupabaseOperatorBlockedSlotsTable.isActive] as bool),
  );

  Future<void> _syncBlockedSlotToSupabase(
    final OperatorBlockedSlot blockedSlot,
  ) async {
    try {
      await supabase
          ?.from(SupabaseSchema.operatorBlockedSlots.tableName)
          .upsert({
            SupabaseOperatorBlockedSlotsTable.id: blockedSlot.id,
            SupabaseOperatorBlockedSlotsTable.seriesId: blockedSlot.seriesId,
            SupabaseOperatorBlockedSlotsTable.operatorId:
                blockedSlot.operatorId,
            SupabaseOperatorBlockedSlotsTable.startDateTime: blockedSlot
                .startDateTime
                .toUtc()
                .toIso8601String(),
            SupabaseOperatorBlockedSlotsTable.endDateTime: blockedSlot
                .endDateTime
                .toUtc()
                .toIso8601String(),
            SupabaseOperatorBlockedSlotsTable.reason: blockedSlot.reason,
            SupabaseOperatorBlockedSlotsTable.createdAt: blockedSlot.createdAt
                .toUtc()
                .toIso8601String(),
            SupabaseOperatorBlockedSlotsTable.updatedAt: blockedSlot.updatedAt
                .toUtc()
                .toIso8601String(),
            SupabaseOperatorBlockedSlotsTable.isActive: blockedSlot.isActive,
          });
    } catch (e, stackTrace) {
      _log.warning(
        'Failed to sync operator blocked slot ${blockedSlot.id} to Supabase',
        e,
        stackTrace,
      );
    }
  }

  Future<void> _syncRecurrenceBlockedSlotToSupabase(
    final List<OperatorBlockedSlot> blockedSlots,
  ) async {
    try {
      final data = blockedSlots
          .map(
            (final slot) => {
              SupabaseOperatorBlockedSlotsTable.id: slot.id,
              SupabaseOperatorBlockedSlotsTable.seriesId: slot.seriesId,
              SupabaseOperatorBlockedSlotsTable.operatorId: slot.operatorId,
              SupabaseOperatorBlockedSlotsTable.startDateTime: slot
                  .startDateTime
                  .toUtc()
                  .toIso8601String(),
              SupabaseOperatorBlockedSlotsTable.endDateTime: slot.endDateTime
                  .toUtc()
                  .toIso8601String(),
              SupabaseOperatorBlockedSlotsTable.reason: slot.reason,
              SupabaseOperatorBlockedSlotsTable.createdAt: slot.createdAt
                  .toUtc()
                  .toIso8601String(),
              SupabaseOperatorBlockedSlotsTable.updatedAt: slot.updatedAt
                  .toUtc()
                  .toIso8601String(),
              SupabaseOperatorBlockedSlotsTable.isActive: slot.isActive,
            },
          )
          .toList();

      await supabase
          ?.from(SupabaseSchema.operatorBlockedSlots.tableName)
          .upsert(data);
    } catch (e, stackTrace) {
      _log.warning(
        'Failed to sync operator blocked slots with seriesId ${blockedSlots.first.seriesId} to Supabase',
        e,
        stackTrace,
      );
    }
  }

  Future<void> _deleteBlockedSlotFromSupabase(
    final OperatorBlockedSlot blockedSlot,
  ) async {
    try {
      await supabase
          ?.from(SupabaseSchema.operatorBlockedSlots.tableName)
          .update({SupabaseOperatorBlockedSlotsTable.isActive: false})
          .eq(SupabaseOperatorBlockedSlotsTable.id, blockedSlot.id);
    } catch (e, stackTrace) {
      _log.warning(
        'Failed to delete operator blocked slot ${blockedSlot.id} from Supabase',
        e,
        stackTrace,
      );
    }
  }

  Future<void> _deleteRecurrenceBlockedSlotFromSupabase(
    final List<OperatorBlockedSlot> blockedSlots,
  ) async {
    final seriesId = blockedSlots.first.seriesId!;

    try {
      await supabase
          ?.from(SupabaseSchema.operatorBlockedSlots.tableName)
          .update({SupabaseOperatorBlockedSlotsTable.isActive: false})
          .eq(SupabaseOperatorBlockedSlotsTable.seriesId, seriesId);
    } catch (e, stackTrace) {
      _log.warning(
        'Failed to delete operator blocked slots with seriesId $seriesId from Supabase',
        e,
        stackTrace,
      );
    }
  }
}
