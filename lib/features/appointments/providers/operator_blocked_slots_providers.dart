import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

import '../../../core/connectivity/connectivity_providers.dart';
import '../../../core/database/app_database.dart';
import '../../../core/database/providers/app_database_provider.dart';
import '../../../core/providers/background_provider.dart';
import '../../../core/providers/supabase_auth_provider.dart';
import '../data/repositories/operator_blocked_slots_repository.dart';
import '../models/blocked_slot_recurrence.dart';

part 'operator_blocked_slots_providers.g.dart';

// ========================================================================
// CORE PROVIDERS
// ========================================================================

/// Operator blocked slots repository with automatic client management
@riverpod
OperatorBlockedSlotRepository operatorBlockedSlotsRepository(final Ref ref) {
  final db = ref.watch(appDatabaseProvider);
  final supabase = ref.watch(supabaseClientProvider);

  final supabaseAuthState = ref.watch(supabaseAuthProvider);
  final isOffline = ref.watch(isConnectionUnusableProvider);
  final isInForeground = ref.watch(appIsInForegroundProvider);

  final isOnline =
      !isOffline && supabaseAuthState.isConnected && isInForeground;

  final repo = OperatorBlockedSlotRepository(
    db: db,
    supabase: supabase,
    isOnline: isOnline,
  );

  // Gestione pulizia automatica
  ref.onDispose(() async {
    await repo.stopRealtimeSync();
  });

  return repo;
}

// ============================================================================
// STREAM PROVIDERS (Reactive UI updates) - LEGACY SYNTAX PER ERRORI TIPI DRIFT
// ============================================================================

/// All operator blocked slots stream - automatically updates UI when data changes

final operatorBlockedSlotsStreamProvider =
    StreamProvider<List<OperatorBlockedSlot>>(
      (final ref) => ref
          .watch(operatorBlockedSlotsRepositoryProvider)
          .watchAllBlockedSlots(),
    );

/// Single operator blocked slot stream by ID
final operatorBlockedSlotStreamProvider =
    StreamProvider.family<OperatorBlockedSlot?, String>(
      (final ref, final blockedSlotId) => ref
          .watch(operatorBlockedSlotsRepositoryProvider)
          .watchBlockedSlotById(blockedSlotId),
    );

// =============================================================================
// CLIPBOARD PROVIDER
// =============================================================================

final clipboardBlockedSlotProvider =
    NotifierProvider<ClipboardOperatorBlockedSlot, OperatorBlockedSlot?>(
      ClipboardOperatorBlockedSlot.new,
    );

class ClipboardOperatorBlockedSlot extends Notifier<OperatorBlockedSlot?> {
  @override
  OperatorBlockedSlot? build() => null;

  void copy(OperatorBlockedSlot slot) => state = slot;

  void clear() => state = null;
}

// =============================================================================
// ACTIONS PROVIDER
// =============================================================================

@riverpod
BlockedSlotActions blockedSlotActions(Ref ref) => BlockedSlotActions(ref);

class BlockedSlotActions {
  BlockedSlotActions(this._ref);

  final Ref _ref;

  OperatorBlockedSlotRepository get _repo =>
      _ref.read(operatorBlockedSlotsRepositoryProvider);

  // ---------------------------------------------------------------------------
  // CREATE
  // ---------------------------------------------------------------------------

  Future<void> createBlockedSlot({
    required int operatorId,
    required DateTime startDateTime,
    required DateTime endDateTime,
    String? reason,
  }) => _repo.createBlockedSlot(
    operatorId: operatorId,
    startDateTime: startDateTime,
    endDateTime: endDateTime,
    reason: reason,
  );

  Future<void> createRecurrenceBlockedSlots({
    required int operatorId,
    required DateTime startDateTime,
    required DateTime endDateTime,
    required BlockedSlotRecurrence recurrence,
    required DateTime until,
    String? reason,
  }) => _repo.createRecurrenceBlockedSlots(
    operatorId: operatorId,
    startDateTime: startDateTime,
    endDateTime: endDateTime,
    recurrence: recurrence,
    until: until,
    reason: reason,
  );

  // ---------------------------------------------------------------------------
  // UPDATE
  // ---------------------------------------------------------------------------

  Future<void> updateBlockedSlot({
    required String id,
    required int operatorId,
    required DateTime startDateTime,
    required DateTime endDateTime,
    String? reason,
  }) => _repo.updateBlockedSlot(
    id: id,
    operatorId: operatorId,
    startDateTime: startDateTime,
    endDateTime: endDateTime,
    reason: reason,
  );

  Future<void> updateRecurrenceBlockedSlots({
    required String seriesId,
    required int operatorId,
    required DateTime startDateTime,
    required DateTime endDateTime,
    String? reason,
  }) => _repo.updateRecurrenceBlockedSlots(
    seriesId: seriesId,
    operatorId: operatorId,
    startDateTime: startDateTime,
    endDateTime: endDateTime,
    reason: reason,
  );

  // ---------------------------------------------------------------------------
  // DELETE
  // ---------------------------------------------------------------------------

  Future<void> deleteBlockedSlot(final String id) =>
      _repo.deleteBlockedSlot(id);

  Future<void> deleteRecurrenceBlockedSlots(final String seriesId) =>
      _repo.deleteRecurrenceBlockedSlots(seriesId);
}
