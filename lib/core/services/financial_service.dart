import 'package:drift/drift.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:uuid/uuid.dart';

import '../database/app_database.dart';
import '../logging/app_logger.dart';

/// Eccezione specifica per errori finanziari
class FinancialException implements Exception {
  final String code;
  final String message;
  final String? operation;
  final Map<String, dynamic>? context;

  FinancialException({
    required this.code,
    required this.message,
    this.operation,
    this.context,
  });

  @override
  String toString() =>
      '[FinancialException:$code] $message${operation != null ? ' (op: $operation)' : ''}';
}

/// Risultato di un'operazione finanziaria atomica
class FinancialResult<T> {
  final bool success;
  final T? data;
  final FinancialException? error;
  final String operationId;

  FinancialResult._({
    required this.success,
    this.data,
    this.error,
    required this.operationId,
  });

  factory FinancialResult.success(T data, String operationId) =>
      FinancialResult._(success: true, data: data, operationId: operationId);

  factory FinancialResult.failure(
    FinancialException error,
    String operationId,
  ) =>
      FinancialResult._(success: false, error: error, operationId: operationId);

  R when<R>({
    required R Function(T data) success,
    required R Function(FinancialException error) failure,
  }) {
    if (this.success && data != null) {
      return success(data as T);
    } else if (error != null) {
      return failure(error!);
    } else {
      // Fallback: should never happen, but handle gracefully
      return failure(
        FinancialException(
          code: 'UNKNOWN_ERROR',
          message: 'Operation failed without error details',
          operation: 'when',
        ),
      );
    }
  }
}

/// Service centralizzato per tutte le operazioni finanziarie
///
/// TUTTE le operazioni finanziarie DEVONO passare da questo service.
/// Non usare mai i repository direttamente per operazioni che coinvolgono
/// pagamenti, fidelity, o pacchetti.
class FinancialService {
  FinancialService({required this.db, required this.isOnline});

  final AppDatabase db;
  final bool isOnline;

  static final _log = AppLogger.getLogger(name: 'FinancialService');

  // ==========================================================================
  // SEZIONE 1: VALIDAZIONI CENTRALIZZATE (Guard Clauses)
  // ==========================================================================

  /// Validazione importo - deve essere > 0, finito e non NaN
  void _validateAmount(double amount, String operation) {
    if (amount <= 0) {
      throw FinancialException(
        code: 'INVALID_AMOUNT',
        message: 'L\'importo deve essere maggiore di zero: $amount',
        operation: operation,
      );
    }
    if (amount.isNaN || amount.isInfinite) {
      throw FinancialException(
        code: 'INVALID_AMOUNT',
        message: 'L\'importo non è un valore numerico valido: $amount',
        operation: operation,
      );
    }
    // Limite massimo per evitare overflow (100 milioni)
    if (amount > 100000000) {
      throw FinancialException(
        code: 'AMOUNT_TOO_LARGE',
        message: 'L\'importo supera il limite massimo consentito: $amount',
        operation: operation,
      );
    }
  }

  /// Validazione riferimento pagamento - almeno uno deve essere presente
  void _validatePaymentReference({
    String? packageId,
    String? appointmentId,
    String? productSaleId,
    required String operation,
  }) {
    if (packageId == null && appointmentId == null && productSaleId == null) {
      throw FinancialException(
        code: 'ORPHAN_PAYMENT',
        message: 'Il pagamento deve essere collegato ad almeno una entità',
        operation: operation,
      );
    }
  }

  /// Validazione client ID - non può essere nullo o vuoto
  void _validateClientId(String? clientId, String operation) {
    if (clientId == null || clientId.isEmpty) {
      throw FinancialException(
        code: 'INVALID_CLIENT',
        message: 'Client ID non valido o mancante',
        operation: operation,
      );
    }
  }

  /// Validazione saldo fidelity sufficiente
  Future<void> _validateFidelityBalance(
    String cardId,
    double amount,
    String operation,
  ) async {
    final card = await (db.select(
      db.fidelityCardsTable,
    )..where((t) => t.id.equals(cardId))).getSingleOrNull();

    if (card == null) {
      throw FinancialException(
        code: 'FIDELITY_CARD_NOT_FOUND',
        message: 'Carta fidelity non trovata: $cardId',
        operation: operation,
      );
    }

    if (card.balance < amount) {
      throw FinancialException(
        code: 'INSUFFICIENT_BALANCE',
        message:
            'Saldo insufficiente: €${card.balance.toStringAsFixed(2)} < €${amount.toStringAsFixed(2)}',
        operation: operation,
        context: {
          'cardId': cardId,
          'balance': card.balance,
          'requested': amount,
        },
      );
    }
  }

  /// Validazione sedute pacchetto disponibili
  Future<void> _validatePackageSessions(
    String packageItemId,
    String operation,
  ) async {
    final item = await (db.select(
      db.packageItemsTable,
    )..where((t) => t.id.equals(packageItemId))).getSingleOrNull();

    if (item == null) {
      throw FinancialException(
        code: 'PACKAGE_ITEM_NOT_FOUND',
        message: 'Item pacchetto non trovato: $packageItemId',
        operation: operation,
      );
    }

    if (item.usedSessions >= item.totalSessions) {
      throw FinancialException(
        code: 'NO_SESSIONS_AVAILABLE',
        message:
            'Nessuna seduta disponibile (${item.usedSessions}/${item.totalSessions})',
        operation: operation,
        context: {
          'packageItemId': packageItemId,
          'used': item.usedSessions,
          'total': item.totalSessions,
        },
      );
    }
  }

  /// Verifica che non esista già un pagamento per la stessa entità
  Future<void> _validateNoDuplicatePayment({
    String? packageId,
    String? appointmentId,
    String? productSaleId,
    required String operation,
  }) async {
    var query = db.select(db.paymentsTable);

    if (packageId != null) {
      query = query..where((t) => t.packageId.equals(packageId));
    } else if (appointmentId != null) {
      query = query..where((t) => t.appointmentId.equals(appointmentId));
    } else if (productSaleId != null) {
      query = query..where((t) => t.productSaleId.equals(productSaleId));
    } else {
      return; // Nessun riferimento, non possiamo controllare duplicati
    }

    final existing = await query.get();

    if (existing.isNotEmpty) {
      throw FinancialException(
        code: 'DUPLICATE_PAYMENT',
        message: 'Esiste già un pagamento per questa entità',
        operation: operation,
        context: {
          'existingPaymentId': existing.first.id,
          'packageId': packageId,
          'appointmentId': appointmentId,
          'productSaleId': productSaleId,
        },
      );
    }
  }

  // ==========================================================================
  // SEZIONE 2: OPERAZIONI FINANZIARIE ATOMICHE
  // ==========================================================================

  /// FLUSSO CRITICO #1: Vendita Prodotto con Pagamento Atomico
  ///
  /// Crea una vendita prodotto E il relativo pagamento in una singola transazione.
  /// Se una delle due operazioni fallisce, entrambe vengono annullate.
  Future<FinancialResult<String>> createProductSaleWithPayment({
    required String clientId,
    required String productId,
    required String lockedProductName,
    required double lockedPrice,
    required int quantity,
    required String paymentMethod,
    String? notes,
    double? discountedPrice,
  }) async {
    final operationId = const Uuid().v7();
    final operation = 'CREATE_PRODUCT_SALE_WITH_PAYMENT';

    try {
      // GUARD CLAUSES
      _validateClientId(clientId, operation);
      _validateAmount(lockedPrice * quantity, operation);

      if (!isOnline) {
        throw FinancialException(
          code: 'OFFLINE_MODE',
          message: 'Operazione non disponibile in modalità offline',
          operation: operation,
        );
      }

      final now = DateTime.now().toUtc();
      // Use discounted price if provided, otherwise use original price
      final actualUnitPrice = discountedPrice ?? lockedPrice;
      final lineTotal = actualUnitPrice * quantity;
      String? saleId;
      String? paymentId;

      // TRANSAZIONE ATOMICA: Tutto o niente
      await db.transaction(() async {
        // 1. Crea la vendita con il prezzo scontato se applicabile
        final sale = await db
            .into(db.productSalesTable)
            .insertReturning(
              ProductSalesTableCompanion.insert(
                id: Value(const Uuid().v7()),
                clientId: Value(clientId),
                productId: productId,
                lockedProductName: lockedProductName.trim(),
                lockedPrice: actualUnitPrice, // Store the actual price paid (discounted)
                quantity: Value(quantity),
                lineTotal: lineTotal,
                createdAt: Value(now),
                isActive: const Value(true),
              ),
            );
        saleId = sale.id;

        // 2. Verifica che non esista già un pagamento (race condition protection)
        // Nota: la verifica del duplicato viene saltata perché la vendita è appena stata creata

        // 3. Crea il pagamento collegato con l'importo scontato
        final payment = await db
            .into(db.paymentsTable)
            .insertReturning(
              PaymentsTableCompanion.insert(
                id: Value(const Uuid().v7()),
                clientId: Value(clientId),
                productSaleId: Value(saleId),
                amount: lineTotal,
                paymentMethod: Value(paymentMethod),
                notes: Value(notes?.trim()),
                paidAt: Value(now),
                createdAt: Value(now),
              ),
            );
        paymentId = payment.id;

        _log.info(
          '[$operation] Transazione completata: saleId=$saleId, paymentId=$paymentId, amount=$lineTotal, discounted=${discountedPrice != null}',
        );
      });

      // Sync a Supabase (fuori dalla transazione locale)
      // Sincronizziamo sia la vendita che il pagamento con Supabase
      try {
        final supabaseClient = Supabase.instance.client;
        if (supabaseClient != null) {
        try {
          // Sync product sale to Supabase
          await _syncProductSaleToSupabase(saleId!);
          // Sync payment to Supabase
          await _syncPaymentToSupabase(paymentId!);
          _log.info('[$operation] Sync completato: saleId=$saleId, paymentId=$paymentId');
        } catch (e) {
          _log.warning('[$operation] Sync Supabase fallito: $e');
          // Non falliamo l'operazione anche se il sync fallisce
        }
        }
      } catch (e) {
        _log.warning('[$operation] Errore accesso Supabase: $e');
        // Continuiamo anche se Supabase non è disponibile
      }

      return FinancialResult.success(saleId!, operationId);
    } on FinancialException catch (e) {
      _log.warning('[$operation] Fallito: ${e.message}', e);
      return FinancialResult.failure(e, operationId);
    } catch (e, stackTrace) {
      _log.severe('[$operation] Errore imprevisto', e, stackTrace);
      return FinancialResult.failure(
        FinancialException(
          code: 'UNEXPECTED_ERROR',
          message: 'Errore imprevisto: $e',
          operation: operation,
        ),
        operationId,
      );
    }
  }

  /// FLUSSO CRITICO #2: Pagamento Pacchetto Atomico
  ///
  /// Registra un pagamento per un pacchetto e aggiorna il paid_amount in modo atomico.
  Future<FinancialResult<String>> createPackagePayment({
    required String clientId,
    required String packageId,
    required double amount,
    required String paymentMethod,
    String? notes,
  }) async {
    final operationId = const Uuid().v7();
    final operation = 'CREATE_PACKAGE_PAYMENT';

    try {
      // GUARD CLAUSES
      _validateClientId(clientId, operation);
      _validateAmount(amount, operation);
      _validatePaymentReference(packageId: packageId, operation: operation);
      await _validateNoDuplicatePayment(
        packageId: packageId,
        operation: operation,
      );

      if (!isOnline) {
        throw FinancialException(
          code: 'OFFLINE_MODE',
          message: 'Operazione non disponibile in modalità offline',
          operation: operation,
        );
      }

      final now = DateTime.now().toUtc();
      String? paymentId;

      // TRANSAZIONE ATOMICA
      await db.transaction(() async {
        // 1. Verifica che il pacchetto esista
        final package = await (db.select(
          db.packagesTable,
        )..where((t) => t.id.equals(packageId))).getSingleOrNull();

        if (package == null) {
          throw FinancialException(
            code: 'PACKAGE_NOT_FOUND',
            message: 'Pacchetto non trovato: $packageId',
            operation: operation,
          );
        }

        // 2. Verifica che il pagamento non superi il totale
        final currentPaid = package.paidAmount;
        if (currentPaid + amount > package.totalPrice) {
          throw FinancialException(
            code: 'PAYMENT_EXCEEDS_TOTAL',
            message:
                'Il pagamento supera il totale del pacchetto: $currentPaid + $amount > ${package.totalPrice}',
            operation: operation,
            context: {
              'packageId': packageId,
              'currentPaid': currentPaid,
              'newAmount': amount,
              'totalPrice': package.totalPrice,
            },
          );
        }

        // 3. Crea il pagamento
        final payment = await db
            .into(db.paymentsTable)
            .insertReturning(
              PaymentsTableCompanion.insert(
                id: Value(const Uuid().v7()),
                clientId: Value(clientId),
                packageId: Value(packageId),
                amount: amount,
                paymentMethod: Value(paymentMethod),
                notes: Value(notes?.trim()),
                paidAt: Value(now),
                createdAt: Value(now),
              ),
            );
        paymentId = payment.id;

        // 4. Aggiorna il paid_amount del pacchetto (denormalizzazione)
        await (db.update(
          db.packagesTable,
        )..where((t) => t.id.equals(packageId))).write(
          PackagesTableCompanion(
            paidAmount: Value(currentPaid + amount),
            updatedAt: Value(now),
          ),
        );

        _log.info(
          '[$operation] Transazione completata: paymentId=$paymentId, packageId=$packageId, amount=$amount',
        );
      });

      // Sync a Supabase (fuori dalla transazione locale)
      try {
        final supabaseClient = Supabase.instance.client;
        if (supabaseClient != null) {
        try {
          // Sync payment to Supabase
          await _syncPaymentToSupabase(paymentId!);
          // Sync package update to Supabase
          await _syncPackageToSupabase(packageId);
          _log.info('[$operation] Sync completato: paymentId=$paymentId, packageId=$packageId');
        } catch (e) {
          _log.warning('[$operation] Sync Supabase fallito: $e');
          // Non falliamo l'operazione anche se il sync fallisce
        }
        }
      } catch (e) {
        _log.warning('[$operation] Errore accesso Supabase: $e');
        // Continuiamo anche se Supabase non è disponibile
      }

      return FinancialResult.success(paymentId!, operationId);
    } on FinancialException catch (e) {
      _log.warning('[$operation] Fallito: ${e.message}', e);
      return FinancialResult.failure(e, operationId);
    } catch (e, stackTrace) {
      _log.severe('[$operation] Errore imprevisto', e, stackTrace);
      return FinancialResult.failure(
        FinancialException(
          code: 'UNEXPECTED_ERROR',
          message: 'Errore imprevisto: $e',
          operation: operation,
        ),
        operationId,
      );
    }
  }

  /// FLUSSO CRITICO #3: Utilizzo Fidelity Atomico
  ///
  /// Scala il saldo fidelity e crea la transazione in modo atomico.
  Future<FinancialResult<String>> useFidelityBalance({
    required String cardId,
    required double amount,
    String? appointmentId,
    String? description,
  }) async {
    final operationId = const Uuid().v7();
    final operation = 'USE_FIDELITY_BALANCE';

    try {
      // GUARD CLAUSES
      _validateAmount(amount, operation);
      await _validateFidelityBalance(cardId, amount, operation);

      if (!isOnline) {
        throw FinancialException(
          code: 'OFFLINE_MODE',
          message: 'Operazione non disponibile in modalità offline',
          operation: operation,
        );
      }

      final now = DateTime.now().toUtc();
      String? transactionId;

      // TRANSAZIONE ATOMICA
      await db.transaction(() async {
        // 1. Recupera carta corrente
        final card = await (db.select(
          db.fidelityCardsTable,
        )..where((t) => t.id.equals(cardId))).getSingle();

        // 2. Aggiorna il saldo (denormalizzazione)
        await (db.update(
          db.fidelityCardsTable,
        )..where((t) => t.id.equals(cardId))).write(
          FidelityCardsTableCompanion(
            balance: Value(card.balance - amount),
            updatedAt: Value(now),
          ),
        );

        // 3. Crea la transazione negativa
        final tx = await db
            .into(db.fidelityTransactionsTable)
            .insertReturning(
              FidelityTransactionsTableCompanion.insert(
                id: Value(const Uuid().v7()),
                fidelityCardId: cardId,
                amount: -amount,
                // Negativo per utilizzo
                type: 'usage',
                appointmentId: Value(appointmentId),
                description: Value(description?.trim()),
                createdAt: Value(now),
              ),
            );
        transactionId = tx.id;

        _log.info(
          '[$operation] Transazione completata: txId=$transactionId, cardId=$cardId, amount=-$amount',
        );
      });

      return FinancialResult.success(transactionId!, operationId);
    } on FinancialException catch (e) {
      _log.warning('[$operation] Fallito: ${e.message}', e);
      return FinancialResult.failure(e, operationId);
    } catch (e, stackTrace) {
      _log.severe('[$operation] Errore imprevisto', e, stackTrace);
      return FinancialResult.failure(
        FinancialException(
          code: 'UNEXPECTED_ERROR',
          message: 'Errore imprevisto: $e',
          operation: operation,
        ),
        operationId,
      );
    }
  }

  /// FLUSSO CRITICO #4: Ricarica Fidelity Atomica
  ///
  /// Aumenta il saldo fidelity e crea la transazione in modo atomico.
  Future<FinancialResult<String>> topupFidelityCard({
    required String cardId,
    required double amount,
    String? description,
  }) async {
    final operationId = const Uuid().v7();
    final operation = 'TOPUP_FIDELITY_CARD';

    try {
      // GUARD CLAUSES
      _validateAmount(amount, operation);

      if (!isOnline) {
        throw FinancialException(
          code: 'OFFLINE_MODE',
          message: 'Operazione non disponibile in modalità offline',
          operation: operation,
        );
      }

      final now = DateTime.now().toUtc();
      String? transactionId;

      // TRANSAZIONE ATOMICA
      await db.transaction(() async {
        // 1. Recupera carta corrente
        final card = await (db.select(
          db.fidelityCardsTable,
        )..where((t) => t.id.equals(cardId))).getSingle();

        // 2. Aggiorna il saldo
        await (db.update(
          db.fidelityCardsTable,
        )..where((t) => t.id.equals(cardId))).write(
          FidelityCardsTableCompanion(
            balance: Value(card.balance + amount),
            updatedAt: Value(now),
          ),
        );

        // 3. Crea la transazione positiva
        final tx = await db
            .into(db.fidelityTransactionsTable)
            .insertReturning(
              FidelityTransactionsTableCompanion.insert(
                id: Value(const Uuid().v7()),
                fidelityCardId: cardId,
                amount: amount,
                // Positivo per ricarica
                type: 'topup',
                description: Value(description?.trim()),
                createdAt: Value(now),
              ),
            );
        transactionId = tx.id;

        _log.info(
          '[$operation] Transazione completata: txId=$transactionId, cardId=$cardId, amount=+$amount',
        );
      });

      return FinancialResult.success(transactionId!, operationId);
    } on FinancialException catch (e) {
      _log.warning('[$operation] Fallito: ${e.message}', e);
      return FinancialResult.failure(e, operationId);
    } catch (e, stackTrace) {
      _log.severe('[$operation] Errore imprevisto', e, stackTrace);
      return FinancialResult.failure(
        FinancialException(
          code: 'UNEXPECTED_ERROR',
          message: 'Errore imprevisto: $e',
          operation: operation,
        ),
        operationId,
      );
    }
  }

  /// FLUSSO CRITICO #5: Utilizzo Seduta Pacchetto Atomico
  ///
  /// Incrementa used_sessions di un package_item.
  Future<FinancialResult<void>> usePackageSession({
    required String packageItemId,
    String? appointmentId,
  }) async {
    final operationId = const Uuid().v7();
    final operation = 'USE_PACKAGE_SESSION';

    try {
      // GUARD CLAUSES
      await _validatePackageSessions(packageItemId, operation);

      if (!isOnline) {
        throw FinancialException(
          code: 'OFFLINE_MODE',
          message: 'Operazione non disponibile in modalità offline',
          operation: operation,
        );
      }

      // TRANSAZIONE ATOMICA
      await db.transaction(() async {
        // 1. Recupera item corrente (con lock implicito per SQLite)
        final item = await (db.select(
          db.packageItemsTable,
        )..where((t) => t.id.equals(packageItemId))).getSingle();

        // 2. Verifica di nuovo (race condition protection in transaction)
        if (item.usedSessions >= item.totalSessions) {
          throw FinancialException(
            code: 'NO_SESSIONS_AVAILABLE',
            message: 'Nessuna seduta disponibile',
            operation: operation,
            context: {
              'packageItemId': packageItemId,
              'used': item.usedSessions,
              'total': item.totalSessions,
            },
          );
        }

        // 3. Incrementa used_sessions
        await (db.update(
          db.packageItemsTable,
        )..where((t) => t.id.equals(packageItemId))).write(
          PackageItemsTableCompanion(
            usedSessions: Value(item.usedSessions + 1),
          ),
        );

        _log.info(
          '[$operation] Transazione completata: packageItemId=$packageItemId, used=${item.usedSessions + 1}/${item.totalSessions}',
        );
      });

      return FinancialResult.success(null, operationId);
    } on FinancialException catch (e) {
      _log.warning('[$operation] Fallito: ${e.message}', e);
      return FinancialResult.failure(e, operationId);
    } catch (e, stackTrace) {
      _log.severe('[$operation] Errore imprevisto', e, stackTrace);
      return FinancialResult.failure(
        FinancialException(
          code: 'UNEXPECTED_ERROR',
          message: 'Errore imprevisto: $e',
          operation: operation,
        ),
        operationId,
      );
    }
  }

  /// FLUSSO CRITICO #6: Rimborso/Annullamento Seduta Pacchetto
  ///
  /// Decrementa used_sessions (per annullamento appuntamento).
  Future<FinancialResult<void>> refundPackageSession({
    required String packageItemId,
  }) async {
    final operationId = const Uuid().v7();
    final operation = 'REFUND_PACKAGE_SESSION';

    try {
      if (!isOnline) {
        throw FinancialException(
          code: 'OFFLINE_MODE',
          message: 'Operazione non disponibile in modalità offline',
          operation: operation,
        );
      }

      // TRANSAZIONE ATOMICA
      await db.transaction(() async {
        // 1. Recupera item corrente
        final item = await (db.select(
          db.packageItemsTable,
        )..where((t) => t.id.equals(packageItemId))).getSingle();

        // 2. Verifica che ci siano sedute da rimborare
        if (item.usedSessions <= 0) {
          throw FinancialException(
            code: 'NO_SESSIONS_TO_REFUND',
            message: 'Nessuna seduta da rimborare',
            operation: operation,
            context: {
              'packageItemId': packageItemId,
              'used': item.usedSessions,
            },
          );
        }

        // 3. Decrementa used_sessions
        await (db.update(
          db.packageItemsTable,
        )..where((t) => t.id.equals(packageItemId))).write(
          PackageItemsTableCompanion(
            usedSessions: Value(item.usedSessions - 1),
          ),
        );

        _log.info(
          '[$operation] Transazione completata: packageItemId=$packageItemId, used=${item.usedSessions - 1}/${item.totalSessions}',
        );
      });

      return FinancialResult.success(null, operationId);
    } on FinancialException catch (e) {
      _log.warning('[$operation] Fallito: ${e.message}', e);
      return FinancialResult.failure(e, operationId);
    } catch (e, stackTrace) {
      _log.severe('[$operation] Errore imprevisto', e, stackTrace);
      return FinancialResult.failure(
        FinancialException(
          code: 'UNEXPECTED_ERROR',
          message: 'Errore imprevisto: $e',
          operation: operation,
        ),
        operationId,
      );
    }
  }

  /// FLUSSO CRITICO #7: Storno/Rimborso Pagamento
  ///
  /// Crea un pagamento negativo per stornare un pagamento precedente.
  Future<FinancialResult<String>> refundPayment({
    required String originalPaymentId,
    String? reason,
  }) async {
    final operationId = const Uuid().v7();
    final operation = 'REFUND_PAYMENT';

    try {
      if (!isOnline) {
        throw FinancialException(
          code: 'OFFLINE_MODE',
          message: 'Operazione non disponibile in modalità offline',
          operation: operation,
        );
      }

      final now = DateTime.now().toUtc();
      String? refundPaymentId;

      // TRANSAZIONE ATOMICA
      await db.transaction(() async {
        // 1. Recupera pagamento originale
        final originalPayment = await (db.select(
          db.paymentsTable,
        )..where((t) => t.id.equals(originalPaymentId))).getSingleOrNull();

        if (originalPayment == null) {
          throw FinancialException(
            code: 'PAYMENT_NOT_FOUND',
            message: 'Pagamento originale non trovato: $originalPaymentId',
            operation: operation,
          );
        }

        // 2. Verifica che non sia già uno storno
        if (originalPayment.amount < 0) {
          throw FinancialException(
            code: 'CANNOT_REFUND_REFUND',
            message: 'Non è possibile stornare un pagamento già negativo',
            operation: operation,
          );
        }

        // 3. Crea il pagamento di storno (importo negativo)
        final refundPayment = await db
            .into(db.paymentsTable)
            .insertReturning(
              PaymentsTableCompanion.insert(
                id: Value(const Uuid().v7()),
                clientId: Value(originalPayment.clientId),
                packageId: Value(originalPayment.packageId),
                appointmentId: Value(originalPayment.appointmentId),
                productSaleId: Value(originalPayment.productSaleId),
                amount: -originalPayment.amount.abs(),
                // Importo negativo
                paymentMethod: Value(originalPayment.paymentMethod),
                notes: Value(
                  'Storno pagamento ${originalPayment.id}${reason != null ? ': $reason' : ''}',
                ),
                paidAt: Value(now),
                createdAt: Value(now),
              ),
            );
        refundPaymentId = refundPayment.id;

        // 4. Se è un pagamento pacchetto, aggiorna paid_amount
        if (originalPayment.packageId != null) {
          final package = await (db.select(
            db.packagesTable,
          )..where((t) => t.id.equals(originalPayment.packageId!))).getSingle();

          await (db.update(
            db.packagesTable,
          )..where((t) => t.id.equals(originalPayment.packageId!))).write(
            PackagesTableCompanion(
              paidAmount: Value(package.paidAmount - originalPayment.amount),
              updatedAt: Value(now),
            ),
          );
        }

        _log.info(
          '[$operation] Transazione completata: refundId=$refundPaymentId, originalId=$originalPaymentId, amount=${-originalPayment.amount}',
        );
      });

      return FinancialResult.success(refundPaymentId!, operationId);
    } on FinancialException catch (e) {
      _log.warning('[$operation] Fallito: ${e.message}', e);
      return FinancialResult.failure(e, operationId);
    } catch (e, stackTrace) {
      _log.severe('[$operation] Errore imprevisto', e, stackTrace);
      return FinancialResult.failure(
        FinancialException(
          code: 'UNEXPECTED_ERROR',
          message: 'Errore imprevisto: $e',
          operation: operation,
        ),
        operationId,
      );
    }
  }

  // ==========================================================================
  // SEZIONE 3: OPERAZIONI COMPLESSE (Multi-step)
  // ==========================================================================

  /// FLUSSO COMPLESSO #1: Appuntamento con Pagamento Diretto Atomico
  ///
  /// Crea un appuntamento, i suoi servizi, e i relativi pagamenti in una
  /// singola transazione atomica.
  Future<FinancialResult<String>> createAppointmentWithDirectPayment({
    required int operatorId,
    required String clientId,
    required int cabinId,
    required DateTime startDateTime,
    required DateTime endDateTime,
    required List<AppointmentServiceInput> services,
    String? notes,
  }) async {
    final operationId = const Uuid().v7();
    final operation = 'CREATE_APPOINTMENT_WITH_PAYMENT';

    try {
      // GUARD CLAUSES
      _validateClientId(clientId, operation);

      if (services.isEmpty) {
        throw FinancialException(
          code: 'NO_SERVICES',
          message: 'Almeno un servizio è richiesto',
          operation: operation,
        );
      }

      if (!isOnline) {
        throw FinancialException(
          code: 'OFFLINE_MODE',
          message: 'Operazione non disponibile in modalità offline',
          operation: operation,
        );
      }

      final now = DateTime.now().toUtc();
      String? appointmentId;

      // TRANSAZIONE ATOMICA
      await db.transaction(() async {
        // 1. Crea l'appuntamento
        final appointment = await db
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
                createdAt: Value(now),
                updatedAt: Value(now),
                isActive: const Value(true),
              ),
            );
        appointmentId = appointment.id;

        // 2. Crea i servizi e gestisci pagamenti/fidelity/pacchetti
        for (final service in services) {
          // Crea il servizio associato
          await db
              .into(db.appointmentServicesTable)
              .insert(
                AppointmentServicesTableCompanion.insert(
                  id: Value(const Uuid().v7()),
                  appointmentId: appointmentId!,
                  serviceId: service.serviceId,
                  lockedPrice: service.lockedPrice,
                  lockedDuration: service.lockedDuration,
                  packageItemId: Value(service.packageItemId),
                  fidelityCardId: Value(service.fidelityCardId),
                  paymentSource: Value(service.paymentSource),
                ),
              );

          // Gestisci pagamento in base al tipo
          switch (service.paymentSource) {
            case 'direct':
              // Crea pagamento diretto
              await db
                  .into(db.paymentsTable)
                  .insert(
                    PaymentsTableCompanion.insert(
                      id: Value(const Uuid().v7()),
                      clientId: Value(clientId),
                      appointmentId: Value(appointmentId),
                      amount: service.lockedPrice,
                      paymentMethod: const Value('cash'),
                      notes: Value(
                        'Pagamento per servizio: ${service.serviceId}',
                      ),
                      paidAt: Value(now),
                      createdAt: Value(now),
                    ),
                  );
              break;

            case 'fidelity':
              if (service.fidelityCardId == null) {
                throw FinancialException(
                  code: 'MISSING_FIDELITY_CARD',
                  message: 'Fidelity card richiesta per pagamento fidelity',
                  operation: operation,
                );
              }
              // Scala fidelity
              final card =
                  await (db.select(db.fidelityCardsTable)
                        ..where((t) => t.id.equals(service.fidelityCardId!)))
                      .getSingle();

              if (card.balance < service.lockedPrice) {
                throw FinancialException(
                  code: 'INSUFFICIENT_FIDELITY_BALANCE',
                  message: 'Saldo fidelity insufficiente',
                  operation: operation,
                );
              }

              await (db.update(
                db.fidelityCardsTable,
              )..where((t) => t.id.equals(service.fidelityCardId!))).write(
                FidelityCardsTableCompanion(
                  balance: Value(card.balance - service.lockedPrice),
                  updatedAt: Value(now),
                ),
              );

              await db
                  .into(db.fidelityTransactionsTable)
                  .insert(
                    FidelityTransactionsTableCompanion.insert(
                      id: Value(const Uuid().v7()),
                      fidelityCardId: service.fidelityCardId!,
                      amount: -service.lockedPrice,
                      type: 'usage',
                      appointmentId: Value(appointmentId),
                      description: Value(
                        'Utilizzo per servizio: ${service.serviceId}',
                      ),
                      createdAt: Value(now),
                    ),
                  );
              break;

            case 'package':
              if (service.packageItemId == null) {
                throw FinancialException(
                  code: 'MISSING_PACKAGE_ITEM',
                  message: 'Package item richiesto per pagamento pacchetto',
                  operation: operation,
                );
              }
              // Scala seduta pacchetto
              final item = await (db.select(
                db.packageItemsTable,
              )..where((t) => t.id.equals(service.packageItemId!))).getSingle();

              if (item.usedSessions >= item.totalSessions) {
                throw FinancialException(
                  code: 'NO_PACKAGE_SESSIONS',
                  message: 'Nessuna seduta disponibile nel pacchetto',
                  operation: operation,
                );
              }

              await (db.update(
                db.packageItemsTable,
              )..where((t) => t.id.equals(service.packageItemId!))).write(
                PackageItemsTableCompanion(
                  usedSessions: Value(item.usedSessions + 1),
                ),
              );
              break;
          }
        }

        _log.info(
          '[$operation] Transazione completata: appointmentId=$appointmentId, services=${services.length}',
        );
      });

      return FinancialResult.success(appointmentId!, operationId);
    } on FinancialException catch (e) {
      _log.warning('[$operation] Fallito: ${e.message}', e);
      return FinancialResult.failure(e, operationId);
    } catch (e, stackTrace) {
      _log.severe('[$operation] Errore imprevisto', e, stackTrace);
      return FinancialResult.failure(
        FinancialException(
          code: 'UNEXPECTED_ERROR',
          message: 'Errore imprevisto: $e',
          operation: operation,
        ),
        operationId,
      );
    }
  }

  // ==========================================================================
  // SEZIONE 4: UTILITÀ DI VERIFICA INTEGRITÀ
  // ==========================================================================

  /// Sync product sale to Supabase
  Future<void> _syncProductSaleToSupabase(String saleId) async {
    try {
      final localSale = await (db.select(db.productSalesTable)
            ..where((t) => t.id.equals(saleId)))
          .getSingle();

      await Supabase.instance.client.from('product_sales').upsert({
        'id': localSale.id,
        'client_id': localSale.clientId,
        'product_id': localSale.productId,
        'locked_product_name': localSale.lockedProductName,
        'locked_price': localSale.lockedPrice,
        'quantity': localSale.quantity,
        'line_total': localSale.lineTotal,
        'created_at': localSale.createdAt.toIso8601String(),
        'is_active': localSale.isActive,
      });

      _log.info('Product sale $saleId synced to Supabase');
    } catch (e) {
      _log.warning('Failed to sync product sale $saleId to Supabase: $e');
      rethrow;
    }
  }

  /// Sync payment to Supabase
  Future<void> _syncPaymentToSupabase(String paymentId) async {
    try {
      final localPayment = await (db.select(db.paymentsTable)
            ..where((t) => t.id.equals(paymentId)))
          .getSingle();

      await Supabase.instance.client.from('payments').upsert({
        'id': localPayment.id,
        'client_id': localPayment.clientId,
        'package_id': localPayment.packageId,
        'appointment_id': localPayment.appointmentId,
        'product_sale_id': localPayment.productSaleId,
        'amount': localPayment.amount,
        'payment_method': localPayment.paymentMethod,
        'notes': localPayment.notes,
        'paid_at': localPayment.paidAt.toIso8601String(),
        'created_at': localPayment.createdAt.toIso8601String(),
      });

      _log.info('Payment $paymentId synced to Supabase');
    } catch (e) {
      _log.warning('Failed to sync payment $paymentId to Supabase: $e');
      rethrow;
    }
  }

  /// Sync package to Supabase
  Future<void> _syncPackageToSupabase(String packageId) async {
    try {
      final localPackage = await (db.select(db.packagesTable)
            ..where((t) => t.id.equals(packageId)))
          .getSingle();

      await Supabase.instance.client.from('packages').upsert({
        'id': localPackage.id,
        'client_id': localPackage.clientId,
        'name': localPackage.name,
        'total_price': localPackage.totalPrice,
        'paid_amount': localPackage.paidAmount,
        'created_at': localPackage.createdAt.toIso8601String(),
        'updated_at': localPackage.updatedAt.toIso8601String(),
        'is_active': localPackage.isActive,
      });

      _log.info('Package $packageId synced to Supabase');
    } catch (e) {
      _log.warning('Failed to sync package $packageId to Supabase: $e');
      rethrow;
    }
  }

  /// Verifica integrità completa del sistema finanziario
  Future<Map<String, List<Map<String, dynamic>>>>
  verifyFinancialIntegrity() async {
    final result = <String, List<Map<String, dynamic>>>{
      'payment_orphans': [],
      'payment_duplicates': [],
      'fidelity_mismatches': [],
      'package_mismatches': [],
      'negative_amounts': [],
    };

    // 1. Trova pagamenti orfani
    final orphanPayments =
        await (db.select(db.paymentsTable)..where(
              (t) =>
                  t.packageId.isNull() &
                  t.appointmentId.isNull() &
                  t.productSaleId.isNull(),
            ))
            .get();

    result['payment_orphans'] = orphanPayments
        .map((p) => {'id': p.id, 'amount': p.amount, 'client_id': p.clientId})
        .toList();

    // 2. Trova pagamenti duplicati per stessa entità
    final allPayments = await db.select(db.paymentsTable).get();
    final paymentGroups = <String, List<PaymentData>>{};

    for (final p in allPayments) {
      final key = '${p.packageId}_${p.appointmentId}_${p.productSaleId}';
      paymentGroups.putIfAbsent(key, () => []).add(p);
    }

    result['payment_duplicates'] = paymentGroups.entries
        .where((e) => e.value.length > 1 && e.key != 'null_null_null')
        .expand(
          (e) => e.value.map(
            (p) => {'id': p.id, 'entity_key': e.key, 'amount': p.amount},
          ),
        )
        .toList();

    // 3. Verifica saldi fidelity
    final cards = await db.select(db.fidelityCardsTable).get();
    for (final card in cards) {
      final transactions = await (db.select(
        db.fidelityTransactionsTable,
      )..where((t) => t.fidelityCardId.equals(card.id))).get();

      final calculatedBalance = transactions.fold<double>(
        0,
        (sum, t) => sum + t.amount,
      );

      if ((calculatedBalance - card.balance).abs() > 0.01) {
        result['fidelity_mismatches']!.add({
          'card_id': card.id,
          'stored_balance': card.balance,
          'calculated_balance': calculatedBalance,
          'difference': calculatedBalance - card.balance,
        });
      }
    }

    // 4. Verifica paid_amount pacchetti
    final packages = await db.select(db.packagesTable).get();
    for (final pkg in packages) {
      final payments = await (db.select(
        db.paymentsTable,
      )..where((t) => t.packageId.equals(pkg.id))).get();

      final totalPaid = payments.fold<double>(0, (sum, p) => sum + p.amount);

      if ((totalPaid - pkg.paidAmount).abs() > 0.01) {
        result['package_mismatches']!.add({
          'package_id': pkg.id,
          'stored_paid': pkg.paidAmount,
          'calculated_paid': totalPaid,
          'difference': totalPaid - pkg.paidAmount,
        });
      }
    }

    return result;
  }
}

/// Input per servizio appuntamento
class AppointmentServiceInput {
  final String serviceId;
  final double lockedPrice;
  final int lockedDuration;
  final String paymentSource; // 'direct', 'fidelity', 'package'
  final String? packageItemId;
  final String? fidelityCardId;

  AppointmentServiceInput({
    required this.serviceId,
    required this.lockedPrice,
    required this.lockedDuration,
    required this.paymentSource,
    this.packageItemId,
    this.fidelityCardId,
  });
}
