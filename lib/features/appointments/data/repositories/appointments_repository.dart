// file: features/appointments/data/repositories/appointments_repository.dart

import 'package:drift/drift.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:uuid/uuid.dart';

import '../../../../core/constants/app_constants.dart';
import '../../../../core/database/app_database.dart';
import '../../../../core/database/repositories/base_repository.dart';
import '../../../../core/database/supabase_schema.dart';
import '../../../../core/logging/app_logger.dart';

// ============================================================================
// REPOSITORY
// ============================================================================

/// Repository for appointments management.
///
/// Follows the offline-first pattern established by [BaseRepository]:
/// 1. Every write hits the local Drift DB first.
/// 2. A non-blocking async sync pushes the change to Supabase.
/// 3. Realtime subscriptions (started on first sync) propagate remote changes.
class AppointmentsRepository extends BaseRepository {
  AppointmentsRepository({
    required super.db,
    required super.supabase,
    required super.isOnline,
  });

  static final _log = AppLogger.getLogger(name: 'AppointmentsRepository');

  // ==========================================================================
  // READ — always from local DB
  // ==========================================================================

  /// Live stream of ALL appointments, ordered by start time.
  /// Syncfusion receives this stream and renders only the visible range.
  Stream<List<AppointmentData>> watchAllAppointments() => (db.select(
    db.appointmentsTable,
  )..orderBy([(final t) => OrderingTerm.asc(t.startDateTime)])).watch();

  /// Live stream of appointments for a single day (inclusive range).
  Stream<List<AppointmentData>> watchAppointmentsForDay(final DateTime day) {
    final start = DateTime(day.year, day.month, day.day);
    final end = start.add(const Duration(days: 1));
    return watchAppointmentsForRange(start, end);
  }

  /// Live stream of appointments for a range.
  Stream<List<AppointmentData>> watchAppointmentsForRange(
    final DateTime start,
    final DateTime end,
  ) =>
      (db.select(db.appointmentsTable)
            ..where(
              (final t) =>
                  t.startDateTime.isBiggerOrEqualValue(start) &
                  t.startDateTime.isSmallerThanValue(end),
            )
            ..orderBy([(final t) => OrderingTerm.asc(t.startDateTime)]))
          .watch();

  /// Single appointment by id (null if not found).
  Future<AppointmentData?> getAppointmentById(final String id) => (db.select(
    db.appointmentsTable,
  )..where((final t) => t.id.equals(id))).getSingleOrNull();

  /// Watch appointment by ID for reactive UI updates
  Stream<AppointmentData?> watchAppointmentById(final String id) => (db.select(
    db.appointmentsTable,
  )..where((final t) => t.id.equals(id))).watchSingleOrNull();

  /// Watch appointments by client ID for reactive UI updates
  Stream<List<AppointmentData>> watchAppointmentsByClientId(
    final String clientId,
  ) =>
      (db.select(db.appointmentsTable)
            ..where(
              (final t) =>
                  t.clientId.equals(clientId) & t.isActive.equals(true),
            )
            ..orderBy([(final t) => OrderingTerm.desc(t.startDateTime)]))
          .watch();

  // ==========================================================================
  // APPOINTMENT SERVICES
  // ==========================================================================

  /// Get appointment services by appointment ID
  Future<List<AppointmentServiceData>> getAppointmentServicesByAppointmentId(
    final String appointmentId,
  ) => (db.select(
    db.appointmentServicesTable,
  )..where((final t) => t.appointmentId.equals(appointmentId))).get();

  /// Watch appointment services by appointment ID for reactive UI updates
  Stream<List<AppointmentServiceData>> watchAppointmentServicesByAppointmentId(
    final String appointmentId,
  ) => (db.select(
    db.appointmentServicesTable,
  )..where((final t) => t.appointmentId.equals(appointmentId))).watch();

  /// Create appointment service
  Future<String> createAppointmentService({
    required final String appointmentId,
    required final String serviceId,
    required final double lockedPrice,
    required final int lockedDuration,
    required final String paymentSource,
    final String? packageItemId,
    final String? fidelityCardId,
  }) async {
    final insertedService = await db
        .into(db.appointmentServicesTable)
        .insertReturning(
          AppointmentServicesTableCompanion.insert(
            id: Value(const Uuid().v7()),
            appointmentId: appointmentId,
            serviceId: serviceId,
            lockedPrice: lockedPrice,
            lockedDuration: lockedDuration,
            packageItemId: Value(packageItemId),
            fidelityCardId: Value(fidelityCardId),
            paymentSource: Value(paymentSource),
          ),
        );

    syncAsync(
      'appointment_service_${insertedService.id}',
      () => _syncAppointmentServiceToSupabase(insertedService.id),
    );

    return insertedService.id;
  }

  /// Delete appointment services by appointment ID
  Future<void> deleteAppointmentServicesByAppointmentId(
    final String appointmentId,
  ) async {
    await (db.delete(
      db.appointmentServicesTable,
    )..where((final t) => t.appointmentId.equals(appointmentId))).go();

    syncAsync(
      'delete_services_$appointmentId',
      () => _deleteAppointmentServicesFromSupabase(appointmentId),
    );
  }

  // ==========================================================================
  // CREATE
  // ==========================================================================

  /// Creates an appointment locally and syncs to Supabase.
  /// Returns the appointment ID or null on error.
  /// Note: Works offline - sync to Supabase happens in background.
  Future<String?> createAppointment({
    required final int operatorId,
    required final String clientId,
    required final int cabinId,
    required final String service,
    required final DateTime startDateTime,
    required final DateTime endDateTime,
    final String? notes,
  }) async {
    assert(
      startDateTime.isBefore(endDateTime),
      'Appointment startTime must be before endTime',
    );

    final now = DateTime.now().toUtc();

    // Insert to local DB first (offline-first)
    final insertedAppointment = await db
        .into(db.appointmentsTable)
        .insertReturning(
          AppointmentsTableCompanion.insert(
            id: Value(const Uuid().v7()),
            operatorId: Value(operatorId),
            clientId: Value(clientId),
            cabinId: Value(cabinId),
            startDateTime: startDateTime,
            endDateTime: endDateTime,
            notes: Value(notes?.trim()),
            discount: const Value.absent(),
            discountReason: const Value.absent(),
            createdAt: Value(now),
            updatedAt: Value(now),
            isActive: const Value(true),
          ),
        );

    _log.info('Appointment ${insertedAppointment.id} created locally, scheduling sync...');
    
    // Esegui sync in background con retry robusto
    await _triggerSyncWithDebounce(insertedAppointment.id);

    return insertedAppointment.id;
  }

  // ==========================================================================
  // UPDATE
  // ==========================================================================

  /// Updates an existing appointment.
  /// Returns true if successful, false if offline (read-only mode).
  Future<bool> updateAppointment({
    required final String id,
    required final int operatorId,
    required final String clientId,
    required final int cabinId,
    required final String service,
    required final DateTime startDateTime,
    required final DateTime endDateTime,
    final String? notes,
  }) async {
    if (!isOnline) {
      _log.warning('Cannot update appointment: offline mode (read-only)');
      return false;
    }

    final upApt =
        await (db.update(
          db.appointmentsTable,
        )..where((final t) => t.id.equals(id))).writeReturning(
          AppointmentsTableCompanion(
            operatorId: Value(operatorId),
            clientId: Value(clientId),
            cabinId: Value(cabinId),

            startDateTime: Value(startDateTime),
            endDateTime: Value(endDateTime),
            notes: Value(notes?.trim()),
            updatedAt: Value(DateTime.now().toUtc()),
          ),
        );

    syncAsync(
      'appointment_${upApt.first.id}',
      () async => _syncAppointmentToSupabase(upApt.first),
    );

    return true;
  }

  // ==========================================================================
  // UPDATE WITH SERVICES — transactional update of appointment and its services
  // ==========================================================================

  /// Atomically updates an appointment and replaces all its services.
  /// Prevents partial state where appointment exists but services are missing.
  Future<bool> updateAppointmentWithServices({
    required final String id,
    required final int operatorId,
    required final String clientId,
    required final int cabinId,
    required final DateTime startDateTime,
    required final DateTime endDateTime,
    final String? notes,
    required final List<
      ({
        String serviceId,
        double lockedPrice,
        int lockedDuration,
        String paymentSource,
        String? packageItemId,
        String? fidelityCardId,
      })
    >
    services,
  }) async {
    if (!isOnline) {
      _log.warning('Cannot update appointment: offline mode (read-only)');
      return false;
    }

    final now = DateTime.now().toUtc();

    await db.transaction(() async {
      // 1. Update appointment
      await (db.update(
        db.appointmentsTable,
      )..where((final t) => t.id.equals(id))).write(
        AppointmentsTableCompanion(
          operatorId: Value(operatorId),
          clientId: Value(clientId),
          cabinId: Value(cabinId),
          startDateTime: Value(startDateTime),
          endDateTime: Value(endDateTime),
          notes: Value(notes?.trim()),
          updatedAt: Value(now),
        ),
      );

      // 2. Delete old services
      await (db.delete(
        db.appointmentServicesTable,
      )..where((final t) => t.appointmentId.equals(id))).go();

      // 3. Insert new services
      for (final svc in services) {
        await db
            .into(db.appointmentServicesTable)
            .insert(
              AppointmentServicesTableCompanion.insert(
                id: Value(const Uuid().v7()),
                appointmentId: id,
                serviceId: svc.serviceId,
                lockedPrice: svc.lockedPrice,
                lockedDuration: svc.lockedDuration,
                packageItemId: Value(svc.packageItemId),
                fidelityCardId: Value(svc.fidelityCardId),
                paymentSource: Value(svc.paymentSource),
              ),
            );
      }
    });

    // 4. Sync appointment and services to Supabase after transaction is complete
    syncAsync('appointment_$id', () async {
      final appointment = await getAppointmentById(id);
      if (appointment != null) {
        await _syncAppointmentToSupabase(appointment);
      }
      await _deleteAppointmentServicesFromSupabase(id);
      for (final svc in services) {
        final inserted =
            await (db.select(db.appointmentServicesTable)..where(
                  (final t) =>
                      t.appointmentId.equals(id) &
                      t.serviceId.equals(svc.serviceId),
                ))
                .get();
        for (final row in inserted) {
          await _syncAppointmentServiceToSupabase(row.id);
        }
      }
    });

    return true;
  }

  // ===========================================================================
  // MOVE — changes date/time and optionally operator, preserves everything else
  // ===========================================================================

  Future<bool> moveAppointment({
    required String id,
    required DateTime newStartDateTime,
    required DateTime newEndDateTime,
    int? newOperatorId,
  }) async {
    if (!isOnline) {
      _log.warning('Cannot move appointment: offline mode (read-only)');
      return false;
    }

    assert(
      newStartDateTime.isBefore(newEndDateTime),
      'newStartDateTime must be before newEndDateTime',
    );

    final upApt =
        await (db.update(
          db.appointmentsTable,
        )..where((t) => t.id.equals(id))).writeReturning(
          AppointmentsTableCompanion(
            operatorId: newOperatorId != null
                ? Value(newOperatorId)
                : const Value.absent(),
            startDateTime: Value(newStartDateTime),
            endDateTime: Value(newEndDateTime),
            updatedAt: Value(DateTime.now().toUtc()),
          ),
        );

    syncAsync(
      'appointment_${upApt.first.id}',
      () => _syncAppointmentToSupabase(upApt.first),
    );

    return true;
  }

  // ===========================================================================
  // DUPLICATE — creates a copy with a new ID, optionally on a different day
  // ===========================================================================

  Future<void> duplicateAppointment({
    required String sourceId,
    required DateTime newStartDateTime,
    required DateTime newEndDateTime,
    int? newOperatorId,
  }) async {
    final source = await getAppointmentById(sourceId);
    if (source == null) {
      throw StateError('Source appointment $sourceId not found');
    }

    // Get services from source appointment to duplicate
    final sourceServices = await getAppointmentServicesByAppointmentId(
      sourceId,
    );

    // Create new appointment with same details but new time slot
    final newAppointmentId = await createAppointment(
      operatorId: newOperatorId ?? source.operatorId ?? 0,
      clientId: source.clientId ?? '',
      cabinId: source.cabinId ?? 0,
      service: sourceServices.isNotEmpty ? sourceServices.first.serviceId : '',
      startDateTime: newStartDateTime,
      endDateTime: newEndDateTime,
      notes: source.notes,
    );

    if (newAppointmentId == null) {
      throw StateError(
        'Failed to duplicate appointment: offline mode (read-only)',
      );
    }

    // Duplicate all services but reset payment sources to direct
    // (package/fidelity credits should NOT be double-charged)
    for (var i = 0; i < sourceServices.length; i++) {
      final svc = sourceServices[i];
      // Skip the first service as it was already created as the placeholder
      if (i == 0) continue;
      await createAppointmentService(
        appointmentId: newAppointmentId,
        serviceId: svc.serviceId,
        lockedPrice: svc.lockedPrice,
        lockedDuration: svc.lockedDuration,
        paymentSource: 'direct',
      );
    }
  }

  // ==========================================================================
  // DELETE
  // ==========================================================================

  /// Deletes an appointment and restores sessions/fidelity credits.
  /// This is a transactional operation that:
  /// 1. Restores package sessions if services were paid with packages
  /// 2. Refunds fidelity cards if services were paid with fidelity
  /// 3. Soft-deletes the appointment and its services
  /// Returns true if successful, false if offline (read-only mode).
  Future<bool> deleteAppointment(final String id) async {
    if (!isOnline) {
      _log.warning('Cannot delete appointment: offline mode (read-only)');
      return false;
    }

    await db.transaction(() async {
      // Get appointment services before deletion
      final services = await getAppointmentServicesByAppointmentId(id);

      // Restore package sessions
      for (final service in services) {
        if (service.paymentSource == 'package' &&
            service.packageItemId != null) {
          // Decrement usedSessions to restore the session
          final item =
              await (db.select(db.packageItemsTable)
                    ..where((final t) => t.id.equals(service.packageItemId!)))
                  .getSingleOrNull();
          if (item != null && item.usedSessions > 0) {
            await (db.update(
              db.packageItemsTable,
            )..where((final t) => t.id.equals(service.packageItemId!))).write(
              PackageItemsTableCompanion(
                usedSessions: Value(item.usedSessions - 1),
              ),
            );
          }
        }

        // Refund fidelity cards
        if (service.paymentSource == 'fidelity' &&
            service.fidelityCardId != null) {
          final item = await (db.select(
            db.appointmentServicesTable,
          )..where((final t) => t.id.equals(service.id))).getSingleOrNull();
          if (item != null) {
            // Get current card balance
            final card =
                await (db.select(
                      db.fidelityCardsTable,
                    )..where((final t) => t.id.equals(service.fidelityCardId!)))
                    .getSingleOrNull();
            if (card != null) {
              // Increment balance by the refunded amount
              await (db.update(db.fidelityCardsTable)
                    ..where((final t) => t.id.equals(service.fidelityCardId!)))
                  .write(
                    FidelityCardsTableCompanion(
                      balance: Value(card.balance + item.lockedPrice),
                    ),
                  );

              // Create refund transaction
              await db
                  .into(db.fidelityTransactionsTable)
                  .insert(
                    FidelityTransactionsTableCompanion.insert(
                      id: Value(const Uuid().v7()),
                      fidelityCardId: service.fidelityCardId!,
                      amount: item.lockedPrice,
                      type: 'refund',
                      description: const Value(
                        'Rimborso appuntamento cancellato',
                      ),
                      createdAt: Value(DateTime.now().toUtc()),
                    ),
                  );
            }
          }
        }
      }

      // Soft-delete appointment
      await (db.update(
        db.appointmentsTable,
      )..where((final t) => t.id.equals(id))).writeReturning(
        const AppointmentsTableCompanion(isActive: Value(false)),
      );

      // Soft-delete appointment services (local only — sync happens outside transaction)
      await (db.delete(
        db.appointmentServicesTable,
      )..where((final t) => t.appointmentId.equals(id))).go();
    });

    // Sync to Supabase outside the local DB transaction
    syncAsync('delete_appointment_$id', () async {
      await _deleteAppointmentFromSupabase((await getAppointmentById(id))!);
      await _deleteAppointmentServicesFromSupabase(id);
    });

    return true;
  }

  // ========================================================================
  // SYNC HELPER - Robust sync with retry
  // ========================================================================

  /// Trigger sync con debounce e retry robusto
  Future<void> _triggerSyncWithDebounce(final String appointmentId) async {
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

        _log.finest('Sync attempt $attempt/$maxAttempts for appointment $appointmentId');
        await syncEntityToSupabase(appointmentId);
        
        _log.info('Appointment $appointmentId synced successfully on attempt $attempt');
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

    _log.warning('Appointment $appointmentId failed to sync after $maxAttempts attempts');
  }

  // ========================================================================
  // SYNC IMPLEMENTATION (BaseRepository overrides)
  // ========================================================================

  @override
  Future<void> pullSupabaseToLocal() async {
    // CRITICAL: Verifica che supabase sia disponibile
    if (supabase == null) {
      _log.warning('Cannot pull appointments: Supabase client is null');
      return;
    }

    try {
      // 1. Get the last time we synced
      final lastSync = await getLastSyncTime(kLastSyncTimeAppointmentsKey);

      // 2. Fetch UPDATES/INSERTS (Delta Sync)
      var query = supabase?.from(SupabaseSchema.appointments.tableName).select();
      if (query == null) {
        _log.warning('Cannot pull appointments: Supabase client is null');
        return;
      }

      if (lastSync != null) {
        final adjustedTime = lastSync.subtract(kLastSyncBufferDuration);
        query = query.gt(
          SupabaseAppointmentsTable.updatedAt,
          adjustedTime.toIso8601String(),
        );
      }

      final updatesData = await query;

      // 3. Fetch ALL IDs to handle DELETIONS
      final allRemoteIdsData = await supabase
          ?.from(SupabaseSchema.appointments.tableName)
          .select(SupabaseAppointmentsTable.id) ?? [];

      final remoteIds = List<Map<String, dynamic>>.from(
        allRemoteIdsData,
      ).map((final e) => e[SupabaseAppointmentsTable.id] as String).toSet();

      await db.transaction(() async {
        // A. Apply Updates/Inserts
        if (updatesData.isNotEmpty) {
          await db.batch((final batch) {
            final companions = updatesData.map(_mapSupabaseDataToCompanion);
            batch.insertAllOnConflictUpdate(db.appointmentsTable, companions);
          });
          _log.info('Synced ${updatesData.length} updated/new appointments.');
        }

        // B. Handle Deletions - CRITICAL: Non cancellare record creati dopo l'ultimo sync
        if (remoteIds.isNotEmpty) {
          final lastSyncThreshold = lastSync ?? DateTime(2000).toUtc();
          await (db.delete(db.appointmentsTable)..where(
                (final t) =>
                    t.id.isNotIn(remoteIds) &
                    t.createdAt.isSmallerThan(Variable(lastSyncThreshold)),
              )).go();
        } else if (updatesData.isEmpty && allRemoteIdsData.isEmpty && lastSync != null) {
          // Solo se c'è stato almeno un sync prima
          await (db.delete(db.appointmentsTable)
            ..where((final t) => t.createdAt.isSmallerThan(Variable(lastSync!)))).go();
        }

        // C. Sync Appointment Services
        await _pullAppointmentServices();
      });

      await updateLastSyncTime(kLastSyncTimeAppointmentsKey);
    } catch (e, stackTrace) {
      _log.warning('Pull from Supabase failed', e, stackTrace);
    }
  }

  @override
  void startRealtimeSync() {
    if (!isOnline) return;

    subscribeToChannel(
      table: SupabaseSchema.appointments,
      onEvent: _handleAppointmentChange,
    );

    subscribeToChannel(
      table: SupabaseSchema.appointmentServices,
      onEvent: _handleAppointmentServiceChange,
    );

    _log.info('Realtime sync started for appointments and services');
  }

  // ========================================================================
  // REALTIME EVENT HANDLER
  // ========================================================================

  Future<void> _handleAppointmentChange(
    final PostgresChangePayload payload,
  ) async {
    try {
      switch (payload.eventType) {
        case PostgresChangeEvent.insert:
        case PostgresChangeEvent.update:
          final data = payload.newRecord;

          await db
              .into(db.appointmentsTable)
              .insertOnConflictUpdate(_mapSupabaseDataToCompanion(data));

          _log.finest(
            'Appointment ${data[SupabaseAppointmentsTable.id]} synced from realtime',
          );

        // case PostgresChangeEvent.delete:
        //   final oldData = payload.oldRecord;
        //   final id = oldData[SupabaseAppointmentsTable.id] as String;
        //
        //   await (db.delete(
        //     db.appointmentsTable,
        //   )..where((final t) => t.id.equals(id))).go();
        //   _log.finest('Appointment $id deleted from realtime');

        case PostgresChangeEvent.delete:
        case PostgresChangeEvent.all:
          throw UnimplementedError('PostgresChangeEvent.all not supported');
      }
    } catch (e, stackTrace) {
      _log.warning('Failed to handle appointment change', e, stackTrace);
    }
  }

  // ========================================================================
  // PRIVATE SYNC HELPERS
  // ========================================================================

  AppointmentsTableCompanion _mapSupabaseDataToCompanion(
    final Map<String, dynamic> data,
  ) => AppointmentsTableCompanion.insert(
    id: Value(data[SupabaseAppointmentsTable.id] as String),
    operatorId: Value(data[SupabaseAppointmentsTable.operatorId] as int?),
    clientId: Value(data[SupabaseAppointmentsTable.clientId] as String?),
    cabinId: Value(data[SupabaseAppointmentsTable.cabinId] as int?),
    startDateTime: DateTime.parse(
      data[SupabaseAppointmentsTable.startDateTime] as String,
    ).toLocal(),
    endDateTime: DateTime.parse(
      data[SupabaseAppointmentsTable.endDateTime] as String,
    ).toLocal(),
    notes: Value(data[SupabaseAppointmentsTable.notes] as String?),
    discount: Value(
      (data[SupabaseAppointmentsTable.discount] as num?)?.toDouble() ?? 0.0,
    ),
    discountReason: Value(
      data[SupabaseAppointmentsTable.discountReason] as String?,
    ),
    isActive: Value(data[SupabaseAppointmentsTable.isActive] as bool? ?? true),
    createdAt: Value(
      DateTime.parse(
        data[SupabaseAppointmentsTable.createdAt] as String,
      ).toLocal(),
    ),
    updatedAt: Value(
      DateTime.parse(
        data[SupabaseAppointmentsTable.updatedAt] as String,
      ).toLocal(),
    ),
  );

  /// Sincronizza forzatamente un appuntamento a Supabase
  /// Usato da PaymentsRepository per risolvere dipendenze FK
  Future<void> syncEntityToSupabase(final String id) async {
    try {
      final appointment = await getAppointmentById(id);
      if (appointment == null) {
        _log.warning('Cannot sync appointment $id: not found in local DB');
        return;
      }

      // Sync appuntamento principale
      await _syncAppointmentToSupabase(appointment);

      // Sync anche i servizi associati (indipendente dal successo dell'appuntamento)
      try {
        final services = await getAppointmentServicesByAppointmentId(id);
        for (final service in services) {
          await _syncAppointmentServiceToSupabase(service.id);
        }
        _log.finest('Synced ${services.length} services for appointment $id');
      } catch (servicesError) {
        _log.warning(
          'Failed to sync services for appointment $id',
          servicesError,
        );
        // Non rilanciare - l'appuntamento principale è già stato sincronizzato
      }
    } catch (e, stackTrace) {
      _log.warning('Failed to sync appointment $id to Supabase', e, stackTrace);
      rethrow; // Rilancia per permettere retry
    }
  }

  Future<void> _syncAppointmentToSupabase(
    final AppointmentData appointment,
  ) async {
    try {
      await supabase?.from(SupabaseSchema.appointments.tableName).upsert({
        SupabaseAppointmentsTable.id: appointment.id,
        SupabaseAppointmentsTable.operatorId: appointment.operatorId,
        SupabaseAppointmentsTable.clientId: appointment.clientId,
        SupabaseAppointmentsTable.cabinId: appointment.cabinId,
        SupabaseAppointmentsTable.startDateTime: appointment.startDateTime
            .toUtc()
            .toIso8601String(),
        SupabaseAppointmentsTable.endDateTime: appointment.endDateTime
            .toUtc()
            .toIso8601String(),
        SupabaseAppointmentsTable.notes: appointment.notes,
        SupabaseAppointmentsTable.discount: appointment.discount,
        SupabaseAppointmentsTable.discountReason: appointment.discountReason,
        SupabaseAppointmentsTable.createdAt: appointment.createdAt
            .toUtc()
            .toIso8601String(),
        SupabaseAppointmentsTable.updatedAt: appointment.updatedAt
            .toUtc()
            .toIso8601String(),
        SupabaseAppointmentsTable.isActive: appointment.isActive,
      });
    } catch (e, stackTrace) {
      _log.warning(
        'Failed to sync appointment ${appointment.id} to Supabase',
        e,
        stackTrace,
      );
    }
  }

  Future<void> _deleteAppointmentFromSupabase(
    final AppointmentData appointment,
  ) async {
    try {
      await supabase
          ?.from(SupabaseSchema.appointments.tableName)
          .update({SupabaseAppointmentsTable.isActive: false})
          .eq(SupabaseAppointmentsTable.id, appointment.id);
    } catch (e, stackTrace) {
      _log.warning(
        'Failed to delete appointment ${appointment.id} from Supabase',
        e,
        stackTrace,
      );
    }
  }

  Future<void> _syncAppointmentServiceToSupabase(final String id) async {
    try {
      final service = await (db.select(
        db.appointmentServicesTable,
      )..where((final t) => t.id.equals(id))).getSingleOrNull();
      if (service == null) return;

      await supabase?.from(SupabaseSchema.appointmentServices.tableName).upsert(
        {
          SupabaseAppointmentServicesTable.id: service.id,
          SupabaseAppointmentServicesTable.appointmentId: service.appointmentId,
          SupabaseAppointmentServicesTable.serviceId: service.serviceId,
          SupabaseAppointmentServicesTable.lockedPrice: service.lockedPrice,
          SupabaseAppointmentServicesTable.lockedDuration:
              service.lockedDuration,
          SupabaseAppointmentServicesTable.packageItemId: service.packageItemId,
          SupabaseAppointmentServicesTable.fidelityCardId:
              service.fidelityCardId,
          SupabaseAppointmentServicesTable.paymentSource: service.paymentSource,
        },
      );
    } catch (e, stackTrace) {
      _log.warning(
        'Failed to sync appointment service $id to Supabase',
        e,
        stackTrace,
      );
    }
  }

  Future<void> _deleteAppointmentServicesFromSupabase(
    final String appointmentId,
  ) async {
    try {
      await supabase
          ?.from(SupabaseSchema.appointmentServices.tableName)
          .delete()
          .eq(SupabaseAppointmentServicesTable.appointmentId, appointmentId);
    } catch (e, stackTrace) {
      _log.warning(
        'Failed to delete appointment services for $appointmentId from Supabase',
        e,
        stackTrace,
      );
    }
  }

  // ========================================================================
  // APPOINTMENT SERVICES PULL SYNC
  // ========================================================================

  Future<void> _pullAppointmentServices() async {
    try {
      final lastSync = await getLastSyncTime(
        kLastSyncTimeAppointmentServicesKey,
      );

      final query = supabase?.from(SupabaseSchema.appointmentServices.tableName).select();
      if (query == null) {
        _log.warning('Cannot pull appointment services: Supabase client is null');
        return;
      }

      // Note: appointment_services doesn't have updated_at, so we pull all data every time
      // This is acceptable as appointment_services are relatively small in number
      final updatesData = await query;

      final allRemoteIdsData = await supabase
          ?.from(SupabaseSchema.appointmentServices.tableName)
          .select(SupabaseAppointmentServicesTable.id) ?? [];

      final remoteIds = List<Map<String, dynamic>>.from(allRemoteIdsData)
          .map((final e) => e[SupabaseAppointmentServicesTable.id] as String)
          .toSet();

      if (updatesData.isNotEmpty) {
        await db.batch((final batch) {
          final companions = updatesData.map(_mapAppointmentServiceToCompanion);
          batch.insertAllOnConflictUpdate(
            db.appointmentServicesTable,
            companions,
          );
        });
        _log.info(
          'Synced ${updatesData.length} updated/new appointment services.',
        );
      }

      if (remoteIds.isNotEmpty) {
        await (db.delete(
          db.appointmentServicesTable,
        )..where((final t) => t.id.isNotIn(remoteIds))).go();
      } else if (updatesData.isEmpty) {
        await db.delete(db.appointmentServicesTable).go();
      }

      await updateLastSyncTime(kLastSyncTimeAppointmentServicesKey);
    } catch (e, stackTrace) {
      _log.warning('Failed to pull appointment services', e, stackTrace);
    }
  }

  AppointmentServicesTableCompanion _mapAppointmentServiceToCompanion(
    final Map<String, dynamic> data,
  ) => AppointmentServicesTableCompanion.insert(
    id: Value(data[SupabaseAppointmentServicesTable.id] as String),
    appointmentId:
        data[SupabaseAppointmentServicesTable.appointmentId] as String,
    serviceId: data[SupabaseAppointmentServicesTable.serviceId] as String,
    lockedPrice:
        (data[SupabaseAppointmentServicesTable.lockedPrice] as num?)
            ?.toDouble() ??
        0,
    lockedDuration:
        data[SupabaseAppointmentServicesTable.lockedDuration] as int? ?? 30,
    packageItemId: Value(
      data[SupabaseAppointmentServicesTable.packageItemId] as String?,
    ),
    fidelityCardId: Value(
      data[SupabaseAppointmentServicesTable.fidelityCardId] as String?,
    ),
    paymentSource: Value(
      data[SupabaseAppointmentServicesTable.paymentSource] as String? ??
          'direct',
    ),
  );

  // ========================================================================
  // APPOINTMENT SERVICES REALTIME HANDLER
  // ========================================================================

  Future<void> _handleAppointmentServiceChange(
    final PostgresChangePayload payload,
  ) async {
    try {
      switch (payload.eventType) {
        case PostgresChangeEvent.insert:
        case PostgresChangeEvent.update:
          final data = payload.newRecord;
          await db
              .into(db.appointmentServicesTable)
              .insertOnConflictUpdate(_mapAppointmentServiceToCompanion(data));
          _log.finest(
            'Appointment service ${data[SupabaseAppointmentServicesTable.id]} synced from realtime',
          );

        case PostgresChangeEvent.delete:
          final oldData = payload.oldRecord;
          final id = oldData[SupabaseAppointmentServicesTable.id] as String;
          await (db.delete(
            db.appointmentServicesTable,
          )..where((final t) => t.id.equals(id))).go();
          _log.finest('Appointment service $id deleted from realtime');

        case PostgresChangeEvent.all:
          throw UnimplementedError('PostgresChangeEvent.all not supported');
      }
    } catch (e, stackTrace) {
      _log.warning(
        'Failed to handle appointment service change',
        e,
        stackTrace,
      );
    }
  }
}
