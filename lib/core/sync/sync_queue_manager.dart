import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';
import 'package:uuid/uuid.dart';

import '../logging/app_logger.dart';

part 'sync_queue_manager.g.dart';

/// Types of sync operations that can be queued
enum SyncOperationType {
  create,
  update,
  delete,
  batchCreate,
  batchUpdate,
  batchDelete,
}

/// Status of a sync operation in the queue
enum SyncOperationStatus {
  pending,
  inProgress,
  completed,
  failed,
  retrying,
  conflict,
}

/// Priority levels for sync operations
enum SyncPriority { low, normal, high, critical }

/// A single sync operation in the queue
class SyncOperation {
  final String id;
  final String entityType;
  final String entityId;
  final SyncOperationType type;
  final SyncPriority priority;
  final Map<String, dynamic> data;
  final DateTime createdAt;
  DateTime? processedAt;
  DateTime? completedAt;
  String? errorMessage;
  int retryCount;
  SyncOperationStatus status;

  SyncOperation({
    String? id,
    required this.entityType,
    required this.entityId,
    required this.type,
    this.priority = SyncPriority.normal,
    required this.data,
    DateTime? createdAt,
    this.processedAt,
    this.completedAt,
    this.errorMessage,
    this.retryCount = 0,
    this.status = SyncOperationStatus.pending,
  }) : id = id ?? const Uuid().v7(),
       createdAt = createdAt ?? DateTime.now();

  Map<String, dynamic> toJson() => {
    'id': id,
    'entityType': entityType,
    'entityId': entityId,
    'type': type.name,
    'priority': priority.name,
    'data': data,
    'createdAt': createdAt.toIso8601String(),
    'processedAt': processedAt?.toIso8601String(),
    'completedAt': completedAt?.toIso8601String(),
    'errorMessage': errorMessage,
    'retryCount': retryCount,
    'status': status.name,
  };

  factory SyncOperation.fromJson(Map<String, dynamic> json) => SyncOperation(
    id: json['id'] as String,
    entityType: json['entityType'] as String,
    entityId: json['entityId'] as String,
    type: SyncOperationType.values.firstWhere(
      (e) => e.name == json['type'],
      orElse: () => SyncOperationType.create,
    ),
    priority: SyncPriority.values.firstWhere(
      (e) => e.name == json['priority'],
      orElse: () => SyncPriority.normal,
    ),
    data: json['data'] as Map<String, dynamic>,
    createdAt: DateTime.parse(json['createdAt'] as String),
    processedAt: json['processedAt'] != null
        ? DateTime.parse(json['processedAt'] as String)
        : null,
    completedAt: json['completedAt'] != null
        ? DateTime.parse(json['completedAt'] as String)
        : null,
    errorMessage: json['errorMessage'] as String?,
    retryCount: json['retryCount'] as int? ?? 0,
    status: SyncOperationStatus.values.firstWhere(
      (e) => e.name == json['status'],
      orElse: () => SyncOperationStatus.pending,
    ),
  );

  /// Get display name for this operation
  String get displayName {
    final typeStr = switch (type) {
      SyncOperationType.create => 'Creazione',
      SyncOperationType.update => 'Aggiornamento',
      SyncOperationType.delete => 'Eliminazione',
      SyncOperationType.batchCreate => 'Creazione multipla',
      SyncOperationType.batchUpdate => 'Aggiornamento multiplo',
      SyncOperationType.batchDelete => 'Eliminazione multipla',
    };
    return '$typeStr ${entityType.toLowerCase()}';
  }

  /// Human-readable status
  String get statusText => switch (status) {
    SyncOperationStatus.pending => 'In attesa',
    SyncOperationStatus.inProgress => 'In corso',
    SyncOperationStatus.completed => 'Completato',
    SyncOperationStatus.failed => 'Fallito',
    SyncOperationStatus.retrying => 'Nuovo tentativo',
    SyncOperationStatus.conflict => 'Conflitto',
  };

  /// Icon for this status
  IconData get statusIcon => switch (status) {
    SyncOperationStatus.pending => Icons.schedule,
    SyncOperationStatus.inProgress => Icons.sync,
    SyncOperationStatus.completed => Icons.check_circle,
    SyncOperationStatus.failed => Icons.error,
    SyncOperationStatus.retrying => Icons.refresh,
    SyncOperationStatus.conflict => Icons.warning,
  };

  /// Color for this status
  Color statusColor(ColorScheme colorScheme) => switch (status) {
    SyncOperationStatus.pending => colorScheme.outline,
    SyncOperationStatus.inProgress => colorScheme.primary,
    SyncOperationStatus.completed => Colors.green,
    SyncOperationStatus.failed => colorScheme.error,
    SyncOperationStatus.retrying => Colors.orange,
    SyncOperationStatus.conflict => Colors.deepOrange,
  };

  SyncOperation copyWith({
    SyncOperationStatus? status,
    DateTime? processedAt,
    DateTime? completedAt,
    String? errorMessage,
    int? retryCount,
  }) => SyncOperation(
    id: id,
    entityType: entityType,
    entityId: entityId,
    type: type,
    priority: priority,
    data: data,
    createdAt: createdAt,
    processedAt: processedAt ?? this.processedAt,
    completedAt: completedAt ?? this.completedAt,
    errorMessage: errorMessage ?? this.errorMessage,
    retryCount: retryCount ?? this.retryCount,
    status: status ?? this.status,
  );
}

/// Manager for the sync queue
class SyncQueueManager extends ChangeNotifier {
  static final _log = AppLogger.getLogger(name: 'SyncQueueManager');

  final List<SyncOperation> _operations = [];
  final _maxRetries = 3;
  final _retryDelays = [
    const Duration(seconds: 5),
    const Duration(seconds: 15),
    const Duration(seconds: 60),
  ];

  List<SyncOperation> get operations => List.unmodifiable(_operations);

  /// Get pending operations count
  int get pendingCount => _operations
      .where((op) => op.status == SyncOperationStatus.pending)
      .length;

  /// Get failed operations count
  int get failedCount =>
      _operations.where((op) => op.status == SyncOperationStatus.failed).length;

  /// Get operations needing retry
  List<SyncOperation> get retryableOperations => _operations
      .where(
        (op) =>
            op.status == SyncOperationStatus.failed &&
            op.retryCount < _maxRetries,
      )
      .toList();

  /// Check if there are any pending or in-progress operations
  bool get hasPendingOperations => _operations.any(
    (op) =>
        op.status == SyncOperationStatus.pending ||
        op.status == SyncOperationStatus.inProgress,
  );

  /// Add operation to queue
  void addOperation(SyncOperation operation) {
    _operations.add(operation);
    _sortByPriority();
    _log.finest('Added sync operation: ${operation.displayName}');
    notifyListeners();
  }

  /// Add multiple operations
  void addOperations(List<SyncOperation> operations) {
    _operations.addAll(operations);
    _sortByPriority();
    _log.finest('Added ${operations.length} sync operations');
    notifyListeners();
  }

  /// Mark operation as in progress
  void markInProgress(String operationId) {
    final index = _operations.indexWhere((op) => op.id == operationId);
    if (index != -1) {
      _operations[index] = _operations[index].copyWith(
        status: SyncOperationStatus.inProgress,
        processedAt: DateTime.now(),
      );
      notifyListeners();
    }
  }

  /// Mark operation as completed
  void markCompleted(String operationId) {
    final index = _operations.indexWhere((op) => op.id == operationId);
    if (index != -1) {
      _operations[index] = _operations[index].copyWith(
        status: SyncOperationStatus.completed,
        completedAt: DateTime.now(),
      );
      _log.finest(
        'Sync operation completed: ${_operations[index].displayName}',
      );
      notifyListeners();
    }
  }

  /// Mark operation as failed
  void markFailed(String operationId, String error) {
    final index = _operations.indexWhere((op) => op.id == operationId);
    if (index != -1) {
      final op = _operations[index];
      final newRetryCount = op.retryCount + 1;

      _operations[index] = op.copyWith(
        status: newRetryCount >= _maxRetries
            ? SyncOperationStatus.failed
            : SyncOperationStatus.retrying,
        errorMessage: error,
        retryCount: newRetryCount,
      );

      _log.warning(
        'Sync operation failed: ${op.displayName} (retry $newRetryCount/$_maxRetries)',
      );
      notifyListeners();

      // Auto-retry if under max retries
      if (newRetryCount < _maxRetries) {
        _scheduleRetry(operationId, _retryDelays[newRetryCount - 1]);
      }
    }
  }

  /// Mark operation as having conflict
  void markConflict(String operationId, String details) {
    final index = _operations.indexWhere((op) => op.id == operationId);
    if (index != -1) {
      _operations[index] = _operations[index].copyWith(
        status: SyncOperationStatus.conflict,
        errorMessage: details,
      );
      _log.warning(
        'Sync conflict: ${_operations[index].displayName} - $details',
      );
      notifyListeners();
    }
  }

  /// Remove completed operations older than [olderThan]
  void cleanupCompleted({Duration olderThan = const Duration(hours: 24)}) {
    final cutoff = DateTime.now().subtract(olderThan);
    _operations.removeWhere(
      (op) =>
          op.status == SyncOperationStatus.completed &&
          op.completedAt != null &&
          op.completedAt!.isBefore(cutoff),
    );
    notifyListeners();
  }

  /// Clear all operations
  void clearAll() {
    _operations.clear();
    notifyListeners();
  }

  /// Get next pending operation (highest priority first)
  SyncOperation? getNextPending() {
    try {
      return _operations.firstWhere(
        (op) => op.status == SyncOperationStatus.pending,
      );
    } catch (_) {
      return null;
    }
  }

  void _sortByPriority() {
    final priorityOrder = {
      SyncPriority.critical: 0,
      SyncPriority.high: 1,
      SyncPriority.normal: 2,
      SyncPriority.low: 3,
    };

    _operations.sort((a, b) {
      // First by status (pending first)
      final statusOrder = {
        SyncOperationStatus.pending: 0,
        SyncOperationStatus.inProgress: 1,
        SyncOperationStatus.retrying: 2,
        SyncOperationStatus.failed: 3,
        SyncOperationStatus.conflict: 4,
        SyncOperationStatus.completed: 5,
      };

      final statusCompare = (statusOrder[a.status] ?? 999).compareTo(
        statusOrder[b.status] ?? 999,
      );
      if (statusCompare != 0) return statusCompare;

      // Then by priority
      final priorityCompare = (priorityOrder[a.priority] ?? 999).compareTo(
        priorityOrder[b.priority] ?? 999,
      );
      if (priorityCompare != 0) return priorityCompare;

      // Finally by creation time (oldest first)
      return a.createdAt.compareTo(b.createdAt);
    });
  }

  void _scheduleRetry(String operationId, Duration delay) {
    Timer(delay, () {
      final index = _operations.indexWhere((op) => op.id == operationId);
      if (index != -1 &&
          _operations[index].status == SyncOperationStatus.retrying) {
        _operations[index] = _operations[index].copyWith(
          status: SyncOperationStatus.pending,
        );
        notifyListeners();
      }
    });
  }
}

/// Riverpod provider for the sync queue - Modern Riverpod 2.x syntax
@Riverpod(keepAlive: true)
class SyncQueue extends _$SyncQueue {
  @override
  SyncQueueManager build() => SyncQueueManager();
}

/// Provider for sync queue stats
@riverpod
SyncQueueStats syncQueueStats(final Ref ref) {
  final queue = ref.watch(syncQueueProvider);

  return SyncQueueStats(
    pendingCount: queue.pendingCount,
    failedCount: queue.failedCount,
    hasPendingOperations: queue.hasPendingOperations,
    totalOperations: queue.operations.length,
  );
}

/// Stats about the sync queue
class SyncQueueStats {
  final int pendingCount;
  final int failedCount;
  final bool hasPendingOperations;
  final int totalOperations;

  const SyncQueueStats({
    required this.pendingCount,
    required this.failedCount,
    required this.hasPendingOperations,
    required this.totalOperations,
  });

  /// Whether to show the sync indicator
  bool get showIndicator => hasPendingOperations || failedCount > 0;

  /// Summary text for the indicator
  String get statusText {
    if (failedCount > 0 && pendingCount > 0) {
      return '$pendingCount in attesa, $failedCount falliti';
    } else if (failedCount > 0) {
      return '$failedCount operazioni fallite';
    } else if (pendingCount > 0) {
      return '$pendingCount in attesa di sincronizzazione';
    }
    return '';
  }
}
