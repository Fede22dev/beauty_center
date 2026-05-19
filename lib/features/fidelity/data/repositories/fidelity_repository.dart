import 'package:drift/drift.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:uuid/uuid.dart';

import '../../../../core/constants/app_constants.dart';
import '../../../../core/database/app_database.dart';
import '../../../../core/database/repositories/base_repository.dart';
import '../../../../core/database/supabase_schema.dart';
import '../../../../core/logging/app_logger.dart';

/// Repository for fidelity cards management
/// Implements offline-first pattern with Supabase sync
class FidelityRepository extends BaseRepository {
  FidelityRepository({
    required super.db,
    required super.supabase,
    required super.isOnline,
  });

  static final _log = AppLogger.getLogger(name: 'FidelityRepository');

  List<OrderingTerm Function(FidelityCardsTable)> get _defaultOrdering => [
    (final t) => OrderingTerm.desc(t.createdAt),
  ];

  // ========================================================================
  // FIDELITY CARDS - QUERIES (Read operations - always from local DB)
  // ========================================================================

  /// Get all fidelity cards ordered by creation date
  Future<List<FidelityCardData>> getAllFidelityCards() =>
      (db.select(db.fidelityCardsTable)
            ..where((final t) => t.isActive.equals(true))
            ..orderBy(_defaultOrdering))
          .get();

  /// Watch all fidelity cards stream for reactive UI updates
  Stream<List<FidelityCardData>> watchAllFidelityCards() =>
      (db.select(db.fidelityCardsTable)
            ..where((final t) => t.isActive.equals(true))
            ..orderBy(_defaultOrdering))
          .watch();

  /// Get fidelity cards by client ID
  Future<List<FidelityCardData>> getFidelityCardsByClientId(
    final String clientId,
  ) =>
      (db.select(db.fidelityCardsTable)
            ..where(
              (final t) =>
                  t.clientId.equals(clientId) & t.isActive.equals(true),
            )
            ..orderBy(_defaultOrdering))
          .get();

  /// Watch fidelity cards by client ID for reactive UI updates
  Stream<List<FidelityCardData>> watchFidelityCardsByClientId(
    final String clientId,
  ) =>
      (db.select(db.fidelityCardsTable)
            ..where(
              (final t) =>
                  t.clientId.equals(clientId) & t.isActive.equals(true),
            )
            ..orderBy(_defaultOrdering))
          .watch();

  /// Get active fidelity cards by client ID
  Future<List<FidelityCardData>> getActiveFidelityCardsByClientId(
    final String clientId,
  ) =>
      (db.select(db.fidelityCardsTable)
            ..where(
              (final t) =>
                  t.clientId.equals(clientId) &
                  t.isActive.equals(true) &
                  t.status.equals('active'),
            )
            ..orderBy(_defaultOrdering))
          .get();

  /// Watch active fidelity cards by client ID for reactive UI updates
  Stream<List<FidelityCardData>> watchActiveFidelityCardsByClientId(
    final String clientId,
  ) =>
      (db.select(db.fidelityCardsTable)
            ..where(
              (final t) =>
                  t.clientId.equals(clientId) &
                  t.isActive.equals(true) &
                  t.status.equals('active'),
            )
            ..orderBy(_defaultOrdering))
          .watch();

  /// Get fidelity card by ID
  Future<FidelityCardData?> getFidelityCardById(final String id) => (db.select(
    db.fidelityCardsTable,
  )..where((final t) => t.id.equals(id))).getSingleOrNull();

  /// Watch fidelity card by ID for reactive UI updates
  Stream<FidelityCardData?> watchFidelityCardById(final String id) =>
      (db.select(
        db.fidelityCardsTable,
      )..where((final t) => t.id.equals(id))).watchSingleOrNull();

  /// Get fidelity card by card number
  Future<FidelityCardData?> getFidelityCardByNumber(final String cardNumber) =>
      (db.select(
        db.fidelityCardsTable,
      )..where((final t) => t.cardNumber.equals(cardNumber))).getSingleOrNull();

  /// Get fidelity transactions by card ID
  Future<List<FidelityTransactionData>> getFidelityTransactionsByCardId(
    final String cardId,
  ) =>
      (db.select(db.fidelityTransactionsTable)
            ..where((final t) => t.fidelityCardId.equals(cardId))
            ..orderBy([(final t) => OrderingTerm.desc(t.createdAt)]))
          .get();

  /// Watch fidelity transactions by card ID for reactive UI updates
  Stream<List<FidelityTransactionData>> watchFidelityTransactionsByCardId(
    final String cardId,
  ) =>
      (db.select(db.fidelityTransactionsTable)
            ..where((final t) => t.fidelityCardId.equals(cardId))
            ..orderBy([(final t) => OrderingTerm.desc(t.createdAt)]))
          .watch();

  // ========================================================================
  // FIDELITY CARDS - CRUD (Write operations - sync with Supabase)
  // ========================================================================

  /// Create new fidelity card
  /// Returns card ID or null if offline (read-only mode)
  Future<String?> createFidelityCard({
    required final String clientId,
    required final String cardNumber,
    final double initialBalance = 0,
    final bool isGift = false,
    final String? giftNote,
  }) async {
    if (!isOnline) {
      _log.warning('Cannot create fidelity card: offline mode (read-only)');
      return null;
    }

    final now = DateTime.now().toUtc();

    return await db.transaction(() async {
      // Insert card
      final insertedCard = await db
          .into(db.fidelityCardsTable)
          .insertReturning(
            FidelityCardsTableCompanion.insert(
              id: Value(const Uuid().v7()),
              clientId: Value(clientId),
              cardNumber: cardNumber.trim(),
              balance: Value(initialBalance),
              isGift: Value(isGift),
              giftNote: Value(giftNote?.trim()),
              status: const Value('active'),
              createdAt: Value(now),
              updatedAt: Value(now),
              isActive: const Value(true),
            ),
          );

      // If initial balance > 0, create a topup transaction
      if (initialBalance > 0) {
        await db
            .into(db.fidelityTransactionsTable)
            .insert(
              FidelityTransactionsTableCompanion.insert(
                id: Value(const Uuid().v7()),
                fidelityCardId: insertedCard.id,
                amount: initialBalance,
                type: 'topup',
                description: Value('Ricarica iniziale'),
                createdAt: Value(now),
              ),
            );
      }

      return insertedCard.id;
    }).then((cardId) {
      // Sync to Supabase after transaction is complete
      syncAsync(
        'fidelity_$cardId',
        () => _syncFidelityCardToSupabase(cardId),
      );
      return cardId;
    });
  }

  /// Add topup to fidelity card
  /// Returns true if successful, false if offline (read-only mode)
  Future<bool> addTopup({
    required final String cardId,
    required final double amount,
    final String? description,
  }) async {
    if (!isOnline) {
      _log.warning('Cannot add topup: offline mode (read-only)');
      return false;
    }

    final now = DateTime.now().toUtc();

    await db.transaction(() async {
      // Update card balance
      final currentCard = await getFidelityCardById(cardId);
      if (currentCard == null) return false;

      final companion = FidelityCardsTableCompanion(
        balance: Value(currentCard.balance + amount),
        updatedAt: Value(now),
      );

      await (db.update(
        db.fidelityCardsTable,
      )..where((final t) => t.id.equals(cardId))).write(companion);

      // Create transaction
      await db
          .into(db.fidelityTransactionsTable)
          .insert(
            FidelityTransactionsTableCompanion.insert(
              id: Value(const Uuid().v7()),
              fidelityCardId: cardId,
              amount: amount,
              type: 'topup',
              description: Value(description?.trim()),
              createdAt: Value(now),
            ),
          );

      return true;
    }).then((_) {
      // Sync to Supabase after transaction is complete
      syncAsync('fidelity_$cardId', () => _syncFidelityCardToSupabase(cardId));
    });

    return true;
  }

  /// Add usage transaction to fidelity card
  /// Throws if offline (read-only mode) or if amount exceeds balance.
  Future<void> addUsage({
    required final String cardId,
    required final double amount,
    final String? appointmentId,
    final String? description,
  }) async {
    if (!isOnline) {
      _log.warning('Cannot add usage: offline mode (read-only)');
      throw StateError('Operazione non disponibile in modalità offline');
    }

    if (amount <= 0) {
      throw ArgumentError('Usage amount must be positive');
    }

    final now = DateTime.now().toUtc();

    await db.transaction(() async {
      // Update card balance
      final currentCard = await getFidelityCardById(cardId);
      if (currentCard == null) return;

      if (currentCard.balance < amount) {
        throw StateError(
          'Credito insufficiente: €${currentCard.balance.toStringAsFixed(2)} < €${amount.toStringAsFixed(2)}',
        );
      }

      final companion = FidelityCardsTableCompanion(
        balance: Value(currentCard.balance - amount),
        updatedAt: Value(now),
      );

      await (db.update(
        db.fidelityCardsTable,
      )..where((final t) => t.id.equals(cardId))).write(companion);

      // Create transaction (negative amount for usage)
      await db
          .into(db.fidelityTransactionsTable)
          .insert(
            FidelityTransactionsTableCompanion.insert(
              id: Value(const Uuid().v7()),
              fidelityCardId: cardId,
              amount: -amount,
              type: 'usage',
              appointmentId: Value(appointmentId),
              description: Value(description?.trim()),
              createdAt: Value(now),
            ),
          );
    }).then((_) {
      // Sync to Supabase after transaction is complete
      syncAsync('fidelity_$cardId', () => _syncFidelityCardToSupabase(cardId));
    });
  }

  /// Refund usage (restore balance for appointment cancellation)
  /// Throws if offline (read-only mode).
  Future<void> refundUsage({
    required final String cardId,
    required final double amount,
    final String? appointmentId,
    final String? description,
  }) async {
    if (!isOnline) {
      _log.warning('Cannot refund usage: offline mode (read-only)');
      throw StateError('Operazione non disponibile in modalità offline');
    }

    if (amount <= 0) {
      throw ArgumentError('Refund amount must be positive');
    }

    final now = DateTime.now().toUtc();

    await db.transaction(() async {
      // Update card balance
      final currentCard = await getFidelityCardById(cardId);
      if (currentCard == null) return;

      final companion = FidelityCardsTableCompanion(
        balance: Value(currentCard.balance + amount),
        updatedAt: Value(now),
      );

      await (db.update(
        db.fidelityCardsTable,
      )..where((final t) => t.id.equals(cardId))).write(companion);

      // Create refund transaction (positive amount)
      await db
          .into(db.fidelityTransactionsTable)
          .insert(
            FidelityTransactionsTableCompanion.insert(
              id: Value(const Uuid().v7()),
              fidelityCardId: cardId,
              amount: amount,
              type: 'refund',
              appointmentId: Value(appointmentId),
              description: Value(description?.trim()),
              createdAt: Value(now),
            ),
          );
    }).then((_) {
      // Sync to Supabase after transaction is complete
      syncAsync('fidelity_$cardId', () => _syncFidelityCardToSupabase(cardId));
    });
  }

  /// Update fidelity card status
  /// Returns true if successful, false if offline (read-only mode)
  Future<bool> updateFidelityCardStatus({
    required final String id,
    required final String status,
  }) async {
    if (!isOnline) {
      _log.warning('Cannot update card status: offline mode (read-only)');
      return false;
    }

    final companion = FidelityCardsTableCompanion(
      status: Value(status),
      updatedAt: Value(DateTime.now().toUtc()),
    );

    await (db.update(
      db.fidelityCardsTable,
    )..where((final t) => t.id.equals(id))).write(companion);

    syncAsync('fidelity_$id', () => _syncFidelityCardToSupabase(id));
    return true;
  }

  /// Update fidelity card notes
  /// Returns true if successful, false if offline (read-only mode)
  Future<bool> updateFidelityCardNotes({
    required final String id,
    final String? notes,
  }) async {
    if (!isOnline) {
      _log.warning('Cannot update card notes: offline mode (read-only)');
      return false;
    }

    final companion = FidelityCardsTableCompanion(
      giftNote: Value(notes),
      updatedAt: Value(DateTime.now().toUtc()),
    );

    await (db.update(
      db.fidelityCardsTable,
    )..where((final t) => t.id.equals(id))).write(companion);

    syncAsync('fidelity_$id', () => _syncFidelityCardToSupabase(id));
    return true;
  }

  /// Soft delete fidelity card
  /// Returns true if successful, false if offline (read-only mode)
  Future<bool> deleteFidelityCard(final String id) async {
    if (!isOnline) {
      _log.warning('Cannot delete card: offline mode (read-only)');
      return false;
    }

    final companion = FidelityCardsTableCompanion(
      isActive: const Value(false),
      updatedAt: Value(DateTime.now().toUtc()),
    );

    await (db.update(
      db.fidelityCardsTable,
    )..where((final t) => t.id.equals(id))).write(companion);

    syncAsync('fidelity_$id', () => _syncFidelityCardToSupabase(id));
    return true;
  }

  // ========================================================================
  // SYNC IMPLEMENTATION (BaseRepository overrides)
  // ========================================================================

  @override
  Future<void> pullSupabaseToLocal() async {
    if (!isOnline) return;

    try {
      final lastSync = await getLastSyncTime(kLastSyncTimeFidelityCardsKey);

      var query = supabase!
          .from(SupabaseSchema.fidelityCards.tableName)
          .select();

      if (lastSync != null) {
        final adjustedTime = lastSync.subtract(kLastSyncBufferDuration);
        query = query.gt(
          SupabaseFidelityCardsTable.updatedAt,
          adjustedTime.toIso8601String(),
        );
      }

      final updatesData = await query;

      final allRemoteIdsData = await supabase!
          .from(SupabaseSchema.fidelityCards.tableName)
          .select(SupabaseFidelityCardsTable.id);

      final remoteIds = List<Map<String, dynamic>>.from(
        allRemoteIdsData,
      ).map((final e) => e[SupabaseFidelityCardsTable.id] as String).toSet();

      await db.transaction(() async {
        if (updatesData.isNotEmpty) {
          await db.batch((final batch) {
            final companions = updatesData.map(_mapSupabaseDataToCompanion);
            batch.insertAllOnConflictUpdate(db.fidelityCardsTable, companions);
          });
          _log.info('Synced ${updatesData.length} updated/new fidelity cards.');
        }

        if (remoteIds.isNotEmpty) {
          await (db.delete(
            db.fidelityCardsTable,
          )..where((final t) => t.id.isNotIn(remoteIds))).go();
        } else if (updatesData.isEmpty) {
          await db.delete(db.fidelityCardsTable).go();
        }

        // Sync Fidelity Transactions
        await _pullFidelityTransactions();
      });

      await updateLastSyncTime(kLastSyncTimeFidelityCardsKey);
    } catch (e, stackTrace) {
      _log.warning('Pull from Supabase failed', e, stackTrace);
    }
  }

  @override
  void startRealtimeSync() {
    if (!isOnline) return;

    subscribeToChannel(
      table: SupabaseSchema.fidelityCards,
      onEvent: _handleFidelityCardChange,
    );

    subscribeToChannel(
      table: SupabaseSchema.fidelityTransactions,
      onEvent: _handleFidelityTransactionChange,
    );

    _log.info('Realtime sync started for fidelity cards and transactions');
  }

  // ========================================================================
  // REALTIME EVENT HANDLER
  // ========================================================================

  Future<void> _handleFidelityCardChange(
    final PostgresChangePayload payload,
  ) async {
    try {
      switch (payload.eventType) {
        case PostgresChangeEvent.insert:
        case PostgresChangeEvent.update:
          final data = payload.newRecord;

          await db
              .into(db.fidelityCardsTable)
              .insertOnConflictUpdate(_mapSupabaseDataToCompanion(data));

          _log.finest(
            'Fidelity card ${data[SupabaseFidelityCardsTable.id]} synced from realtime',
          );

        case PostgresChangeEvent.delete:
          final oldData = payload.oldRecord;
          final id = oldData[SupabaseFidelityCardsTable.id] as String;

          await (db.delete(
            db.fidelityCardsTable,
          )..where((final t) => t.id.equals(id))).go();
          _log.finest('Fidelity card $id deleted from realtime');

        case PostgresChangeEvent.all:
          throw UnimplementedError('PostgresChangeEvent.all not supported');
      }
    } catch (e, stackTrace) {
      _log.warning('Failed to handle fidelity card change', e, stackTrace);
    }
  }

  // ========================================================================
  // PRIVATE SYNC HELPERS
  // ========================================================================

  FidelityCardsTableCompanion _mapSupabaseDataToCompanion(
    final Map<String, dynamic> data,
  ) => FidelityCardsTableCompanion.insert(
    id: Value(data[SupabaseFidelityCardsTable.id] as String),
    clientId: Value(data[SupabaseFidelityCardsTable.clientId] as String?),
    cardNumber: data[SupabaseFidelityCardsTable.cardNumber] as String,
    balance: Value(
      (data[SupabaseFidelityCardsTable.balance] as num?)?.toDouble() ?? 0,
    ),
    isGift: Value(data[SupabaseFidelityCardsTable.isGift] as bool? ?? false),
    giftNote: Value(data[SupabaseFidelityCardsTable.giftNote] as String?),
    status: Value(
      data[SupabaseFidelityCardsTable.status] as String? ?? 'active',
    ),
    createdAt: Value(
      DateTime.parse(
        data[SupabaseFidelityCardsTable.createdAt] as String,
      ).toLocal(),
    ),
    updatedAt: Value(
      DateTime.parse(
        data[SupabaseFidelityCardsTable.updatedAt] as String,
      ).toLocal(),
    ),
    isActive: Value(data[SupabaseFidelityCardsTable.isActive] as bool? ?? true),
  );

  Future<void> _syncFidelityCardToSupabase(final String id) async {
    try {
      final card = await getFidelityCardById(id);
      if (card == null) return;

      await supabase!
          .from(SupabaseSchema.fidelityCards.tableName)
          .upsert({
            SupabaseFidelityCardsTable.id: card.id,
            SupabaseFidelityCardsTable.clientId: card.clientId,
            SupabaseFidelityCardsTable.cardNumber: card.cardNumber,
            SupabaseFidelityCardsTable.balance: card.balance,
            SupabaseFidelityCardsTable.isGift: card.isGift,
            SupabaseFidelityCardsTable.giftNote: card.giftNote,
            SupabaseFidelityCardsTable.status: card.status,
            SupabaseFidelityCardsTable.createdAt: card.createdAt
                .toUtc()
                .toIso8601String(),
            SupabaseFidelityCardsTable.updatedAt: card.updatedAt
                .toUtc()
                .toIso8601String(),
            SupabaseFidelityCardsTable.isActive: card.isActive,
          });
    } catch (e, stackTrace) {
      _log.warning(
        'Failed to sync fidelity card $id to Supabase',
        e,
        stackTrace,
      );
    }
  }

  // ========================================================================
  // FIDELITY TRANSACTIONS PULL SYNC
  // ========================================================================

  Future<void> _pullFidelityTransactions() async {
    try {
      final lastSync = await getLastSyncTime(
        kLastSyncTimeFidelityTransactionsKey,
      );

      var query = supabase!
          .from(SupabaseSchema.fidelityTransactions.tableName)
          .select();

      if (lastSync != null) {
        final adjustedTime = lastSync.subtract(kLastSyncBufferDuration);
        query = query.gt(
          SupabaseFidelityTransactionsTable.createdAt,
          adjustedTime.toIso8601String(),
        );
      }

      final updatesData = await query;

      final allRemoteIdsData = await supabase!
          .from(SupabaseSchema.fidelityTransactions.tableName)
          .select(SupabaseFidelityTransactionsTable.id);

      final remoteIds = List<Map<String, dynamic>>.from(allRemoteIdsData)
          .map((final e) => e[SupabaseFidelityTransactionsTable.id] as String)
          .toSet();

      if (updatesData.isNotEmpty) {
        await db.batch((final batch) {
          final companions = updatesData.map(
            _mapFidelityTransactionToCompanion,
          );
          batch.insertAllOnConflictUpdate(
            db.fidelityTransactionsTable,
            companions,
          );
        });
        _log.info(
          'Synced ${updatesData.length} updated/new fidelity transactions.',
        );
      }

      if (remoteIds.isNotEmpty) {
        await (db.delete(
          db.fidelityTransactionsTable,
        )..where((final t) => t.id.isNotIn(remoteIds))).go();
      } else if (updatesData.isEmpty) {
        await db.delete(db.fidelityTransactionsTable).go();
      }

      await updateLastSyncTime(kLastSyncTimeFidelityTransactionsKey);
    } catch (e, stackTrace) {
      _log.warning('Failed to pull fidelity transactions', e, stackTrace);
    }
  }

  FidelityTransactionsTableCompanion _mapFidelityTransactionToCompanion(
    final Map<String, dynamic> data,
  ) => FidelityTransactionsTableCompanion.insert(
    id: Value(data[SupabaseFidelityTransactionsTable.id] as String),
    fidelityCardId:
        data[SupabaseFidelityTransactionsTable.fidelityCardId] as String,
    amount:
        (data[SupabaseFidelityTransactionsTable.amount] as num?)?.toDouble() ??
        0,
    type: data[SupabaseFidelityTransactionsTable.type] as String,
    appointmentId: Value(
      data[SupabaseFidelityTransactionsTable.appointmentId] as String?,
    ),
    description: Value(
      data[SupabaseFidelityTransactionsTable.description] as String?,
    ),
    createdAt: Value(
      DateTime.parse(
        data[SupabaseFidelityTransactionsTable.createdAt] as String,
      ).toLocal(),
    ),
  );

  // ========================================================================
  // FIDELITY TRANSACTIONS REALTIME HANDLER
  // ========================================================================

  Future<void> _handleFidelityTransactionChange(
    final PostgresChangePayload payload,
  ) async {
    try {
      switch (payload.eventType) {
        case PostgresChangeEvent.insert:
        case PostgresChangeEvent.update:
          final data = payload.newRecord;
          await db
              .into(db.fidelityTransactionsTable)
              .insertOnConflictUpdate(_mapFidelityTransactionToCompanion(data));
          _log.finest(
            'Fidelity transaction ${data[SupabaseFidelityTransactionsTable.id]} synced from realtime',
          );

        case PostgresChangeEvent.delete:
          final oldData = payload.oldRecord;
          final id = oldData[SupabaseFidelityTransactionsTable.id] as String;
          await (db.delete(
            db.fidelityTransactionsTable,
          )..where((final t) => t.id.equals(id))).go();
          _log.finest('Fidelity transaction $id deleted from realtime');

        case PostgresChangeEvent.all:
          throw UnimplementedError('PostgresChangeEvent.all not supported');
      }
    } catch (e, stackTrace) {
      _log.warning(
        'Failed to handle fidelity transaction change',
        e,
        stackTrace,
      );
    }
  }
}
