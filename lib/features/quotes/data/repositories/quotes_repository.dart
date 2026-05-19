import 'package:drift/drift.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:uuid/uuid.dart';

import '../../../../core/constants/app_constants.dart';
import '../../../../core/database/app_database.dart';
import '../../../../core/database/repositories/base_repository.dart';
import '../../../../core/database/supabase_schema.dart';
import '../../../../core/logging/app_logger.dart';
import '../../../clients/data/repositories/clients_repository.dart';

/// Repository for quotes management
/// Implements offline-first pattern with Supabase sync
class QuotesRepository extends BaseRepository {
  QuotesRepository({
    required super.db,
    required super.supabase,
    required super.isOnline,
  });

  static final _log = AppLogger.getLogger(name: 'QuotesRepository');

  List<OrderingTerm Function(QuotesTable)> get _defaultOrdering => [
    (final t) => OrderingTerm.desc(t.createdAt),
  ];

  // ========================================================================
  // QUOTES - QUERIES (Read operations - always from local DB)
  // ========================================================================

  /// Get all quotes ordered by creation date
  Future<List<QuoteData>> getAllQuotes() =>
      (db.select(db.quotesTable)
            ..where((final t) => t.isActive.equals(true))
            ..orderBy(_defaultOrdering))
          .get();

  /// Watch all quotes stream for reactive UI updates
  Stream<List<QuoteData>> watchAllQuotes() =>
      (db.select(db.quotesTable)
            ..where((final t) => t.isActive.equals(true))
            ..orderBy(_defaultOrdering))
          .watch();

  /// Get quotes by client ID
  Future<List<QuoteData>> getQuotesByClientId(final String clientId) =>
      (db.select(db.quotesTable)
            ..where(
              (final t) =>
                  t.clientId.equals(clientId) & t.isActive.equals(true),
            )
            ..orderBy(_defaultOrdering))
          .get();

  /// Watch quotes by client ID for reactive UI updates
  Stream<List<QuoteData>> watchQuotesByClientId(final String clientId) =>
      (db.select(db.quotesTable)
            ..where(
              (final t) =>
                  t.clientId.equals(clientId) & t.isActive.equals(true),
            )
            ..orderBy(_defaultOrdering))
          .watch();

  /// Get quote by ID
  Future<QuoteData?> getQuoteById(final String id) => (db.select(
    db.quotesTable,
  )..where((final t) => t.id.equals(id))).getSingleOrNull();

  /// Watch quote by ID for reactive UI updates
  Stream<QuoteData?> watchQuoteById(final String id) => (db.select(
    db.quotesTable,
  )..where((final t) => t.id.equals(id))).watchSingleOrNull();

  /// Get quote items by quote ID
  Future<List<QuoteItemData>> getQuoteItemsByQuoteId(final String quoteId) =>
      (db.select(
        db.quoteItemsTable,
      )..where((final t) => t.quoteId.equals(quoteId))).get();

  /// Watch quote items by quote ID for reactive UI updates
  Stream<List<QuoteItemData>> watchQuoteItemsByQuoteId(final String quoteId) =>
      (db.select(
        db.quoteItemsTable,
      )..where((final t) => t.quoteId.equals(quoteId))).watch();

  // ========================================================================
  // QUOTES - CRUD (Write operations - sync with Supabase)
  // ========================================================================

  /// Create new quote with items
  /// Returns quote ID or null on error
  /// Note: Works offline - sync to Supabase happens in background
  Future<String?> createQuote({
    required final String clientId,
    required final String quoteNumber,
    required final double totalPrice,
    final double discountAmount = 0,
    final DateTime? validUntil,
    final String? notes,
    required final List<QuoteItemData> items,
  }) async {
    final now = DateTime.now().toUtc();

    return await db.transaction(() async {
      // Insert quote
      final insertedQuote = await db
          .into(db.quotesTable)
          .insertReturning(
            QuotesTableCompanion.insert(
              id: Value(const Uuid().v7()),
              clientId: Value(clientId),
              quoteNumber: quoteNumber.trim(),
              status: const Value('draft'),
              totalPrice: Value(totalPrice),
              discountAmount: Value(discountAmount),
              validUntil: Value(validUntil),
              notes: Value(notes?.trim()),
              createdAt: Value(now),
              updatedAt: Value(now),
              isActive: const Value(true),
            ),
          );

      // Insert quote items with discount fields
      for (final item in items) {
        await db
            .into(db.quoteItemsTable)
            .insert(
              QuoteItemsTableCompanion.insert(
                id: Value(const Uuid().v7()),
                quoteId: insertedQuote.id,
                serviceId: item.serviceId,
                lockedServiceName: item.lockedServiceName,
                lockedUnitPrice: item.lockedUnitPrice,
                sessions: Value(item.sessions),
                discountType: Value(item.discountType),
                discountAmount: Value(item.discountAmount),
                discountedUnitPrice: Value(item.discountedUnitPrice),
                lineTotal: item.lineTotal,
              ),
            );
      }

      // CRITICAL: Sync verso Supabase - tenta anche se momentaneamente offline
      // La sync verrà ritentata automaticamente quando la connessione torna
      _log.info('Quote ${insertedQuote.id} created locally, scheduling sync to Supabase...');
      
      // Esegui sync subito se possibile, altrimenti verrà ritentato
      await _triggerSyncWithDebounce(insertedQuote.id);

      return insertedQuote.id;
    });
  }

  /// Update quote status
  /// Returns true if successful, false on error
  Future<bool> updateQuoteStatus({
    required final String id,
    required final String status,
  }) async {
    try {
      final companion = QuotesTableCompanion(
        status: Value(status),
        updatedAt: Value(DateTime.now().toUtc()),
      );

      final updated = await (db.update(
        db.quotesTable,
      )..where((final t) => t.id.equals(id))).write(companion);

      if (updated > 0) {
        _log.info('Quote $id status updated to $status locally');
        // CRITICAL: Sync verso Supabase
        await _triggerSyncWithDebounce(id);
      }
      return updated > 0;
    } catch (e) {
      _log.warning('Failed to update quote $id status', e);
      return false;
    }
  }

  /// Soft delete quote
  /// Returns true if successful, false on error
  Future<bool> deleteQuote(final String id) async {
    try {
      final companion = QuotesTableCompanion(
        isActive: const Value(false),
        updatedAt: Value(DateTime.now().toUtc()),
      );

      final updated = await (db.update(
        db.quotesTable,
      )..where((final t) => t.id.equals(id))).write(companion);

      if (updated > 0) {
        _log.info('Quote $id soft deleted locally');
        // CRITICAL: Sync verso Supabase (anche se sembra un po' controintuitivo,
        // dobbiamo sincronizzare il flag isActive=false)
        await _triggerSyncWithDebounce(id);
      }
      return updated > 0;
    } catch (e) {
      _log.warning('Failed to delete quote $id', e);
      return false;
    }
  }

  // ========================================================================
  // SYNC HELPER - Nuovo metodo robusto
  // ========================================================================

  /// Trigger sync con debounce e retry robusto
  /// Non blocca l'utente, tenta la sync in background
  Future<void> _triggerSyncWithDebounce(final String quoteId) async {
    const maxAttempts = 5;
    var attempt = 0;

    while (attempt < maxAttempts) {
      attempt++;
      
      try {
        // Verifica che supabase sia disponibile
        if (supabase == null) {
          _log.warning('Supabase not available, sync attempt $attempt/$maxAttempts failed');
          await Future.delayed(Duration(seconds: attempt * 2));
          continue;
        }

        // Tenta la sync
        _log.finest('Sync attempt $attempt/$maxAttempts for quote $quoteId');
        await _syncQuoteToSupabase(quoteId);
        
        _log.info('Quote $quoteId synced successfully on attempt $attempt');
        return; // Successo, esci
        
      } on PostgrestException catch (e) {
        if (e.code == '23503') {
          // FK error - potrebbe risolversi dopo
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

    _log.warning('Quote $quoteId failed to sync after $maxAttempts attempts');
  }

  // ========================================================================
  // SYNC IMPLEMENTATION (BaseRepository overrides)
  // ========================================================================

  @override
  Future<void> pullSupabaseToLocal() async {
    // CRITICAL: Verifica che supabase sia disponibile
    if (supabase == null) {
      _log.warning('Cannot pull quotes: Supabase client is null');
      return;
    }

    try {
      final lastSync = await getLastSyncTime(kLastSyncTimeQuotesKey);

      var query = supabase?.from(SupabaseSchema.quotes.tableName).select();
      if (query == null) {
        _log.warning('Cannot pull quotes: Supabase client is null');
        return;
      }

      if (lastSync != null) {
        final adjustedTime = lastSync.subtract(kLastSyncBufferDuration);
        query = query.gt(
          SupabaseQuotesTable.updatedAt,
          adjustedTime.toIso8601String(),
        );
      }

      final updatesData = await query;

      final allRemoteIdsData = await supabase
          ?.from(SupabaseSchema.quotes.tableName)
          .select(SupabaseQuotesTable.id) ?? [];

      final remoteIds = List<Map<String, dynamic>>.from(
        allRemoteIdsData,
      ).map((final e) => e[SupabaseQuotesTable.id] as String).toSet();

      await db.transaction(() async {
        if (updatesData.isNotEmpty) {
          await db.batch((final batch) {
            final companions = updatesData.map(_mapSupabaseDataToCompanion);
            batch.insertAllOnConflictUpdate(db.quotesTable, companions);
          });
          _log.info('Synced ${updatesData.length} updated/new quotes.');
        }

        if (remoteIds.isNotEmpty) {
          // CRITICAL: Non cancellare i record creati dopo l'ultimo sync (local-only)
          // Questi record non sono ancora stati sincronizzati su Supabase
          final lastSyncThreshold = lastSync ?? DateTime(2000).toUtc();
          await (db.delete(db.quotesTable)..where(
                (final t) =>
                    t.id.isNotIn(remoteIds) &
                    t.createdAt.isSmallerThan(Variable(lastSyncThreshold)),
              ))
              .go();
        } else if (updatesData.isEmpty && lastSync != null) {
          // Solo se c'è stato almeno un sync prima, e il server ha dati vuoti
          // Non cancellare nulla se è il primo sync (lastSync == null)
          await (db.delete(db.quotesTable)..where(
                (final t) => t.createdAt.isSmallerThan(Variable(lastSync)),
              ))
              .go();
        }

        // Sync Quote Items
        await _pullQuoteItems();
      });

      await updateLastSyncTime(kLastSyncTimeQuotesKey);
    } catch (e, stackTrace) {
      _log.warning('Pull from Supabase failed', e, stackTrace);
    }
  }

  @override
  void startRealtimeSync() {
    if (!isOnline) return;

    subscribeToChannel(
      table: SupabaseSchema.quotes,
      onEvent: _handleQuoteChange,
    );

    subscribeToChannel(
      table: SupabaseSchema.quoteItems,
      onEvent: _handleQuoteItemChange,
    );

    _log.info('Realtime sync started for quotes and items');
  }

  // ========================================================================
  // REALTIME EVENT HANDLER
  // ========================================================================

  Future<void> _handleQuoteChange(final PostgresChangePayload payload) async {
    try {
      switch (payload.eventType) {
        case PostgresChangeEvent.insert:
        case PostgresChangeEvent.update:
          final data = payload.newRecord;

          await db
              .into(db.quotesTable)
              .insertOnConflictUpdate(_mapSupabaseDataToCompanion(data));

          _log.finest(
            'Quote ${data[SupabaseQuotesTable.id]} synced from realtime',
          );

        case PostgresChangeEvent.delete:
          final oldData = payload.oldRecord;
          final id = oldData[SupabaseQuotesTable.id] as String;

          await (db.delete(
            db.quotesTable,
          )..where((final t) => t.id.equals(id))).go();
          _log.finest('Quote $id deleted from realtime');

        case PostgresChangeEvent.all:
          throw UnimplementedError('PostgresChangeEvent.all not supported');
      }
    } catch (e, stackTrace) {
      _log.warning('Failed to handle quote change', e, stackTrace);
    }
  }

  // ========================================================================
  // PRIVATE SYNC HELPERS
  // ========================================================================

  QuotesTableCompanion _mapSupabaseDataToCompanion(
    final Map<String, dynamic> data,
  ) => QuotesTableCompanion.insert(
    id: Value(data[SupabaseQuotesTable.id] as String),
    clientId: Value(data[SupabaseQuotesTable.clientId] as String?),
    quoteNumber: data[SupabaseQuotesTable.quoteNumber] as String,
    status: Value(data[SupabaseQuotesTable.status] as String? ?? 'draft'),
    totalPrice: Value(
      (data[SupabaseQuotesTable.totalPrice] as num?)?.toDouble() ?? 0,
    ),
    discountAmount: Value(
      (data[SupabaseQuotesTable.discountAmount] as num?)?.toDouble() ?? 0,
    ),
    validUntil: data[SupabaseQuotesTable.validUntil] != null
        ? Value(
            DateTime.parse(
              data[SupabaseQuotesTable.validUntil] as String,
            ).toLocal(),
          )
        : const Value.absent(),
    notes: Value(data[SupabaseQuotesTable.notes] as String?),
    createdAt: Value(
      DateTime.parse(data[SupabaseQuotesTable.createdAt] as String).toLocal(),
    ),
    updatedAt: Value(
      DateTime.parse(data[SupabaseQuotesTable.updatedAt] as String).toLocal(),
    ),
    isActive: Value(data[SupabaseQuotesTable.isActive] as bool? ?? true),
  );

  /// Sincronizza forzatamente un preventivo a Supabase
  /// Usato per risolvere dipendenze FK (es. quando un pacchetto referenzia questo preventivo)
  Future<void> syncEntityToSupabase(final String id) async {
    try {
      // Sync preventivo principale
      await _syncQuoteToSupabase(id);

      // Sync anche gli items del preventivo (indipendente dal successo del preventivo)
      try {
        await _syncQuoteItemsToSupabase(id);
      } catch (itemsError) {
        _log.warning('Failed to sync items for quote $id', itemsError);
        // Non rilanciare - il preventivo principale è già stato sincronizzato
      }
    } catch (e, stackTrace) {
      _log.warning('Failed to sync quote $id to Supabase', e, stackTrace);
      throw e; // Rilancia per permettere retry
    }
  }

  Future<void> _syncQuoteToSupabase(
    final String id, {
    int retryCount = 0,
  }) async {
    const maxRetries = 3;

    final quote = await getQuoteById(id);
    if (quote == null) {
      _log.warning('Cannot sync quote $id: not found in local DB');
      return;
    }

    _log.finest('Syncing quote $id (client: ${quote.clientId}, status: ${quote.status})');

    // CRITICAL: Verifica che supabase sia disponibile
    if (supabase == null) {
      _log.warning('Cannot sync quote $id: Supabase client is null');
      throw StateError('Supabase client not available');
    }

    try {
      _log.finest('Sending quote $id to Supabase...');
      await supabase?.from(SupabaseSchema.quotes.tableName).upsert({
        SupabaseQuotesTable.id: quote.id,
        SupabaseQuotesTable.clientId: quote.clientId,
        SupabaseQuotesTable.quoteNumber: quote.quoteNumber,
        SupabaseQuotesTable.status: quote.status,
        SupabaseQuotesTable.totalPrice: quote.totalPrice,
        SupabaseQuotesTable.discountAmount: quote.discountAmount,
        SupabaseQuotesTable.validUntil: quote.validUntil
            ?.toUtc()
            .toIso8601String(),
        SupabaseQuotesTable.notes: quote.notes,
        SupabaseQuotesTable.createdAt: quote.createdAt
            .toUtc()
            .toIso8601String(),
        SupabaseQuotesTable.updatedAt: quote.updatedAt
            .toUtc()
            .toIso8601String(),
        SupabaseQuotesTable.isActive: quote.isActive,
      });
      
      _log.finest('Quote $id upserted to Supabase successfully');

      // CRITICAL: Sync anche gli items del preventivo
      await _syncQuoteItemsToSupabase(id);
      
      _log.info('Quote $id and its items synced successfully');
    } on PostgrestException catch (e, stackTrace) {
      // CRITICAL: Gestione errore Foreign Key verso clients
      if (e.code == '23503' && retryCount < maxRetries) {
        _log.warning(
          'FK constraint failed for quote $id (client not found), attempting to sync client first (retry ${retryCount + 1}/$maxRetries)',
          e,
        );

        try {
          // Sincronizza il cliente prima di riprovare
          final clientId = quote.clientId;
          if (clientId == null) {
            _log.warning(
              'Quote $id has no client assigned, skipping client sync',
            );
            rethrow;
          }
          final clientsRepo = ClientsRepository(
            db: db,
            supabase: supabase,
            isOnline: isOnline,
          );
          await clientsRepo.syncEntityToSupabase(clientId);
          _log.info('Synced client $clientId before quote $id');

          // Attendi un momento per permettere a Supabase di processare
          await Future.delayed(Duration(seconds: retryCount + 1));

          // Riprova la sync del preventivo
          return await _syncQuoteToSupabase(id, retryCount: retryCount + 1);
        } catch (clientError) {
          _log.warning('Failed to sync client for quote $id', clientError);
        }
      }

      _log.warning('Failed to sync quote $id to Supabase', e, stackTrace);
      rethrow;
    } catch (e, stackTrace) {
      _log.warning('Failed to sync quote $id to Supabase', e, stackTrace);
      rethrow;
    }
  }

  /// Sincronizza gli items di un preventivo specifico a Supabase
  Future<void> _syncQuoteItemsToSupabase(final String quoteId) async {
    try {
      final items = await getQuoteItemsByQuoteId(quoteId);

      for (final item in items) {
        await supabase?.from(SupabaseSchema.quoteItems.tableName).upsert({
          SupabaseQuoteItemsTable.id: item.id,
          SupabaseQuoteItemsTable.quoteId: item.quoteId,
          SupabaseQuoteItemsTable.serviceId: item.serviceId,
          SupabaseQuoteItemsTable.lockedServiceName: item.lockedServiceName,
          SupabaseQuoteItemsTable.lockedUnitPrice: item.lockedUnitPrice,
          SupabaseQuoteItemsTable.sessions: item.sessions,
          SupabaseQuoteItemsTable.discountType: item.discountType,
          SupabaseQuoteItemsTable.discountAmount: item.discountAmount,
          SupabaseQuoteItemsTable.discountedUnitPrice: item.discountedUnitPrice,
          SupabaseQuoteItemsTable.lineTotal: item.lineTotal,
        });
      }

      _log.finest('Synced ${items.length} items for quote $quoteId');
    } catch (e, stackTrace) {
      _log.warning('Failed to sync quote items for $quoteId', e, stackTrace);
    }
  }

  // ========================================================================
  // QUOTE ITEMS PULL SYNC
  // ========================================================================

  Future<void> _pullQuoteItems() async {
    try {
      // CRITICAL: Verifica che supabase sia disponibile
      if (supabase == null) {
        _log.warning('Cannot pull quote items: Supabase client is null');
        return;
      }

      final lastSync = await getLastSyncTime(kLastSyncTimeQuoteItemsKey);

      var query = supabase?.from(SupabaseSchema.quoteItems.tableName).select();
      if (query == null) {
        _log.warning('Cannot pull quote items: Supabase client is null');
        return;
      }

      // Note: quote_items doesn't have updated_at, so we pull all data every time
      // This is acceptable as quote_items are relatively small in number
      final updatesData = await query;

      final allRemoteIdsData = await supabase
          ?.from(SupabaseSchema.quoteItems.tableName)
          .select(SupabaseQuoteItemsTable.id) ?? [];

      final remoteIds = List<Map<String, dynamic>>.from(
        allRemoteIdsData,
      ).map((final e) => e[SupabaseQuoteItemsTable.id] as String).toSet();

      if (updatesData.isNotEmpty) {
        await db.batch((final batch) {
          final companions = updatesData.map(_mapQuoteItemToCompanion);
          batch.insertAllOnConflictUpdate(db.quoteItemsTable, companions);
        });
        _log.info('Synced ${updatesData.length} updated/new quote items.');
      }

      // CRITICAL: Non cancellare items creati dopo l'ultimo sync (local-only)
      // Questi items appartengono a preventivi non ancora sincronizzati
      if (remoteIds.isNotEmpty) {
        final lastSyncThreshold = lastSync ?? DateTime(2000).toUtc();
        final oldQuoteIdsQuery = db.selectOnly(db.quotesTable)
          ..addColumns([db.quotesTable.id])
          ..where(db.quotesTable.createdAt.isSmallerThan(Variable(lastSyncThreshold)));
        final oldQuoteIds = await oldQuoteIdsQuery.map((final row) => row.read(db.quotesTable.id)!).get();
        await (db.delete(db.quoteItemsTable)..where(
              (final t) =>
                  t.id.isNotIn(remoteIds) &
                  t.quoteId.isIn(oldQuoteIds),
            )).go();
      } else if (updatesData.isEmpty && lastSync != null) {
        // Solo se c'è stato almeno un sync prima, e il server ha dati vuoti
        // Cancella solo gli items di preventivi creati prima dell'ultimo sync
        final lastSyncThreshold = lastSync;
        final oldQuoteIdsQuery = db.selectOnly(db.quotesTable)
          ..addColumns([db.quotesTable.id])
          ..where(db.quotesTable.createdAt.isSmallerThan(Variable(lastSyncThreshold!)));
        final oldQuoteIds = await oldQuoteIdsQuery.map((final row) => row.read(db.quotesTable.id)!).get();
        await (db.delete(db.quoteItemsTable)..where(
              (final t) => t.quoteId.isIn(oldQuoteIds),
            )).go();
      }

      await updateLastSyncTime(kLastSyncTimeQuoteItemsKey);
    } catch (e, stackTrace) {
      _log.warning('Failed to pull quote items', e, stackTrace);
    }
  }

  QuoteItemsTableCompanion _mapQuoteItemToCompanion(
    final Map<String, dynamic> data,
  ) => QuoteItemsTableCompanion.insert(
    id: Value(data[SupabaseQuoteItemsTable.id] as String),
    quoteId: data[SupabaseQuoteItemsTable.quoteId] as String,
    serviceId: data[SupabaseQuoteItemsTable.serviceId] as String,
    lockedServiceName:
        data[SupabaseQuoteItemsTable.lockedServiceName] as String,
    lockedUnitPrice:
        (data[SupabaseQuoteItemsTable.lockedUnitPrice] as num?)?.toDouble() ??
        0,
    sessions: Value(data[SupabaseQuoteItemsTable.sessions] as int? ?? 1),
    discountType: Value(data[SupabaseQuoteItemsTable.discountType] as String),
    discountAmount: Value(
      (data[SupabaseQuoteItemsTable.discountAmount] as num?)?.toDouble() ?? 0,
    ),
    discountedUnitPrice: Value(
      (data[SupabaseQuoteItemsTable.discountedUnitPrice] as num?)?.toDouble() ??
          0,
    ),
    lineTotal:
        (data[SupabaseQuoteItemsTable.lineTotal] as num?)?.toDouble() ?? 0,
  );

  // ========================================================================
  // QUOTE ITEMS REALTIME HANDLER
  // ========================================================================

  Future<void> _handleQuoteItemChange(
    final PostgresChangePayload payload,
  ) async {
    try {
      switch (payload.eventType) {
        case PostgresChangeEvent.insert:
        case PostgresChangeEvent.update:
          final data = payload.newRecord;
          await db
              .into(db.quoteItemsTable)
              .insertOnConflictUpdate(_mapQuoteItemToCompanion(data));
          _log.finest(
            'Quote item ${data[SupabaseQuoteItemsTable.id]} synced from realtime',
          );

        case PostgresChangeEvent.delete:
          final oldData = payload.oldRecord;
          final id = oldData[SupabaseQuoteItemsTable.id] as String;
          await (db.delete(
            db.quoteItemsTable,
          )..where((final t) => t.id.equals(id))).go();
          _log.finest('Quote item $id deleted from realtime');

        case PostgresChangeEvent.all:
          throw UnimplementedError('PostgresChangeEvent.all not supported');
      }
    } catch (e, stackTrace) {
      _log.warning('Failed to handle quote item change', e, stackTrace);
    }
  }
}
