import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

import '../../../core/connectivity/connectivity_providers.dart';
import '../../../core/database/app_database.dart';
import '../../../core/database/providers/app_database_provider.dart';
import '../../../core/providers/background_provider.dart';
import '../../../core/providers/supabase_auth_provider.dart';
import '../data/repositories/fidelity_repository.dart';

part 'fidelity_providers.g.dart';

// ========================================================================
// CORE PROVIDERS
// ========================================================================

/// Fidelity repository with automatic client management
@riverpod
FidelityRepository fidelityRepository(final Ref ref) {
  final db = ref.watch(appDatabaseProvider);
  final supabase = ref.watch(supabaseClientProvider);

  final supabaseAuthState = ref.watch(supabaseAuthProvider);
  final isOffline = ref.watch(isConnectionUnusableProvider);
  final isInForeground = ref.watch(appIsInForegroundProvider);

  final isOnline =
      !isOffline && supabaseAuthState.isConnected && isInForeground;

  final repo = FidelityRepository(
    db: db,
    supabase: supabase,
    isOnline: isOnline,
  );

  // Automatic cleanup
  ref.onDispose(() async {
    await repo.stopRealtimeSync();
  });

  return repo;
}

// ========================================================================
// STREAM PROVIDERS (Reactive UI updates)
// ========================================================================

/// Fidelity cards stream - automatically updates UI when data changes
final fidelityCardsStreamProvider = StreamProvider<List<FidelityCardData>>(
  (final ref) => ref.watch(fidelityRepositoryProvider).watchAllFidelityCards(),
);

/// Fidelity cards by client stream
final fidelityCardsByClientStreamProvider = StreamProvider.family<List<FidelityCardData>, String>(
  (final ref, final clientId) =>
      ref.watch(fidelityRepositoryProvider).watchFidelityCardsByClientId(clientId),
);

/// Active fidelity cards by client stream
final activeFidelityCardsByClientStreamProvider = StreamProvider.family<List<FidelityCardData>, String>(
  (final ref, final clientId) =>
      ref.watch(fidelityRepositoryProvider).watchActiveFidelityCardsByClientId(clientId),
);

/// Single fidelity card stream by ID
final fidelityCardStreamProvider = StreamProvider.family<FidelityCardData?, String>(
  (final ref, final cardId) =>
      ref.watch(fidelityRepositoryProvider).watchFidelityCardById(cardId),
);

/// Fidelity transactions by card stream
final fidelityTransactionsStreamProvider = StreamProvider.family<List<FidelityTransactionData>, String>(
  (final ref, final cardId) =>
      ref.watch(fidelityRepositoryProvider).watchFidelityTransactionsByCardId(cardId),
);

// ========================================================================
// ACTIONS PROVIDER
// ========================================================================

/// Actions provider - All write operations go through here
@riverpod
FidelityActions fidelityActions(final Ref ref) {
  final repo = ref.watch(fidelityRepositoryProvider);
  return FidelityActions(repo);
}

class FidelityActions {
  FidelityActions(this._repo);

  final FidelityRepository _repo;

  // CREATE
  Future<String?> createFidelityCard({
    required final String clientId,
    required final String cardNumber,
    final double initialBalance = 0,
    final bool isGift = false,
    final String? giftNote,
  }) => _repo.createFidelityCard(
    clientId: clientId,
    cardNumber: cardNumber,
    initialBalance: initialBalance,
    isGift: isGift,
    giftNote: giftNote,
  );

  // READ
  Future<FidelityCardData?> getFidelityCardById(final String id) => _repo.getFidelityCardById(id);

  Future<FidelityCardData?> getFidelityCardByNumber(final String cardNumber) =>
      _repo.getFidelityCardByNumber(cardNumber);

  Future<List<FidelityCardData>> getAllFidelityCards() => _repo.getAllFidelityCards();

  Future<List<FidelityCardData>> getFidelityCardsByClientId(final String clientId) =>
      _repo.getFidelityCardsByClientId(clientId);

  Future<List<FidelityCardData>> getActiveFidelityCardsByClientId(final String clientId) =>
      _repo.getActiveFidelityCardsByClientId(clientId);

  Future<List<FidelityTransactionData>> getFidelityTransactionsByCardId(final String cardId) =>
      _repo.getFidelityTransactionsByCardId(cardId);

  // UPDATE
  Future<void> addTopup({
    required final String cardId,
    required final double amount,
    final String? description,
  }) => _repo.addTopup(cardId: cardId, amount: amount, description: description);

  Future<void> addUsage({
    required final String cardId,
    required final double amount,
    final String? appointmentId,
    final String? description,
  }) => _repo.addUsage(
    cardId: cardId,
    amount: amount,
    appointmentId: appointmentId,
    description: description,
  );

  Future<void> refundUsage({
    required final String cardId,
    required final double amount,
    final String? appointmentId,
    final String? description,
  }) => _repo.refundUsage(
    cardId: cardId,
    amount: amount,
    appointmentId: appointmentId,
    description: description,
  );

  Future<void> updateFidelityCardStatus({
    required final String id,
    required final String status,
  }) => _repo.updateFidelityCardStatus(id: id, status: status);

  Future<void> updateFidelityCardNotes({
    required final String id,
    final String? notes,
  }) => _repo.updateFidelityCardNotes(id: id, notes: notes);

  // DELETE
  Future<void> deleteFidelityCard(final String id) => _repo.deleteFidelityCard(id);

  // SYNC
  Future<void> syncWithSupabase() => _repo.syncWithSupabase();
}
