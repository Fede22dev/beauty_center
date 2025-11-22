import 'package:beauty_center/core/constants/app_constants.dart';
import 'package:drift/drift.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../../core/contacts/contact_sync_helper.dart';
import '../../../../core/database/app_database.dart';
import '../../../../core/database/repositories/base_repository.dart';
import '../../../../core/database/supabase_schema.dart';
import '../../../../core/utils/navigator_key.dart';

/// Repository for clients management
/// Implements offline-first pattern with Supabase sync
class ClientsRepository extends BaseRepository {
  ClientsRepository({
    required super.db,
    required super.supabase,
    required super.isOnline,
  });

  static const kLastSyncKey = 'last_sync_clients';

  List<OrderingTerm Function(ClientsTable)> get _defaultOrdering => [
    (final t) => OrderingTerm.asc(t.firstName),
    (final t) => OrderingTerm.asc(t.lastName),
  ];

  // ========================================================================
  // CLIENTS - QUERIES (Read operations - always from local DB)
  // ========================================================================

  /// Get all clients ordered
  Future<List<Client>> getAllClients() =>
      (db.select(db.clientsTable)..orderBy(_defaultOrdering)).get();

  /// Watch clients stream for reactive UI updates
  Stream<List<Client>> watchClients() =>
      (db.select(db.clientsTable)..orderBy(_defaultOrdering)).watch();

  /// Get client by ID
  Future<Client?> getClientById(final String id) => (db.select(
    db.clientsTable,
  )..where((final t) => t.id.equals(id))).getSingleOrNull();

  /// Watch client by ID for reactive UI updates
  Stream<Client?> watchClientById(final String id) => (db.select(
    db.clientsTable,
  )..where((final t) => t.id.equals(id))).watchSingleOrNull();

  /// Search clients by name, phone or email
  Future<List<Client>> searchClients(final String query) {
    final searchTerm = '%${query.trim().toLowerCase()}%';
    return (db.select(db.clientsTable)
          ..where(
            (final t) =>
                t.firstName.lower().like(searchTerm) |
                t.lastName.lower().like(searchTerm) |
                t.phoneNumber.like(searchTerm) |
                t.email.like(searchTerm),
          )
          ..orderBy(_defaultOrdering))
        .get();
  }

  /// Get total clients count
  Future<int> getClientsCount() async {
    final countExp = db.clientsTable.id.count();
    final query = db.selectOnly(db.clientsTable)..addColumns([countExp]);
    return await query.map((final row) => row.read(countExp)).getSingle() ?? 0;
  }

  // ========================================================================
  // CLIENTS - CRUD (Write operations - sync with Supabase)
  // ========================================================================

  /// Create new client
  Future<String> createClient({
    required final String firstName,
    required final String lastName,
    required final String phoneNumber,
    final String? email,
    final DateTime? birthDate,
    final String? address,
    final String? notes,
  }) async {
    if (firstName.trim().isEmpty || lastName.trim().isEmpty) {
      throw ArgumentError('First name and last name are required');
    }
    if (phoneNumber.trim().isEmpty) {
      throw ArgumentError('Phone number is required');
    }

    final now = DateTime.now().toUtc();

    // Insert to local DB first (offline-first)
    final insertedClient = await db
        .into(db.clientsTable)
        .insertReturning(
          ClientsTableCompanion.insert(
            firstName: firstName.trim(),
            lastName: lastName.trim(),
            phoneNumber: phoneNumber.trim(),
            email: Value(email?.trim()),
            birthDate: Value(birthDate),
            address: Value(address?.trim()),
            notes: Value(notes?.trim()),
            createdAt: Value(now),
            updatedAt: Value(now),
          ),
        );

    // Non-blocking sync to Supabase
    syncAsync(() => _syncClientToSupabase(insertedClient.id));

    return insertedClient.id;
  }

  /// Update client information
  Future<void> updateClient({
    required final String id,
    required final String firstName,
    required final String lastName,
    required final String phoneNumber,
    final String? email,
    final DateTime? birthDate,
    final String? address,
    final String? notes,
  }) async {
    final companion = ClientsTableCompanion(
      firstName: Value(firstName.trim()),
      lastName: Value(lastName.trim()),
      phoneNumber: Value(phoneNumber.trim()),
      email: Value(email?.trim()),
      birthDate: Value(birthDate),
      address: Value(address?.trim()),
      notes: Value(notes?.trim()),
      updatedAt: Value(DateTime.now().toUtc()),
    );

    await (db.update(
      db.clientsTable,
    )..where((final t) => t.id.equals(id))).write(companion);

    syncAsync(() => _syncClientToSupabase(id));
  }

  /// Delete client
  Future<void> deleteClient(final String id) async {
    await (db.delete(
      db.clientsTable,
    )..where((final t) => t.id.equals(id))).go();

    syncAsync(() => _deleteClientFromSupabase(id));
  }

  // ========================================================================
  // SYNC IMPLEMENTATION (BaseRepository overrides)
  // ========================================================================

  @override
  Future<void> pushLocalToSupabase() async {
    // Not needed for clients - data is created by user input
    // No default data to push
  }

  @override
  Future<void> pullSupabaseToLocal() async {
    if (!isOnline) return;

    try {
      // 1. Get the last time we synced
      final lastSync = await getLastSyncTime(kLastSyncKey);

      // 2. Fetch UPDATES/INSERTS (Delta Sync)
      // If lastSync is null, we fetch everything.
      // If lastSync exists, we only fetch what changed since then.
      var query = supabase!.from(SupabaseSchema.clients.tableName).select();

      if (lastSync != null) {
        // Buffer of 1 minute to ensure we don't miss edge cases with clock skew
        final adjustedTime = lastSync.subtract(const Duration(minutes: 1));
        query = query.gt(
          SupabaseClientsTable.updatedAt,
          adjustedTime.toIso8601String(),
        );
      }

      final updatesData = await query;

      // 3. Fetch ALL IDs to handle DELETIONS (Hard Delete Check)
      final allRemoteIdsData = await supabase!
          .from(SupabaseSchema.clients.tableName)
          .select(SupabaseClientsTable.id);

      final remoteIds = List<Map<String, dynamic>>.from(
        allRemoteIdsData,
      ).map((final e) => e[SupabaseClientsTable.id] as String).toSet();

      await db.transaction(() async {
        // A. Apply Updates/Inserts
        if (updatesData.isNotEmpty) {
          await db.batch((final batch) {
            final companions = updatesData.map(_mapSupabaseDataToCompanion);
            batch.insertAllOnConflictUpdate(db.clientsTable, companions);
          });
          log.info('Synced ${updatesData.length} updated/new clients.');
        }

        // B. Handle Deletions (Orphan Removal)
        if (remoteIds.isNotEmpty) {
          await (db.delete(
            db.clientsTable,
          )..where((final t) => t.id.isNotIn(remoteIds))).go();
        } else if (updatesData.isEmpty) {
          // Edge case: Server is completely empty
          await db.delete(db.clientsTable).go();
        }

        // C. Update Contacts (Mobile only)
        if (!kIsWindows && updatesData.isNotEmpty) {
          await Future.microtask(() async {
            final context = navigatorKey.currentContext;
            if (context != null && context.mounted) {
              await ContactSyncHelper.syncAllPersonsToContacts(
                context,
                updatesData,
              );
            }
          });
        }
      });

      // 4. Update timestamp
      await updateLastSyncTime(kLastSyncKey);
    } catch (e, stackTrace) {
      log.warning('Pull from Supabase failed', e, stackTrace);
      // Important: Do not update timestamp if sync failed
    }
  }

  @override
  void startRealtimeSync() {
    if (!isOnline) return;

    subscribeToChannel(
      table: SupabaseSchema.clients,
      onEvent: _handleClientChange,
    );

    log.info('Realtime sync started for clients');
  }

  // ========================================================================
  // REALTIME EVENT HANDLER
  // ========================================================================

  Future<void> _handleClientChange(final PostgresChangePayload payload) async {
    try {
      final context = navigatorKey.currentContext;

      switch (payload.eventType) {
        case PostgresChangeEvent.insert:
        case PostgresChangeEvent.update:
          final data = payload.newRecord;

          await db
              .into(db.clientsTable)
              .insertOnConflictUpdate(_mapSupabaseDataToCompanion(data));

          log.fine(
            'Client ${data[SupabaseClientsTable.id]} synced from realtime',
          );

          // Sync contacts to device
          if (!kIsWindows && context != null && context.mounted) {
            syncAsync(() async {
              await ContactSyncHelper.syncPersonToContact(
                context: context,
                firstName: data[SupabaseClientsTable.firstName] as String,
                lastName: data[SupabaseClientsTable.lastName] as String,
                phoneNumber: data[SupabaseClientsTable.phoneNumber] as String,
                email: data[SupabaseClientsTable.email] as String?,
              );
            });
          }

        case PostgresChangeEvent.delete:
          final oldData = payload.oldRecord;
          final id = oldData[SupabaseClientsTable.id] as String;

          await (db.delete(
            db.clientsTable,
          )..where((final t) => t.id.equals(id))).go();
          log.fine('Client $id deleted from realtime');

          final phoneNumber =
              oldData[SupabaseClientsTable.phoneNumber] as String?;

          if (!kIsWindows &&
              phoneNumber != null &&
              context != null &&
              context.mounted) {
            syncAsync(() async {
              await ContactSyncHelper.deletePersonFromContacts(
                context: context,
                phoneNumber: phoneNumber,
              );
            });
          }

        case PostgresChangeEvent.all:
          throw UnimplementedError('PostgresChangeEvent.all not supported');
      }
    } catch (e, stackTrace) {
      log.warning('Failed to handle client change', e, stackTrace);
    }
  }

  // ========================================================================
  // PRIVATE SYNC HELPERS
  // ========================================================================

  ClientsTableCompanion _mapSupabaseDataToCompanion(
    final Map<String, dynamic> data,
  ) => ClientsTableCompanion.insert(
    id: Value(data[SupabaseClientsTable.id] as String),
    firstName: data[SupabaseClientsTable.firstName] as String,
    lastName: data[SupabaseClientsTable.lastName] as String,
    phoneNumber: data[SupabaseClientsTable.phoneNumber] as String,
    email: Value(data[SupabaseClientsTable.email] as String?),
    birthDate: data[SupabaseClientsTable.birthDate] != null
        ? Value(
            DateTime.tryParse(data[SupabaseClientsTable.birthDate] as String),
          )
        : const Value.absent(),
    address: Value(data[SupabaseClientsTable.address] as String?),
    notes: Value(data[SupabaseClientsTable.notes] as String?),
    createdAt: Value(
      DateTime.parse(data[SupabaseClientsTable.createdAt] as String),
    ),
    updatedAt: Value(
      DateTime.parse(data[SupabaseClientsTable.updatedAt] as String),
    ),
  );

  Future<void> _syncClientToSupabase(final String id) async {
    try {
      final client = await getClientById(id);
      if (client == null) return;

      await supabase?.from(SupabaseSchema.clients.tableName).upsert({
        SupabaseClientsTable.id: client.id,
        SupabaseClientsTable.firstName: client.firstName,
        SupabaseClientsTable.lastName: client.lastName,
        SupabaseClientsTable.phoneNumber: client.phoneNumber,
        SupabaseClientsTable.email: client.email,
        SupabaseClientsTable.birthDate: client.birthDate?.toIso8601String(),
        SupabaseClientsTable.address: client.address,
        SupabaseClientsTable.notes: client.notes,
        SupabaseClientsTable.createdAt: client.createdAt
            .toUtc()
            .toIso8601String(),
        SupabaseClientsTable.updatedAt: client.updatedAt
            .toUtc()
            .toIso8601String(),
      });
    } catch (e, stackTrace) {
      log.warning('Failed to sync client $id to Supabase', e, stackTrace);
    }
  }

  Future<void> _deleteClientFromSupabase(final String id) async {
    try {
      await supabase
          ?.from(SupabaseSchema.clients.tableName)
          .delete()
          .eq(SupabaseClientsTable.id, id);
    } catch (e, stackTrace) {
      log.warning('Failed to delete client $id from Supabase', e, stackTrace);
    }
  }
}
