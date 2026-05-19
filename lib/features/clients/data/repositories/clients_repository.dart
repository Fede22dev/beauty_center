import '../../../../core/constants/app_constants.dart';
import 'package:drift/drift.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:uuid/uuid.dart';

import '../../../../core/contacts/contact_sync_helper.dart';
import '../../../../core/database/app_database.dart';
import '../../../../core/database/repositories/base_repository.dart';
import '../../../../core/database/supabase_schema.dart';
import '../../../../core/logging/app_logger.dart';
import '../../../../core/utils/navigator_key.dart';

/// Repository for clients management
/// Implements offline-first pattern with Supabase sync
class ClientsRepository extends BaseRepository {
  ClientsRepository({
    required super.db,
    required super.supabase,
    required super.isOnline,
  });

  static final _log = AppLogger.getLogger(name: 'ClientsRepository');

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
  Stream<List<Client>> watchAllClients() =>
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
  /// Returns client ID or null on error
  /// Note: Works offline - sync to Supabase happens in background
  Future<String?> createClient({
    required final String firstName,
    required final String lastName,
    required final String phoneNumber,
    final String? email,
    final DateTime? birthDate,
    final String? address,
    final String? notes,
  }) async {
    final now = DateTime.now().toUtc();

    // Insert to local DB first (offline-first)
    final insertedClient = await db
        .into(db.clientsTable)
        .insertReturning(
          ClientsTableCompanion.insert(
            id: Value(const Uuid().v7()),
            firstName: firstName.trim(),
            lastName: lastName.trim(),
            phoneNumber: phoneNumber.trim(),
            email: Value(email?.trim()),
            birthDate: Value(birthDate),
            address: Value(address?.trim()),
            notes: Value(notes?.trim()),
            createdAt: Value(now),
            updatedAt: Value(now),
            isActive: const Value(true),
          ),
        );

    _log.info('Client ${insertedClient.id} created locally, scheduling sync...');
    
    // Esegui sync in background con retry robusto
    await _triggerSyncWithDebounce(insertedClient.id);

    return insertedClient.id;
  }

  /// Update client information
  /// Returns true if successful, false if offline (read-only mode)
  Future<bool> updateClient({
    required final String id,
    required final String firstName,
    required final String lastName,
    required final String phoneNumber,
    final String? email,
    final DateTime? birthDate,
    final String? address,
    final String? notes,
  }) async {
    if (!isOnline) {
      _log.warning('Cannot update client: offline mode (read-only)');
      return false;
    }
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

    syncAsync('client_$id', () => _syncClientToSupabase(id));
    return true;
  }

  /// Delete client
  /// Returns true if successful, false if offline (read-only mode)
  Future<bool> deleteClient(final String id) async {
    if (!isOnline) {
      _log.warning('Cannot delete client: offline mode (read-only)');
      return false;
    }

    await (db.delete(
      db.clientsTable,
    )..where((final t) => t.id.equals(id))).go();

    syncAsync('delete_client_$id', () => _deleteClientFromSupabase(id));
    return true;
  }

  // ========================================================================
  // SYNC HELPER - Robust sync with retry
  // ========================================================================

  /// Trigger sync con debounce e retry robusto
  Future<void> _triggerSyncWithDebounce(final String clientId) async {
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

        _log.finest('Sync attempt $attempt/$maxAttempts for client $clientId');
        await syncEntityToSupabase(clientId);
        
        _log.info('Client $clientId synced successfully on attempt $attempt');
        return;
        
      } catch (e) {
        _log.warning('Sync attempt $attempt failed: $e');
        await Future.delayed(Duration(seconds: attempt * 2));
      }
    }

    _log.warning('Client $clientId failed to sync after $maxAttempts attempts');
  }

  // ========================================================================
  // SYNC IMPLEMENTATION (BaseRepository overrides)
  // ========================================================================
  @override
  Future<void> pullSupabaseToLocal() async {
    // CRITICAL: Verifica che supabase sia disponibile
    if (supabase == null) {
      _log.warning('Cannot pull clients: Supabase client is null');
      return;
    }

    try {
      // 1. Get the last time we synced
      final lastSync = await getLastSyncTime(kLastSyncTimeClientsKey);

      // 2. Fetch UPDATES/INSERTS (Delta Sync)
      var query = supabase?.from(SupabaseSchema.clients.tableName).select();
      if (query == null) {
        _log.warning('Cannot pull clients: Supabase client is null');
        return;
      }

      if (lastSync != null) {
        final adjustedTime = lastSync.subtract(kLastSyncBufferDuration);
        query = query.gt(
          SupabaseClientsTable.updatedAt,
          adjustedTime.toIso8601String(),
        );
      }

      final updatesData = await query;

      // 3. Fetch ALL IDs to handle DELETIONS
      final allRemoteIdsData = await supabase
          ?.from(SupabaseSchema.clients.tableName)
          .select(SupabaseClientsTable.id) ?? [];

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
          _log.info('Synced ${updatesData.length} updated/new clients.');
        }

        // B. Handle Deletions - CRITICAL: Non cancellare record creati dopo l'ultimo sync
        if (remoteIds.isNotEmpty) {
          final lastSyncThreshold = lastSync ?? DateTime(2000).toUtc();
          await (db.delete(db.clientsTable)..where(
                (final t) =>
                    t.id.isNotIn(remoteIds) &
                    t.createdAt.isSmallerThan(Variable(lastSyncThreshold)),
              )).go();
        } else if (updatesData.isEmpty && lastSync != null) {
          // Solo se c'è stato almeno un sync prima
          await (db.delete(db.clientsTable)
            ..where((final t) => t.createdAt.isSmallerThan(Variable(lastSync)))).go();
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

        // D. Sync Client Tags
        await _pullClientTags();

        // E. Sync Client Technical Sheets
        await _pullClientTechnicalSheets();

        // F. Sync Client Product Blacklist
        await _pullClientProductBlacklist();
      });

      // 4. Update timestamp
      await updateLastSyncTime(kLastSyncTimeClientsKey);
    } catch (e, stackTrace) {
      _log.warning('Pull from Supabase failed', e, stackTrace);
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

    subscribeToChannel(
      table: SupabaseSchema.clientTags,
      onEvent: _handleClientTagChange,
    );

    subscribeToChannel(
      table: SupabaseSchema.clientTechnicalSheets,
      onEvent: _handleClientTechnicalSheetChange,
    );

    subscribeToChannel(
      table: SupabaseSchema.clientProductBlacklist,
      onEvent: _handleClientProductBlacklistChange,
    );

    _log.info('Realtime sync started for clients and related tables');
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

          _log.finest(
            'Client ${data[SupabaseClientsTable.id]} synced from realtime',
          );

          // Sync contacts to device
          if (!kIsWindows && context != null && context.mounted) {
            syncAsync(
              'sync_contact_${data[SupabaseClientsTable.id]}',
              () async {
                await ContactSyncHelper.syncPersonToContact(
                  context: context,
                  firstName: data[SupabaseClientsTable.firstName] as String,
                  lastName: data[SupabaseClientsTable.lastName] as String,
                  phoneNumber: data[SupabaseClientsTable.phoneNumber] as String,
                  email: data[SupabaseClientsTable.email] as String?,
                );
              },
            );
          }

        case PostgresChangeEvent.delete:
          final oldData = payload.oldRecord;
          final id = oldData[SupabaseClientsTable.id] as String;

          await (db.delete(
            db.clientsTable,
          )..where((final t) => t.id.equals(id))).go();
          _log.finest('Client $id deleted from realtime');

          final phoneNumber =
              oldData[SupabaseClientsTable.phoneNumber] as String?;

          if (!kIsWindows &&
              phoneNumber != null &&
              context != null &&
              context.mounted) {
            syncAsync('delete_contact_$phoneNumber', () async {
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
      _log.warning('Failed to handle client change', e, stackTrace);
    }
  }

  // ========================================================================
  // CLIENT TAGS
  // ========================================================================

  /// Get all tags for a client
  Future<List<ClientTagData>> getClientTags(final String clientId) =>
      (db.select(db.clientTagsTable)
            ..where((final t) => t.clientId.equals(clientId))
            ..orderBy([(final t) => OrderingTerm.asc(t.tag)]))
          .get();

  /// Watch client tags stream for reactive UI updates
  Stream<List<ClientTagData>> watchClientTags(final String clientId) =>
      (db.select(db.clientTagsTable)
            ..where((final t) => t.clientId.equals(clientId))
            ..orderBy([(final t) => OrderingTerm.asc(t.tag)]))
          .watch();

  /// Add a tag to a client
  /// Returns tag ID or null if offline
  Future<String?> addClientTag({
    required final String clientId,
    required final String tag,
    final String? colorHex,
  }) async {
    if (!isOnline) {
      _log.warning('Cannot add tag while offline');
      return null;
    }

    try {
      final id = const Uuid().v7();
      await db
          .into(db.clientTagsTable)
          .insert(
            ClientTagsTableCompanion.insert(
              id: Value(id),
              clientId: clientId,
              tag: tag.trim(),
              colorHex: Value(colorHex),
            ),
          );
      _log.finest('Tag added to client $clientId: $tag');

      // Sync to Supabase
      await _syncClientTagToSupabase(id);

      return id;
    } catch (e, stackTrace) {
      _log.warning('Failed to add tag to client $clientId', e, stackTrace);
      return null;
    }
  }

  /// Remove a tag from a client
  Future<bool> removeClientTag(final String tagId) async {
    if (!isOnline) {
      _log.warning('Cannot remove tag while offline');
      return false;
    }

    try {
      final tag = await (db.select(
        db.clientTagsTable,
      )..where((final t) => t.id.equals(tagId))).getSingleOrNull();

      if (tag == null) return false;

      await (db.delete(
        db.clientTagsTable,
      )..where((final t) => t.id.equals(tagId))).go();

      _log.finest('Tag removed: $tagId');

      // Delete from Supabase
      await _deleteClientTagFromSupabase(tagId);

      return true;
    } catch (e, stackTrace) {
      _log.warning('Failed to remove tag $tagId', e, stackTrace);
      return false;
    }
  }

  /// Get all unique tags used across all clients (for autocomplete)
  Future<List<String>> getAllUniqueTags() async {
    final query = db.selectOnly(db.clientTagsTable)
      ..addColumns([db.clientTagsTable.tag])
      ..groupBy([db.clientTagsTable.tag]);

    return query.map((final row) => row.read(db.clientTagsTable.tag)!).get();
  }

  Future<void> _syncClientTagToSupabase(final String id) async {
    try {
      final tag = await (db.select(
        db.clientTagsTable,
      )..where((final t) => t.id.equals(id))).getSingleOrNull();
      if (tag == null) return;

      await supabase?.from('client_tags').upsert({
        'id': tag.id,
        'client_id': tag.clientId,
        'tag': tag.tag,
        'color_hex': tag.colorHex,
        'created_at': tag.createdAt.toUtc().toIso8601String(),
      });
    } catch (e, stackTrace) {
      _log.warning('Failed to sync client tag $id to Supabase', e, stackTrace);
    }
  }

  Future<void> _deleteClientTagFromSupabase(final String id) async {
    try {
      await supabase?.from('client_tags').delete().eq('id', id);
    } catch (e, stackTrace) {
      _log.warning(
        'Failed to delete client tag $id from Supabase',
        e,
        stackTrace,
      );
    }
  }

  // ========================================================================
  // CLIENT TECHNICAL SHEET
  // ========================================================================

  /// Get technical sheet for a client (creates one if doesn't exist)
  Future<ClientTechnicalSheetData> getOrCreateTechnicalSheet(
    final String clientId,
  ) async {
    final existing = await (db.select(db.clientTechnicalSheetsTable)
          ..where((final t) => t.clientId.equals(clientId)))
        .getSingleOrNull();

    if (existing != null) return existing;

    // Create empty technical sheet if not exists
    final id = const Uuid().v7();
    await db.into(db.clientTechnicalSheetsTable).insert(
          ClientTechnicalSheetsTableCompanion.insert(
            id: Value(id),
            clientId: clientId,
            updatedAt: Value(DateTime.now().toUtc()),
          ),
        );

    return (db.select(db.clientTechnicalSheetsTable)
          ..where((final t) => t.id.equals(id)))
        .getSingle();
  }

  /// Watch technical sheet stream for reactive UI updates
  Stream<ClientTechnicalSheetData?> watchTechnicalSheet(final String clientId) =>
      (db.select(db.clientTechnicalSheetsTable)
            ..where((final t) => t.clientId.equals(clientId)))
          .watchSingleOrNull();

  /// Update technical sheet
  /// Returns true if successful, false if offline
  Future<bool> updateTechnicalSheet({
    required final String clientId,
    final String? skinType,
    final String? skinConditions,
    final String? allergies,
    final String? contraindications,
    final String? currentMedications,
    final String? previousTreatments,
    final String? machineSettings,
    final String? treatmentGoals,
    final String? medicalNotes,
    final bool? isPregnant,
    final bool? isBreastfeeding,
    final bool? hasSunSensitivity,
    final bool? hasHerpesHistory,
    final bool? hasKeloidTendency,
    final bool? hasDiabetes,
    final bool? hasPacemaker,
    final int? fitzpatrickType,
  }) async {
    if (!isOnline) {
      _log.warning('Cannot update technical sheet: offline mode');
      return false;
    }

    try {
      // Get or create technical sheet first
      final sheet = await getOrCreateTechnicalSheet(clientId);

      final companion = ClientTechnicalSheetsTableCompanion(
        skinType: skinType != null ? Value(skinType.trim()) : const Value.absent(),
        skinConditions: skinConditions != null ? Value(skinConditions.trim()) : const Value.absent(),
        allergies: allergies != null ? Value(allergies.trim()) : const Value.absent(),
        contraindications: contraindications != null ? Value(contraindications.trim()) : const Value.absent(),
        currentMedications: currentMedications != null ? Value(currentMedications.trim()) : const Value.absent(),
        previousTreatments: previousTreatments != null ? Value(previousTreatments.trim()) : const Value.absent(),
        machineSettings: machineSettings != null ? Value(machineSettings.trim()) : const Value.absent(),
        treatmentGoals: treatmentGoals != null ? Value(treatmentGoals.trim()) : const Value.absent(),
        medicalNotes: medicalNotes != null ? Value(medicalNotes.trim()) : const Value.absent(),
        isPregnant: isPregnant != null ? Value(isPregnant) : const Value.absent(),
        isBreastfeeding: isBreastfeeding != null ? Value(isBreastfeeding) : const Value.absent(),
        hasSunSensitivity: hasSunSensitivity != null ? Value(hasSunSensitivity) : const Value.absent(),
        hasHerpesHistory: hasHerpesHistory != null ? Value(hasHerpesHistory) : const Value.absent(),
        hasKeloidTendency: hasKeloidTendency != null ? Value(hasKeloidTendency) : const Value.absent(),
        hasDiabetes: hasDiabetes != null ? Value(hasDiabetes) : const Value.absent(),
        hasPacemaker: hasPacemaker != null ? Value(hasPacemaker) : const Value.absent(),
        fitzpatrickType: fitzpatrickType != null ? Value(fitzpatrickType) : const Value.absent(),
        updatedAt: Value(DateTime.now().toUtc()),
      );

      await (db.update(db.clientTechnicalSheetsTable)
            ..where((final t) => t.id.equals(sheet.id)))
          .write(companion);

      _log.finest('Technical sheet updated for client $clientId');

      // Sync to Supabase
      syncAsync('technical_sheet_$clientId', () => _syncTechnicalSheetToSupabase(sheet.id));

      return true;
    } catch (e, stackTrace) {
      _log.warning('Failed to update technical sheet for client $clientId', e, stackTrace);
      return false;
    }
  }

  Future<void> _syncTechnicalSheetToSupabase(final String id) async {
    try {
      final sheet = await (db.select(db.clientTechnicalSheetsTable)
            ..where((final t) => t.id.equals(id)))
          .getSingleOrNull();
      if (sheet == null) return;

      await supabase?.from('client_technical_sheets').upsert({
        'id': sheet.id,
        'client_id': sheet.clientId,
        'skin_type': sheet.skinType,
        'skin_conditions': sheet.skinConditions,
        'allergies': sheet.allergies,
        'contraindications': sheet.contraindications,
        'current_medications': sheet.currentMedications,
        'previous_treatments': sheet.previousTreatments,
        'machine_settings': sheet.machineSettings,
        'treatment_goals': sheet.treatmentGoals,
        'medical_notes': sheet.medicalNotes,
        'is_pregnant': sheet.isPregnant,
        'is_breastfeeding': sheet.isBreastfeeding,
        'has_sun_sensitivity': sheet.hasSunSensitivity,
        'has_herpes_history': sheet.hasHerpesHistory,
        'has_keloid_tendency': sheet.hasKeloidTendency,
        'has_diabetes': sheet.hasDiabetes,
        'has_pacemaker': sheet.hasPacemaker,
        'fitzpatrick_type': sheet.fitzpatrickType,
        'updated_at': sheet.updatedAt.toUtc().toIso8601String(),
      });
    } catch (e, stackTrace) {
      _log.warning('Failed to sync technical sheet $id to Supabase', e, stackTrace);
    }
  }

  // ========================================================================
  // CLIENT PRODUCT BLACKLIST
  // ========================================================================

  /// Get all blacklisted products for a client (with product details)
  Future<List<ClientProductBlacklistData>> getClientProductBlacklist(
    final String clientId,
  ) =>
      (db.select(db.clientProductBlacklistTable)
            ..where((final t) => t.clientId.equals(clientId))
            ..orderBy([(final t) => OrderingTerm.asc(t.createdAt)]))
          .get();

  /// Watch client product blacklist stream
  Stream<List<ClientProductBlacklistData>> watchClientProductBlacklist(
    final String clientId,
  ) =>
      (db.select(db.clientProductBlacklistTable)
            ..where((final t) => t.clientId.equals(clientId))
            ..orderBy([(final t) => OrderingTerm.asc(t.createdAt)]))
          .watch();

  /// Add a product to client's blacklist
  Future<String?> addProductToBlacklist({
    required final String clientId,
    required final String productId,
    final String? reason,
  }) async {
    if (!isOnline) {
      _log.warning('Cannot add to blacklist while offline');
      return null;
    }

    try {
      final id = const Uuid().v7();
      await db.into(db.clientProductBlacklistTable).insert(
            ClientProductBlacklistTableCompanion.insert(
              id: Value(id),
              clientId: clientId,
              productId: productId,
              reason: Value(reason),
            ),
          );
      _log.finest('Product $productId added to blacklist for client $clientId');
      return id;
    } catch (e, stackTrace) {
      _log.warning('Failed to add product to blacklist', e, stackTrace);
      return null;
    }
  }

  /// Remove a product from client's blacklist
  Future<bool> removeProductFromBlacklist(final String blacklistId) async {
    if (!isOnline) {
      _log.warning('Cannot remove from blacklist while offline');
      return false;
    }

    try {
      await (db.delete(db.clientProductBlacklistTable)
            ..where((final t) => t.id.equals(blacklistId)))
          .go();
      _log.finest('Product removed from blacklist: $blacklistId');
      return true;
    } catch (e, stackTrace) {
      _log.warning('Failed to remove product from blacklist', e, stackTrace);
      return false;
    }
  }

  /// Check if a product is blacklisted for a client
  Future<bool> isProductBlacklisted({
    required final String clientId,
    required final String productId,
  }) async {
    final result = await (db.select(db.clientProductBlacklistTable)
          ..where(
            (final t) =>
                t.clientId.equals(clientId) & t.productId.equals(productId),
          ))
        .getSingleOrNull();
    return result != null;
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
            DateTime.tryParse(
              data[SupabaseClientsTable.birthDate] as String,
            )?.toLocal(),
          )
        : const Value.absent(),
    address: Value(data[SupabaseClientsTable.address] as String?),
    notes: Value(data[SupabaseClientsTable.notes] as String?),
    createdAt: Value(
      DateTime.parse(data[SupabaseClientsTable.createdAt] as String).toLocal(),
    ),
    updatedAt: Value(
      DateTime.parse(data[SupabaseClientsTable.updatedAt] as String).toLocal(),
    ),
  );

  /// Sincronizza forzatamente un cliente a Supabase
  /// Usato da altri repository per risolvere dipendenze FK
  Future<void> syncEntityToSupabase(final String id) async {
    await _syncClientToSupabase(id);
  }

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
      _log.warning('Failed to sync client $id to Supabase', e, stackTrace);
    }
  }

  Future<void> _deleteClientFromSupabase(final String id) async {
    try {
      await supabase
          ?.from(SupabaseSchema.clients.tableName)
          .delete()
          .eq(SupabaseClientsTable.id, id);
    } catch (e, stackTrace) {
      _log.warning('Failed to delete client $id from Supabase', e, stackTrace);
    }
  }

  // ========================================================================
  // RELATED TABLES PULL SYNC
  // ========================================================================

  Future<void> _pullClientTags() async {
    try {
      final lastSync = await getLastSyncTime(kLastSyncTimeClientTagsKey);

      var query = supabase?.from(SupabaseSchema.clientTags.tableName).select();
      if (query == null) {
        _log.warning('Cannot pull client tags: Supabase client is null');
        return;
      }

      if (lastSync != null) {
        final adjustedTime = lastSync.subtract(kLastSyncBufferDuration);
        query = query.gt(
          SupabaseClientTagsTable.createdAt,
          adjustedTime.toIso8601String(),
        );
      }

      final updatesData = await query;

      final allRemoteIdsData = await supabase
          ?.from(SupabaseSchema.clientTags.tableName)
          .select(SupabaseClientTagsTable.id) ?? [];

      final remoteIds = List<Map<String, dynamic>>.from(
        allRemoteIdsData,
      ).map((final e) => e[SupabaseClientTagsTable.id] as String).toSet();

      if (updatesData.isNotEmpty) {
        await db.batch((final batch) {
          final companions = updatesData.map(_mapClientTagToCompanion);
          batch.insertAllOnConflictUpdate(db.clientTagsTable, companions);
        });
        _log.info('Synced ${updatesData.length} updated/new client tags.');
      }

      if (remoteIds.isNotEmpty) {
        await (db.delete(
          db.clientTagsTable,
        )..where((final t) => t.id.isNotIn(remoteIds))).go();
      } else if (updatesData.isEmpty) {
        await db.delete(db.clientTagsTable).go();
      }

      await updateLastSyncTime(kLastSyncTimeClientTagsKey);
    } catch (e, stackTrace) {
      _log.warning('Failed to pull client tags', e, stackTrace);
    }
  }

  Future<void> _pullClientTechnicalSheets() async {
    try {
      final lastSync = await getLastSyncTime(kLastSyncTimeClientTechnicalSheetsKey);

      var query = supabase?.from(SupabaseSchema.clientTechnicalSheets.tableName).select();
      if (query == null) {
        _log.warning('Cannot pull client technical sheets: Supabase client is null');
        return;
      }

      if (lastSync != null) {
        final adjustedTime = lastSync.subtract(kLastSyncBufferDuration);
        query = query.gt(
          SupabaseClientTechnicalSheetsTable.updatedAt,
          adjustedTime.toIso8601String(),
        );
      }

      final updatesData = await query;

      final allRemoteIdsData = await supabase
          ?.from(SupabaseSchema.clientTechnicalSheets.tableName)
          .select(SupabaseClientTechnicalSheetsTable.id) ?? [];

      final remoteIds = List<Map<String, dynamic>>.from(
        allRemoteIdsData,
      ).map((final e) => e[SupabaseClientTechnicalSheetsTable.id] as String).toSet();

      if (updatesData.isNotEmpty) {
        await db.batch((final batch) {
          final companions = updatesData.map(_mapTechnicalSheetToCompanion);
          batch.insertAllOnConflictUpdate(db.clientTechnicalSheetsTable, companions);
        });
        _log.info('Synced ${updatesData.length} updated/new technical sheets.');
      }

      if (remoteIds.isNotEmpty) {
        await (db.delete(
          db.clientTechnicalSheetsTable,
        )..where((final t) => t.id.isNotIn(remoteIds))).go();
      } else if (updatesData.isEmpty) {
        await db.delete(db.clientTechnicalSheetsTable).go();
      }

      await updateLastSyncTime(kLastSyncTimeClientTechnicalSheetsKey);
    } catch (e, stackTrace) {
      _log.warning('Failed to pull client technical sheets', e, stackTrace);
    }
  }

  Future<void> _pullClientProductBlacklist() async {
    try {
      final lastSync = await getLastSyncTime(kLastSyncTimeClientProductBlacklistKey);

      var query = supabase?.from(SupabaseSchema.clientProductBlacklist.tableName).select();
      if (query == null) {
        _log.warning('Cannot pull client product blacklist: Supabase client is null');
        return;
      }

      if (lastSync != null) {
        final adjustedTime = lastSync.subtract(kLastSyncBufferDuration);
        query = query.gt(
          SupabaseClientProductBlacklistTable.createdAt,
          adjustedTime.toIso8601String(),
        );
      }

      final updatesData = await query;

      final allRemoteIdsData = await supabase
          ?.from(SupabaseSchema.clientProductBlacklist.tableName)
          .select(SupabaseClientProductBlacklistTable.id) ?? [];

      final remoteIds = List<Map<String, dynamic>>.from(
        allRemoteIdsData,
      ).map((final e) => e[SupabaseClientProductBlacklistTable.id] as String).toSet();

      if (updatesData.isNotEmpty) {
        await db.batch((final batch) {
          final companions = updatesData.map(_mapProductBlacklistToCompanion);
          batch.insertAllOnConflictUpdate(db.clientProductBlacklistTable, companions);
        });
        _log.info('Synced ${updatesData.length} updated/new product blacklist entries.');
      }

      if (remoteIds.isNotEmpty) {
        await (db.delete(
          db.clientProductBlacklistTable,
        )..where((final t) => t.id.isNotIn(remoteIds))).go();
      } else if (updatesData.isEmpty) {
        await db.delete(db.clientProductBlacklistTable).go();
      }

      await updateLastSyncTime(kLastSyncTimeClientProductBlacklistKey);
    } catch (e, stackTrace) {
      _log.warning('Failed to pull client product blacklist', e, stackTrace);
    }
  }

  // ========================================================================
  // REALTIME HANDLERS FOR RELATED TABLES
  // ========================================================================

  Future<void> _handleClientTagChange(final PostgresChangePayload payload) async {
    try {
      switch (payload.eventType) {
        case PostgresChangeEvent.insert:
        case PostgresChangeEvent.update:
          final data = payload.newRecord;
          await db
              .into(db.clientTagsTable)
              .insertOnConflictUpdate(_mapClientTagToCompanion(data));
          _log.finest('Client tag ${data[SupabaseClientTagsTable.id]} synced from realtime');

        case PostgresChangeEvent.delete:
          final oldData = payload.oldRecord;
          final id = oldData[SupabaseClientTagsTable.id] as String;
          await (db.delete(
            db.clientTagsTable,
          )..where((final t) => t.id.equals(id))).go();
          _log.finest('Client tag $id deleted from realtime');

        case PostgresChangeEvent.all:
          throw UnimplementedError('PostgresChangeEvent.all not supported');
      }
    } catch (e, stackTrace) {
      _log.warning('Failed to handle client tag change', e, stackTrace);
    }
  }

  Future<void> _handleClientTechnicalSheetChange(final PostgresChangePayload payload) async {
    try {
      switch (payload.eventType) {
        case PostgresChangeEvent.insert:
        case PostgresChangeEvent.update:
          final data = payload.newRecord;
          await db
              .into(db.clientTechnicalSheetsTable)
              .insertOnConflictUpdate(_mapTechnicalSheetToCompanion(data));
          _log.finest('Technical sheet ${data[SupabaseClientTechnicalSheetsTable.id]} synced from realtime');

        case PostgresChangeEvent.delete:
          final oldData = payload.oldRecord;
          final id = oldData[SupabaseClientTechnicalSheetsTable.id] as String;
          await (db.delete(
            db.clientTechnicalSheetsTable,
          )..where((final t) => t.id.equals(id))).go();
          _log.finest('Technical sheet $id deleted from realtime');

        case PostgresChangeEvent.all:
          throw UnimplementedError('PostgresChangeEvent.all not supported');
      }
    } catch (e, stackTrace) {
      _log.warning('Failed to handle technical sheet change', e, stackTrace);
    }
  }

  Future<void> _handleClientProductBlacklistChange(final PostgresChangePayload payload) async {
    try {
      switch (payload.eventType) {
        case PostgresChangeEvent.insert:
        case PostgresChangeEvent.update:
          final data = payload.newRecord;
          await db
              .into(db.clientProductBlacklistTable)
              .insertOnConflictUpdate(_mapProductBlacklistToCompanion(data));
          _log.finest('Product blacklist ${data[SupabaseClientProductBlacklistTable.id]} synced from realtime');

        case PostgresChangeEvent.delete:
          final oldData = payload.oldRecord;
          final id = oldData[SupabaseClientProductBlacklistTable.id] as String;
          await (db.delete(
            db.clientProductBlacklistTable,
          )..where((final t) => t.id.equals(id))).go();
          _log.finest('Product blacklist $id deleted from realtime');

        case PostgresChangeEvent.all:
          throw UnimplementedError('PostgresChangeEvent.all not supported');
      }
    } catch (e, stackTrace) {
      _log.warning('Failed to handle product blacklist change', e, stackTrace);
    }
  }

  // ========================================================================
  // COMPANION MAPPERS FOR RELATED TABLES
  // ========================================================================

  ClientTagsTableCompanion _mapClientTagToCompanion(final Map<String, dynamic> data) =>
      ClientTagsTableCompanion.insert(
        id: Value(data[SupabaseClientTagsTable.id] as String),
        clientId: data[SupabaseClientTagsTable.clientId] as String,
        tag: data[SupabaseClientTagsTable.tag] as String,
        colorHex: Value(data[SupabaseClientTagsTable.colorHex] as String?),
        createdAt: Value(
          DateTime.parse(data[SupabaseClientTagsTable.createdAt] as String).toLocal(),
        ),
      );

  ClientTechnicalSheetsTableCompanion _mapTechnicalSheetToCompanion(
    final Map<String, dynamic> data,
  ) =>
      ClientTechnicalSheetsTableCompanion.insert(
        id: Value(data[SupabaseClientTechnicalSheetsTable.id] as String),
        clientId: data[SupabaseClientTechnicalSheetsTable.clientId] as String,
        skinType: Value(data[SupabaseClientTechnicalSheetsTable.skinType] as String?),
        skinConditions: Value(data[SupabaseClientTechnicalSheetsTable.skinConditions] as String?),
        allergies: Value(data[SupabaseClientTechnicalSheetsTable.allergies] as String?),
        contraindications: Value(data[SupabaseClientTechnicalSheetsTable.contraindications] as String?),
        currentMedications: Value(data[SupabaseClientTechnicalSheetsTable.currentMedications] as String?),
        previousTreatments: Value(data[SupabaseClientTechnicalSheetsTable.previousTreatments] as String?),
        machineSettings: Value(data[SupabaseClientTechnicalSheetsTable.machineSettings] as String?),
        treatmentGoals: Value(data[SupabaseClientTechnicalSheetsTable.treatmentGoals] as String?),
        medicalNotes: Value(data[SupabaseClientTechnicalSheetsTable.medicalNotes] as String?),
        isPregnant: Value(data[SupabaseClientTechnicalSheetsTable.isPregnant] as bool? ?? false),
        isBreastfeeding: Value(data[SupabaseClientTechnicalSheetsTable.isBreastfeeding] as bool? ?? false),
        hasSunSensitivity: Value(data[SupabaseClientTechnicalSheetsTable.hasSunSensitivity] as bool? ?? false),
        hasHerpesHistory: Value(data[SupabaseClientTechnicalSheetsTable.hasHerpesHistory] as bool? ?? false),
        hasKeloidTendency: Value(data[SupabaseClientTechnicalSheetsTable.hasKeloidTendency] as bool? ?? false),
        hasDiabetes: Value(data[SupabaseClientTechnicalSheetsTable.hasDiabetes] as bool? ?? false),
        hasPacemaker: Value(data[SupabaseClientTechnicalSheetsTable.hasPacemaker] as bool? ?? false),
        fitzpatrickType: Value(data[SupabaseClientTechnicalSheetsTable.fitzpatrickType] as int?),
        updatedAt: Value(
          DateTime.parse(data[SupabaseClientTechnicalSheetsTable.updatedAt] as String).toLocal(),
        ),
      );

  ClientProductBlacklistTableCompanion _mapProductBlacklistToCompanion(
    final Map<String, dynamic> data,
  ) =>
      ClientProductBlacklistTableCompanion.insert(
        id: Value(data[SupabaseClientProductBlacklistTable.id] as String),
        clientId: data[SupabaseClientProductBlacklistTable.clientId] as String,
        productId: data[SupabaseClientProductBlacklistTable.productId] as String,
        reason: Value(data[SupabaseClientProductBlacklistTable.reason] as String?),
        createdAt: Value(
          DateTime.parse(data[SupabaseClientProductBlacklistTable.createdAt] as String).toLocal(),
        ),
      );
}
