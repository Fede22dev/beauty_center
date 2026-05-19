// ============================================================================
// SYNC ORCHESTRATOR SERVICE
// Gestisce la sincronizzazione ordinata con rispetto delle dipendenze FK
// ============================================================================
//
// PROBLEMA: syncAsync è fire-and-forget e non garantisce l'ordine.
// Quando creiamo: 1) Pacchetto → 2) Pagamento
// La sync può inviare prima il pagamento, causando errore FK su Supabase.
//
// SOLUZIONE: Queue ordinata con dependency tracking.
// Le entità "padre" (packages, quotes) vengono sincronizzate PRIMA
// delle entità "figlie" (payments) che hanno FK verso di esse.
//
// ARCHITETTURA:
// - SyncQueue: coda prioritaria con ordinamento per tipo entità
// - DependencyGraph: definisce l'ordine di sincronizzazione
// - BatchSync: raggruppa operazioni correlate in un batch atomico
// ============================================================================

import 'dart:async';
import 'dart:collection';

import '../database/app_database.dart';
import '../database/supabase_schema.dart';
import '../logging/app_logger.dart';
import '../database/repositories/base_repository.dart';

/// Livello di priorità nella coda di sync
/// Più basso = più prioritario (sincronizzato prima)
enum SyncPriority {
  /// Clienti (nessuna dipendenza)
  clients(1),
  
  /// Cataloghi (nessuna dipendenza)
  catalog(2),
  
  /// Pacchetti (dipendono da clienti)
  packages(3),
  
  /// Preventivi (dipendono da clienti)
  quotes(3),
  
  /// Appuntamenti (dipendono da clienti, operatori, cabin)
  appointments(4),
  
  /// Servizi appuntamento (dipendono da appuntamenti)
  appointmentServices(5),
  
  /// Fidelity cards (dipendono da clienti)
  fidelityCards(4),
  
  /// Transazioni fidelity (dipendono da fidelity cards)
  fidelityTransactions(5),
  
  /// Item pacchetti (dipendono da pacchetti)
  packageItems(4),
  
  /// Vendite prodotti (dipendono da clienti, prodotti)
  productSales(4),
  
  /// Pagamenti (dipendono da TUTTO)
  /// Questo è il livello più alto perché i pagamenti hanno FK
  /// verso packages, appointments, product_sales
  payments(10),
  
  /// Settings (nessuna dipendenza)
  settings(1);

  final int level;
  const SyncPriority(this.level);
}

/// Operazione di sync in coda
class _SyncOperation {
  final String id;
  final SyncPriority priority;
  final Future<void> Function() operation;
  final DateTime queuedAt;
  final String entityType;
  final String? entityId;
  
  /// ID delle operazioni da completare prima di questa
  final List<String>? dependencies;

  _SyncOperation({
    required this.id,
    required this.priority,
    required this.operation,
    required this.entityType,
    this.entityId,
    this.dependencies,
  }) : queuedAt = DateTime.now();
}

/// Raggruppa operazioni correlate in un batch atomico
/// 
/// Esempio: creazione di un pacchetto con pagamento
/// - Il pacchetto DEVE essere sincronizzato prima del pagamento
/// - Se il pagamento fallisce, il pacchetto rimane comunque sincronizzato
///   (non facciamo rollback su Supabase, solo retry)
class SyncBatch {
  final String batchId;
  final List<_SyncOperation> operations;
  final DateTime createdAt;
  
  SyncBatch._(this.batchId, this.operations) : createdAt = DateTime.now();
  
  /// Crea un batch per operazioni correlate
  /// Esempio: [packageOp, paymentOp] dove payment dipende da package
  factory SyncBatch.create({
    required String batchId,
    required List<SyncBatchItem> items,
  }) {
    final operations = <_SyncOperation>[];
    final completedIds = <String>[];
    
    // Ordina per priorità
    items.sort((a, b) => a.priority.level.compareTo(b.priority.level));
    
    for (var i = 0; i < items.length; i++) {
      final item = items[i];
      
      // Le operazioni successive dipendono da quelle precedenti
      final deps = i > 0 ? [...completedIds] : null;
      
      final op = _SyncOperation(
        id: '${batchId}_${item.entityType}_${item.entityId ?? i}',
        priority: item.priority,
        operation: item.operation,
        entityType: item.entityType,
        entityId: item.entityId,
        dependencies: deps,
      );
      
      operations.add(op);
      completedIds.add(op.id);
    }
    
    return SyncBatch._(batchId, operations);
  }
}

/// Item per SyncBatch
class SyncBatchItem {
  final SyncPriority priority;
  final Future<void> Function() operation;
  final String entityType;
  final String? entityId;

  SyncBatchItem({
    required this.priority,
    required this.operation,
    required this.entityType,
    this.entityId,
  });
}

/// Service che orchestra la sincronizzazione con rispetto delle dipendenze
class SyncOrchestratorService {
  SyncOrchestratorService({
    required this.db,
    required this.supabase,
    required this.isOnline,
  });

  final AppDatabase db;
  final dynamic supabase;
  final bool Function() isOnline;

  static final _log = AppLogger.getLogger(name: 'SyncOrchestrator');
  
  /// Coda prioritaria di operazioni
  final Queue<_SyncOperation> _queue = Queue<_SyncOperation>();
  
  /// Operazioni completate (per dependency tracking)
  final Set<String> _completedOperations = <String>{};
  
  /// Operazioni fallite (per retry)
  final Map<String, int> _failedAttempts = <String, int>{};
  static const int _maxRetries = 5;
  
  /// Timer per processare la coda
  Timer? _processTimer;
  
  /// Stato di processing
  bool _isProcessing = false;
  
  /// Stream controller per notificare stato sync
  final _statusController = StreamController<SyncStatus>.broadcast();
  Stream<SyncStatus> get statusStream => _statusController.stream;

  // ==========================================================================
  // PUBLIC API
  // ==========================================================================

  /// Inizializza il service e avvia il timer di processing
  void initialize() {
    _log.info('SyncOrchestrator initialized');
    _startProcessingTimer();
  }

  /// Ferma il service
  void dispose() {
    _processTimer?.cancel();
    _statusController.close();
  }

  /// Accoda una singola operazione di sync
  void enqueue({
    required SyncPriority priority,
    required String entityType,
    String? entityId,
    required Future<void> Function() operation,
    List<String>? dependencies,
  }) {
    if (!isOnline()) {
      _log.finest('Offline, skipping sync enqueue for $entityType');
      return;
    }

    final op = _SyncOperation(
      id: '${entityType}_${entityId ?? DateTime.now().millisecondsSinceEpoch}',
      priority: priority,
      operation: operation,
      entityType: entityType,
      entityId: entityId,
      dependencies: dependencies,
    );

    // Inserisci in ordine di priorità
    _insertInPriorityOrder(op);
    
    _log.finest('Enqueued ${op.id} with priority ${priority.level}');
    _notifyStatusUpdate();
  }

  /// Accoda un batch di operazioni correlate
  void enqueueBatch(SyncBatch batch) {
    if (!isOnline()) {
      _log.finest('Offline, skipping sync batch ${batch.batchId}');
      return;
    }

    for (final op in batch.operations) {
      _insertInPriorityOrder(op);
    }

    _log.info('Enqueued batch ${batch.batchId} with ${batch.operations.length} operations');
    _notifyStatusUpdate();
  }

  /// Forza l'elaborazione immediata della coda
  Future<void> flush() async {
    await _processQueue();
  }

  /// Restituisce lo stato attuale della coda
  SyncStatus get currentStatus => SyncStatus(
    queueLength: _queue.length,
    pendingOperations: _queue.map((op) => op.id).toList(),
    failedOperations: _failedAttempts.keys.toList(),
    isProcessing: _isProcessing,
  );

  // ==========================================================================
  // PRIVATE IMPLEMENTATION
  // ==========================================================================

  void _insertInPriorityOrder(_SyncOperation op) {
    // Se la coda è vuota o l'op ha priorità più alta (level minore), aggiungi in testa
    if (_queue.isEmpty || op.priority.level < _queue.first.priority.level) {
      _queue.addFirst(op);
      return;
    }

    // Trova la posizione corretta
    final iter = _queue.iterator;
    var index = 0;
    while (iter.moveNext()) {
      if (iter.current.priority.level > op.priority.level) {
        break;
      }
      index++;
    }

    // Inserisci alla posizione trovata
    if (index >= _queue.length) {
      _queue.addLast(op);
    } else {
      // Dart Queue non supporta insertAt, quindi ricostruiamo
      final temp = _queue.toList();
      _queue.clear();
      for (var i = 0; i < temp.length; i++) {
        if (i == index) {
          _queue.add(op);
        }
        _queue.add(temp[i]);
      }
      if (index >= temp.length) {
        _queue.add(op);
      }
    }
  }

  void _startProcessingTimer() {
    _processTimer?.cancel();
    _processTimer = Timer.periodic(
      const Duration(seconds: 2),
      (_) => _processQueue(),
    );
  }

  Future<void> _processQueue() async {
    if (_isProcessing || _queue.isEmpty || !isOnline()) return;

    _isProcessing = true;
    _notifyStatusUpdate();

    try {
      while (_queue.isNotEmpty && isOnline()) {
        final op = _queue.first;

        // Verifica dipendenze
        if (op.dependencies != null && op.dependencies!.isNotEmpty) {
          final pendingDeps = op.dependencies!
              .where((dep) => !_completedOperations.contains(dep))
              .toList();

          if (pendingDeps.isNotEmpty) {
            _log.finest('Operation ${op.id} waiting for dependencies: $pendingDeps');
            // Sposta in fondo alla coda (stessa priorità)
            _queue.removeFirst();
            _queue.addLast(op);
            
            // Se tutte le op in coda hanno dipendenze pendenti, break per evitare loop
            if (_queue.every((o) => 
                o.dependencies?.any((d) => !_completedOperations.contains(d)) ?? false)) {
              _log.warning('Deadlock detected in sync queue, breaking');
              break;
            }
            continue;
          }
        }

        // Esegui l'operazione
        _queue.removeFirst();
        
        try {
          _log.finest('Processing sync operation: ${op.id}');
          await op.operation();
          
          // Successo
          _completedOperations.add(op.id);
          _failedAttempts.remove(op.id);
          _log.finest('Sync operation completed: ${op.id}');
          
        } catch (e) {
          // Fallimento
          final attempts = (_failedAttempts[op.id] ?? 0) + 1;
          _failedAttempts[op.id] = attempts;
          
          _log.warning('Sync operation failed (${attempts}/$_maxRetries): ${op.id}', e);
          
          if (attempts < _maxRetries) {
            // Riaggiungi in coda con delay crescente
            await Future.delayed(Duration(seconds: attempts * 2));
            _queue.addLast(op);
          } else {
            _log.severe('Sync operation failed permanently after $_maxRetries attempts: ${op.id}', e);
            // Continua con le altre operazioni
          }
        }
      }
    } finally {
      _isProcessing = false;
      _notifyStatusUpdate();
    }
  }

  void _notifyStatusUpdate() {
    if (!_statusController.isClosed) {
      _statusController.add(currentStatus);
    }
  }
}

/// Stato della sincronizzazione
class SyncStatus {
  final int queueLength;
  final List<String> pendingOperations;
  final List<String> failedOperations;
  final bool isProcessing;

  SyncStatus({
    required this.queueLength,
    required this.pendingOperations,
    required this.failedOperations,
    required this.isProcessing,
  });

  bool get hasPendingOperations => queueLength > 0;
  bool get hasFailedOperations => failedOperations.isNotEmpty;
}

// ============================================================================
// EXTENSION METHODS PER BASE REPOSITORY
// ============================================================================

/// Extension per usare SyncOrchestrator dai repository
extension SyncOrchestratorExtension on BaseRepository {
  /// Sincronizza un'entità con la priorità corretta
  void syncWithPriority({
    required SyncPriority priority,
    required String entityType,
    String? entityId,
    required Future<void> Function() operation,
    List<String>? dependencies,
  }) {
    // Questo è un placeholder - il vero implementazione richiede
    // l'accesso all'istanza singleton di SyncOrchestratorService
    // che dovrebbe essere fornita tramite provider
  }
}
