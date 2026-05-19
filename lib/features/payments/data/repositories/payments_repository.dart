import 'package:drift/drift.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:uuid/uuid.dart';

import '../../../../core/constants/app_constants.dart';
import '../../../../core/database/app_database.dart';
import '../../../../core/database/repositories/base_repository.dart';
import '../../../../core/database/supabase_schema.dart';
import '../../../../core/logging/app_logger.dart';
import '../../../appointments/data/repositories/appointments_repository.dart';
import '../../../packages/data/repositories/packages_repository.dart';
import '../../../product_sales/data/repositories/product_sales_repository.dart';

/// Repository for payments management
/// Implements offline-first pattern with Supabase sync
class PaymentsRepository extends BaseRepository {
  PaymentsRepository({
    required super.db,
    required super.supabase,
    required super.isOnline,
  });

  static final _log = AppLogger.getLogger(name: 'PaymentsRepository');

  List<OrderingTerm Function(PaymentsTable)> get _defaultOrdering => [
    (final t) => OrderingTerm.desc(t.paidAt),
  ];

  // ========================================================================
  // PAYMENTS - QUERIES (Read operations - always from local DB)
  // ========================================================================

  /// Get all payments ordered by payment date
  Future<List<PaymentData>> getAllPayments() =>
      (db.select(db.paymentsTable)..orderBy(_defaultOrdering)).get();

  /// Watch all payments stream for reactive UI updates
  Stream<List<PaymentData>> watchAllPayments() =>
      (db.select(db.paymentsTable)..orderBy(_defaultOrdering)).watch();

  /// Get payments by client ID
  Future<List<PaymentData>> getPaymentsByClientId(final String clientId) =>
      (db.select(db.paymentsTable)
            ..where((final t) => t.clientId.equals(clientId))
            ..orderBy(_defaultOrdering))
          .get();

  /// Watch payments by client ID for reactive UI updates
  Stream<List<PaymentData>> watchPaymentsByClientId(final String clientId) =>
      (db.select(db.paymentsTable)
            ..where((final t) => t.clientId.equals(clientId))
            ..orderBy(_defaultOrdering))
          .watch();

  /// Get payments by package ID
  Future<List<PaymentData>> getPaymentsByPackageId(final String packageId) =>
      (db.select(db.paymentsTable)
            ..where((final t) => t.packageId.equals(packageId))
            ..orderBy(_defaultOrdering))
          .get();

  /// Watch payments by package ID for reactive UI updates
  Stream<List<PaymentData>> watchPaymentsByPackageId(final String packageId) =>
      (db.select(db.paymentsTable)
            ..where((final t) => t.packageId.equals(packageId))
            ..orderBy(_defaultOrdering))
          .watch();

  /// Get payments by appointment ID
  Future<List<PaymentData>> getPaymentsByAppointmentId(
    final String appointmentId,
  ) =>
      (db.select(db.paymentsTable)
            ..where((final t) => t.appointmentId.equals(appointmentId))
            ..orderBy(_defaultOrdering))
          .get();

  /// Watch payments by appointment ID for reactive UI updates
  Stream<List<PaymentData>> watchPaymentsByAppointmentId(
    final String appointmentId,
  ) =>
      (db.select(db.paymentsTable)
            ..where((final t) => t.appointmentId.equals(appointmentId))
            ..orderBy(_defaultOrdering))
          .watch();

  /// Get payments by product sale ID
  Future<List<PaymentData>> getPaymentsByProductSaleId(
    final String productSaleId,
  ) =>
      (db.select(db.paymentsTable)
            ..where((final t) => t.productSaleId.equals(productSaleId))
            ..orderBy(_defaultOrdering))
          .get();

  /// Watch payments by product sale ID for reactive UI updates
  Stream<List<PaymentData>> watchPaymentsByProductSaleId(
    final String productSaleId,
  ) =>
      (db.select(db.paymentsTable)
            ..where((final t) => t.productSaleId.equals(productSaleId))
            ..orderBy(_defaultOrdering))
          .watch();

  /// Get payment by ID
  Future<PaymentData?> getPaymentById(final String id) => (db.select(
    db.paymentsTable,
  )..where((final t) => t.id.equals(id))).getSingleOrNull();

  /// Watch payment by ID for reactive UI updates
  Stream<PaymentData?> watchPaymentById(final String id) => (db.select(
    db.paymentsTable,
  )..where((final t) => t.id.equals(id))).watchSingleOrNull();

  // ========================================================================
  // PAYMENTS - CRUD (Write operations - sync with Supabase)
  // ========================================================================

  /// Create new payment
  /// Returns payment ID or null if offline (read-only mode)
  ///
  /// CRITICAL VALIDATION: A payment MUST be linked to at least one entity
  /// (package, appointment, or product_sale). Payments without references
  /// are considered orphaned and can lead to financial data inconsistencies.
  /// Create new payment
  /// Returns payment ID or null on error
  /// Note: Works offline - sync to Supabase happens in background
  Future<String?> createPayment({
    required final String clientId,
    required final double amount,
    required final String paymentMethod,
    final String? packageId,
    final String? appointmentId,
    final String? productSaleId,
    final String? notes,
  }) async {
    // CRITICAL VALIDATION: Prevent orphaned payments
    // At least one reference must be provided
    if (packageId == null && appointmentId == null && productSaleId == null) {
      _log.severe(
        'CRITICAL: Attempted to create orphaned payment for client $clientId. '
        'A payment MUST be linked to at least one entity (package, appointment, or product_sale).',
      );
      throw ArgumentError(
        'Pagamento orfano rilevato: il pagamento deve essere collegato ad almeno '
        'una entità (pacchetto, appuntamento o vendita prodotto).',
      );
    }

    // Validate amount is not zero
    if (amount == 0) {
      _log.warning('Attempted to create payment with zero amount');
      throw ArgumentError("L'importo del pagamento non può essere zero.");
    }

    final now = DateTime.now().toUtc();

    final insertedPayment = await db
        .into(db.paymentsTable)
        .insertReturning(
          PaymentsTableCompanion.insert(
            id: Value(const Uuid().v7()),
            clientId: Value(clientId),
            packageId: Value(packageId),
            appointmentId: Value(appointmentId),
            productSaleId: Value(productSaleId),
            amount: amount,
            paymentMethod: Value(paymentMethod),
            notes: Value(notes?.trim()),
            paidAt: Value(now),
            createdAt: Value(now),
          ),
        );

    _log.info(
      'Payment ${insertedPayment.id} created locally for client $clientId '
      '(amount: $amount, method: $paymentMethod, '
      'package: $packageId, appointment: $appointmentId, productSale: $productSaleId)',
    );

    // Esegui sync in background con retry robusto
    await _triggerSyncWithDebounce(insertedPayment.id);

    return insertedPayment.id;
  }

  /// Soft delete payment (for refunds/storni)
  /// Returns true if successful, false on error
  Future<bool> deletePayment(final String id) async {
    try {
      await (db.delete(
        db.paymentsTable,
      )..where((final t) => t.id.equals(id))).go();

      _log.info('Payment $id deleted locally');
      
      // Sync deletion to Supabase
      if (supabase != null) {
        await _deletePaymentFromSupabase(id);
      }
      return true;
    } catch (e) {
      _log.warning('Failed to delete payment $id', e);
      return false;
    }
  }

  // ========================================================================
  // SYNC HELPER - Robust sync with retry
  // ========================================================================

  /// Trigger sync con debounce e retry robusto
  Future<void> _triggerSyncWithDebounce(final String paymentId) async {
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

        _log.finest('Sync attempt $attempt/$maxAttempts for payment $paymentId');
        await _syncPaymentToSupabase(paymentId);
        
        _log.info('Payment $paymentId synced successfully on attempt $attempt');
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

    _log.warning('Payment $paymentId failed to sync after $maxAttempts attempts');
  }

  // ========================================================================
  // SYNC IMPLEMENTATION (BaseRepository overrides)
  // ========================================================================

  @override
  Future<void> pullSupabaseToLocal() async {
    // CRITICAL: Verifica che supabase sia disponibile
    if (supabase == null) {
      _log.warning('Cannot pull payments: Supabase client is null');
      return;
    }

    try {
      final lastSync = await getLastSyncTime(kLastSyncTimePaymentsKey);

      var query = supabase?.from(SupabaseSchema.payments.tableName).select();
      if (query == null) {
        _log.warning('Cannot pull payments: Supabase client is null');
        return;
      }

      if (lastSync != null) {
        final adjustedTime = lastSync.subtract(kLastSyncBufferDuration);
        query = query.gt(
          SupabasePaymentsTable.createdAt,
          adjustedTime.toIso8601String(),
        );
      }

      final updatesData = await query;

      final allRemoteIdsData = await supabase
          ?.from(SupabaseSchema.payments.tableName)
          .select(SupabasePaymentsTable.id) ?? [];

      final remoteIds = List<Map<String, dynamic>>.from(
        allRemoteIdsData,
      ).map((final e) => e[SupabasePaymentsTable.id] as String).toSet();

      await db.transaction(() async {
        if (updatesData.isNotEmpty) {
          await db.batch((final batch) {
            final companions = updatesData.map(_mapSupabaseDataToCompanion);
            batch.insertAllOnConflictUpdate(db.paymentsTable, companions);
          });
          _log.info('Synced ${updatesData.length} updated/new payments.');
        }

        // CRITICAL: Non cancellare record creati dopo l'ultimo sync (local-only)
        if (remoteIds.isNotEmpty) {
          final lastSyncThreshold = lastSync ?? DateTime(2000).toUtc();
          await (db.delete(db.paymentsTable)..where(
                (final t) =>
                    t.id.isNotIn(remoteIds) &
                    t.createdAt.isSmallerThan(Variable(lastSyncThreshold)),
              )).go();
        } else if (updatesData.isEmpty && lastSync != null) {
          // Solo se c'è stato almeno un sync prima
          await (db.delete(db.paymentsTable)
            ..where((final t) => t.createdAt.isSmallerThan(Variable(lastSync!)))).go();
        }
      });

      await updateLastSyncTime(kLastSyncTimePaymentsKey);
    } catch (e, stackTrace) {
      _log.warning('Pull from Supabase failed', e, stackTrace);
    }
  }

  @override
  void startRealtimeSync() {
    if (!isOnline) return;

    subscribeToChannel(
      table: SupabaseSchema.payments,
      onEvent: _handlePaymentChange,
    );

    _log.info('Realtime sync started for payments');
  }

  // ========================================================================
  // REALTIME EVENT HANDLER
  // ========================================================================

  Future<void> _handlePaymentChange(final PostgresChangePayload payload) async {
    try {
      switch (payload.eventType) {
        case PostgresChangeEvent.insert:
        case PostgresChangeEvent.update:
          final data = payload.newRecord;

          await db
              .into(db.paymentsTable)
              .insertOnConflictUpdate(_mapSupabaseDataToCompanion(data));

          _log.finest(
            'Payment ${data[SupabasePaymentsTable.id]} synced from realtime',
          );

        case PostgresChangeEvent.delete:
          final oldData = payload.oldRecord;
          final id = oldData[SupabasePaymentsTable.id] as String;

          await (db.delete(
            db.paymentsTable,
          )..where((final t) => t.id.equals(id))).go();
          _log.finest('Payment $id deleted from realtime');

        case PostgresChangeEvent.all:
          throw UnimplementedError('PostgresChangeEvent.all not supported');
      }
    } catch (e, stackTrace) {
      _log.warning('Failed to handle payment change', e, stackTrace);
    }
  }

  // ========================================================================
  // PRIVATE SYNC HELPERS
  // ========================================================================

  PaymentsTableCompanion _mapSupabaseDataToCompanion(
    final Map<String, dynamic> data,
  ) => PaymentsTableCompanion.insert(
    id: Value(data[SupabasePaymentsTable.id] as String),
    clientId: Value(data[SupabasePaymentsTable.clientId] as String?),
    packageId: Value(data[SupabasePaymentsTable.packageId] as String?),
    appointmentId: Value(data[SupabasePaymentsTable.appointmentId] as String?),
    productSaleId: Value(data[SupabasePaymentsTable.productSaleId] as String?),
    amount: (data[SupabasePaymentsTable.amount] as num?)?.toDouble() ?? 0,

    paymentMethod: Value(data[SupabasePaymentsTable.paymentMethod] as String),
    notes: Value(data[SupabasePaymentsTable.notes] as String?),
    createdAt: Value(
      DateTime.parse(data[SupabasePaymentsTable.createdAt] as String).toLocal(),
    ),
  );

  Future<void> _syncPaymentToSupabase(final String id, {int retryCount = 0}) async {
    const maxRetries = 3;

    final payment = await getPaymentById(id);
    if (payment == null) return;

    try {

      await supabase?.from(SupabaseSchema.payments.tableName).upsert({
        SupabasePaymentsTable.id: payment.id,
        SupabasePaymentsTable.clientId: payment.clientId,
        SupabasePaymentsTable.packageId: payment.packageId,
        SupabasePaymentsTable.appointmentId: payment.appointmentId,
        SupabasePaymentsTable.productSaleId: payment.productSaleId,
        SupabasePaymentsTable.amount: payment.amount,
        SupabasePaymentsTable.paymentMethod: payment.paymentMethod,
        SupabasePaymentsTable.notes: payment.notes,
        SupabasePaymentsTable.paidAt: payment.paidAt.toUtc().toIso8601String(),
        SupabasePaymentsTable.createdAt: payment.createdAt
            .toUtc()
            .toIso8601String(),
      });
    } on PostgrestException catch (e, stackTrace) {
      // CRITICAL: Gestione errore Foreign Key
      // Se il pagamento fallisce perché l'entità padre non esiste ancora su Supabase,
      // sincronizza prima l'entità padre e poi riprova
      if (e.code == '23503' && retryCount < maxRetries) { // FK violation
        _log.warning(
          'FK constraint failed for payment $id, attempting to sync parent entity first (retry ${retryCount + 1}/$maxRetries)',
          e,
        );
        
        try {
          // Sincronizza l'entità padre prima di riprovare
          await _syncParentEntityBeforePayment(payment);
          
          // Attendi un momento per permettere a Supabase di processare
          await Future.delayed(Duration(seconds: retryCount + 1));
          
          // Riprova la sync del pagamento
          return await _syncPaymentToSupabase(id, retryCount: retryCount + 1);
        } catch (parentError) {
          _log.warning('Failed to sync parent entity for payment $id', parentError);
        }
      }
      
      _log.warning('Failed to sync payment $id to Supabase', e, stackTrace);
    } catch (e, stackTrace) {
      _log.warning('Failed to sync payment $id to Supabase', e, stackTrace);
    }
  }
  
  /// Sincronizza l'entità padre (package/appointment/product_sale) prima del pagamento
  Future<void> _syncParentEntityBeforePayment(PaymentData payment) async {
    if (payment.packageId != null) {
      // Trova e sincronizza il pacchetto
      final packageRepo = PackagesRepository(
        db: db, 
        supabase: supabase, 
        isOnline: isOnline,
      );
      await packageRepo.syncEntityToSupabase(payment.packageId!);
      _log.info('Synced parent package ${payment.packageId} before payment');
    } else if (payment.appointmentId != null) {
      // Trova e sincronizza l'appuntamento
      final appointmentRepo = AppointmentsRepository(
        db: db, 
        supabase: supabase, 
        isOnline: isOnline,
      );
      await appointmentRepo.syncEntityToSupabase(payment.appointmentId!);
      _log.info('Synced parent appointment ${payment.appointmentId} before payment');
    } else if (payment.productSaleId != null) {
      // Trova e sincronizza la vendita prodotto
      final productSaleRepo = ProductSalesRepository(
        db: db, 
        supabase: supabase, 
        isOnline: isOnline,
      );
      await productSaleRepo.syncEntityToSupabase(payment.productSaleId!);
      _log.info('Synced parent product sale ${payment.productSaleId} before payment');
    }
  }

  Future<void> _deletePaymentFromSupabase(final String id) async {
    try {
      await supabase
          ?.from(SupabaseSchema.payments.tableName)
          .delete()
          .eq(SupabasePaymentsTable.id, id);
    } catch (e, stackTrace) {
      _log.warning('Failed to delete payment $id from Supabase', e, stackTrace);
    }
  }
}
