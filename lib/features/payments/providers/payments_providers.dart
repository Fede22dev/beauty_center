import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

import '../../../core/connectivity/connectivity_providers.dart';
import '../../../core/database/app_database.dart';
import '../../../core/database/providers/app_database_provider.dart';
import '../../../core/providers/background_provider.dart';
import '../../../core/providers/supabase_auth_provider.dart';
import '../data/repositories/payments_repository.dart';

part 'payments_providers.g.dart';

// ========================================================================
// CORE PROVIDERS
// ========================================================================

/// Payments repository with automatic client management
@riverpod
PaymentsRepository paymentsRepository(final Ref ref) {
  final db = ref.watch(appDatabaseProvider);
  final supabase = ref.watch(supabaseClientProvider);

  final supabaseAuthState = ref.watch(supabaseAuthProvider);
  final isOffline = ref.watch(isConnectionUnusableProvider);
  final isInForeground = ref.watch(appIsInForegroundProvider);

  final isOnline =
      !isOffline && supabaseAuthState.isConnected && isInForeground;

  final repo = PaymentsRepository(
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

/// Payments stream - automatically updates UI when data changes
final paymentsStreamProvider = StreamProvider<List<PaymentData>>(
  (final ref) => ref.watch(paymentsRepositoryProvider).watchAllPayments(),
);

/// Payments by client stream
final paymentsByClientStreamProvider = StreamProvider.family<List<PaymentData>, String>(
  (final ref, final clientId) =>
      ref.watch(paymentsRepositoryProvider).watchPaymentsByClientId(clientId),
);

/// Payments by package stream
final paymentsByPackageStreamProvider = StreamProvider.family<List<PaymentData>, String>(
  (final ref, final packageId) =>
      ref.watch(paymentsRepositoryProvider).watchPaymentsByPackageId(packageId),
);

/// Payments by appointment stream
final paymentsByAppointmentStreamProvider = StreamProvider.family<List<PaymentData>, String>(
  (final ref, final appointmentId) =>
      ref.watch(paymentsRepositoryProvider).watchPaymentsByAppointmentId(appointmentId),
);

/// Payments by product sale stream
final paymentsByProductSaleStreamProvider = StreamProvider.family<List<PaymentData>, String>(
  (final ref, final productSaleId) =>
      ref.watch(paymentsRepositoryProvider).watchPaymentsByProductSaleId(productSaleId),
);

/// Single payment stream by ID
final paymentStreamProvider = StreamProvider.family<PaymentData?, String>(
  (final ref, final paymentId) =>
      ref.watch(paymentsRepositoryProvider).watchPaymentById(paymentId),
);

// ========================================================================
// ACTIONS PROVIDER
// ========================================================================

/// Actions provider - All write operations go through here
@riverpod
PaymentsActions paymentsActions(final Ref ref) {
  final repo = ref.watch(paymentsRepositoryProvider);
  return PaymentsActions(repo);
}

class PaymentsActions {
  PaymentsActions(this._repo);

  final PaymentsRepository _repo;

  // CREATE
  Future<String?> createPayment({
    required final String clientId,
    required final double amount,
    required final String paymentMethod,
    final String? packageId,
    final String? appointmentId,
    final String? productSaleId,
    final String? notes,
  }) => _repo.createPayment(
    clientId: clientId,
    amount: amount,
    paymentMethod: paymentMethod,
    packageId: packageId,
    appointmentId: appointmentId,
    productSaleId: productSaleId,
    notes: notes,
  );

  // READ
  Future<PaymentData?> getPaymentById(final String id) => _repo.getPaymentById(id);

  Future<List<PaymentData>> getAllPayments() => _repo.getAllPayments();

  Future<List<PaymentData>> getPaymentsByClientId(final String clientId) =>
      _repo.getPaymentsByClientId(clientId);

  Future<List<PaymentData>> getPaymentsByPackageId(final String packageId) =>
      _repo.getPaymentsByPackageId(packageId);

  Future<List<PaymentData>> getPaymentsByAppointmentId(final String appointmentId) =>
      _repo.getPaymentsByAppointmentId(appointmentId);

  Future<List<PaymentData>> getPaymentsByProductSaleId(final String productSaleId) =>
      _repo.getPaymentsByProductSaleId(productSaleId);

  // DELETE
  Future<void> deletePayment(final String id) => _repo.deletePayment(id);

  // SYNC
  Future<void> syncWithSupabase() => _repo.syncWithSupabase();
}
