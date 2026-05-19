import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

import '../../../core/connectivity/connectivity_providers.dart';
import '../../../core/database/app_database.dart';
import '../../../core/database/providers/app_database_provider.dart';
import '../../../core/providers/background_provider.dart';
import '../../../core/providers/supabase_auth_provider.dart';
import '../data/repositories/quotes_repository.dart';

part 'quotes_providers.g.dart';

// ========================================================================
// CORE PROVIDERS
// ========================================================================

/// Quotes repository with automatic client management
@riverpod
QuotesRepository quotesRepository(final Ref ref) {
  final db = ref.watch(appDatabaseProvider);
  final supabase = ref.watch(supabaseClientProvider);

  final supabaseAuthState = ref.watch(supabaseAuthProvider);
  final isOffline = ref.watch(isConnectionUnusableProvider);
  final isInForeground = ref.watch(appIsInForegroundProvider);

  final isOnline =
      !isOffline && supabaseAuthState.isConnected && isInForeground;

  final repo = QuotesRepository(db: db, supabase: supabase, isOnline: isOnline);

  // Automatic cleanup
  ref.onDispose(() async {
    await repo.stopRealtimeSync();
  });

  return repo;
}

// ========================================================================
// STREAM PROVIDERS (Reactive UI updates)
// ========================================================================

/// Quotes stream - automatically updates UI when data changes
final quotesStreamProvider = StreamProvider<List<QuoteData>>(
  (final ref) => ref.watch(quotesRepositoryProvider).watchAllQuotes(),
);

/// Quotes by client stream
final quotesByClientStreamProvider =
    StreamProvider.family<List<QuoteData>, String>(
      (final ref, final clientId) =>
          ref.watch(quotesRepositoryProvider).watchQuotesByClientId(clientId),
    );

/// Single quote stream by ID
final quoteStreamProvider = StreamProvider.family<QuoteData?, String>(
  (final ref, final quoteId) =>
      ref.watch(quotesRepositoryProvider).watchQuoteById(quoteId),
);

/// Quote items by quote stream
final quoteItemsStreamProvider =
    StreamProvider.family<List<QuoteItemData>, String>(
      (final ref, final quoteId) =>
          ref.watch(quotesRepositoryProvider).watchQuoteItemsByQuoteId(quoteId),
    );

// ========================================================================
// ACTIONS PROVIDER
// ========================================================================

/// Actions provider - All write operations go through here
@riverpod
QuotesActions quotesActions(final Ref ref) {
  final repo = ref.watch(quotesRepositoryProvider);
  return QuotesActions(repo);
}

class QuotesActions {
  QuotesActions(this._repo);

  final QuotesRepository _repo;

  // CREATE
  Future<String?> createQuote({
    required final String clientId,
    required final String quoteNumber,
    required final double totalPrice,
    required final List<QuoteItemData> items,
    final double discountAmount = 0,
    final DateTime? validUntil,
    final String? notes,
  }) => _repo.createQuote(
    clientId: clientId,
    quoteNumber: quoteNumber,
    totalPrice: totalPrice,
    discountAmount: discountAmount,
    validUntil: validUntil,
    notes: notes,
    items: items,
  );

  // READ
  Future<QuoteData?> getQuoteById(final String id) => _repo.getQuoteById(id);

  Future<List<QuoteData>> getAllQuotes() => _repo.getAllQuotes();

  Future<List<QuoteData>> getQuotesByClientId(final String clientId) =>
      _repo.getQuotesByClientId(clientId);

  Future<List<QuoteItemData>> getQuoteItemsByQuoteId(final String quoteId) =>
      _repo.getQuoteItemsByQuoteId(quoteId);

  // UPDATE
  Future<void> updateQuoteStatus({
    required final String id,
    required final String status,
  }) => _repo.updateQuoteStatus(id: id, status: status);

  // DELETE
  Future<void> deleteQuote(final String id) => _repo.deleteQuote(id);

  // SYNC
  Future<void> syncWithSupabase() => _repo.syncWithSupabase();
}
