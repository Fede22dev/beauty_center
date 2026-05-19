import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

import '../../../core/connectivity/connectivity_providers.dart';
import '../../../core/database/app_database.dart';
import '../../../core/database/providers/app_database_provider.dart';
import '../../../core/providers/background_provider.dart';
import '../../../core/providers/supabase_auth_provider.dart';
import '../data/repositories/appointments_repository.dart';

part 'appointments_providers.g.dart';

// ========================================================================
// CORE PROVIDERS
// ========================================================================

/// Appointments repository with automatic client management
/// Uses keepAlive to prevent memory leaks from rapid recreation
@Riverpod(keepAlive: true)
AppointmentsRepository appointmentsRepository(final Ref ref) {
  final db = ref.watch(appDatabaseProvider);
  final supabase = ref.watch(supabaseClientProvider);

  final supabaseAuthState = ref.watch(supabaseAuthProvider);
  final isOffline = ref.watch(isConnectionUnusableProvider);
  final isInForeground = ref.watch(appIsInForegroundProvider);

  final isOnline =
      !isOffline && supabaseAuthState.isConnected && isInForeground;

  final repo = AppointmentsRepository(
    db: db,
    supabase: supabase,
    isOnline: isOnline,
  );

  // Gestione pulizia quando il provider viene distrutto
  ref.onDispose(() async {
    await repo.stopRealtimeSync();
  });

  return repo;
}

// ============================================================================
// STREAM PROVIDERS (Reactive UI updates)
// ============================================================================

/// Stores the date currently viewed in the calendar
@riverpod
class CalendarDate extends _$CalendarDate {
  @override
  DateTime build() => DateTime.now();

  void update(DateTime newDate) => state = newDate;
}

/// Range-filtered appointments stream (±7 days from selected date)
final appointmentsStreamProvider = StreamProvider<List<AppointmentData>>((
  final ref,
) {
  final date = ref.watch(calendarDateProvider);
  final start = date.subtract(const Duration(days: 7));
  final end = date.add(const Duration(days: 7));

  return ref
      .watch(appointmentsRepositoryProvider)
      .watchAppointmentsForRange(start, end);
});

/// Single appointment stream by ID
final appointmentStreamProvider =
    StreamProvider.family<AppointmentData?, String>(
      (final ref, final appointmentId) => ref
          .watch(appointmentsRepositoryProvider)
          .watchAppointmentById(appointmentId),
    );

/// Appointments by client stream
final clientAppointmentsStreamProvider =
    StreamProvider.family<List<AppointmentData>, String>(
      (final ref, final clientId) => ref
          .watch(appointmentsRepositoryProvider)
          .watchAppointmentsByClientId(clientId),
    );

/// Appointment services stream by appointment ID
final appointmentServicesStreamProvider =
    StreamProvider.family<List<AppointmentServiceData>, String>(
      (final ref, final appointmentId) => ref
          .watch(appointmentsRepositoryProvider)
          .watchAppointmentServicesByAppointmentId(appointmentId),
    );

// =============================================================================
// CLIPBOARD PROVIDER (copy/paste)
// =============================================================================

final clipboardAppointmentProvider =
    NotifierProvider<ClipboardAppointment, ClipboardItem?>(
      ClipboardAppointment.new,
    );

enum ClipboardOperation { copy, cut }

class ClipboardItem {
  ClipboardItem({required this.appointment, required this.operation});

  final AppointmentData appointment;
  final ClipboardOperation operation;
}

class ClipboardAppointment extends Notifier<ClipboardItem?> {
  @override
  ClipboardItem? build() => null;

  void copy(AppointmentData appointment) => state = ClipboardItem(
    appointment: appointment,
    operation: ClipboardOperation.copy,
  );

  void cut(AppointmentData appointment) => state = ClipboardItem(
    appointment: appointment,
    operation: ClipboardOperation.cut,
  );

  void clear() => state = null;
}

// =============================================================================
// ACTIONS PROVIDER — the ONLY entry point for UI writes
// =============================================================================

@riverpod
AppointmentActions appointmentActions(Ref ref) => AppointmentActions(ref);

class AppointmentActions {
  AppointmentActions(this._ref);

  final Ref _ref;

  AppointmentsRepository get _repo => _ref.read(appointmentsRepositoryProvider);

  // ---------------------------------------------------------------------------
  // CREATE
  // ---------------------------------------------------------------------------

  Future<String?> createAppointment({
    required int operatorId,
    required String clientId,
    required int cabinId,
    required String service,
    required DateTime startDateTime,
    required DateTime endDateTime,
    String? notes,
  }) => _repo.createAppointment(
    operatorId: operatorId,
    clientId: clientId,
    cabinId: cabinId,
    service: service,
    startDateTime: startDateTime,
    endDateTime: endDateTime,
    notes: notes,
  );

  // ---------------------------------------------------------------------------
  // UPDATE
  // ---------------------------------------------------------------------------

  Future<void> updateAppointment({
    required String id,
    required int operatorId,
    required String clientId,
    required int cabinId,
    required String service,
    required DateTime startDateTime,
    required DateTime endDateTime,
    String? notes,
  }) => _repo.updateAppointment(
    id: id,
    operatorId: operatorId,
    clientId: clientId,
    cabinId: cabinId,
    service: service,
    startDateTime: startDateTime,
    endDateTime: endDateTime,
    notes: notes,
  );

  Future<bool> updateAppointmentWithServices({
    required String id,
    required int operatorId,
    required String clientId,
    required int cabinId,
    required DateTime startDateTime,
    required DateTime endDateTime,
    String? notes,
    required List<({
      String serviceId,
      double lockedPrice,
      int lockedDuration,
      String paymentSource,
      String? packageItemId,
      String? fidelityCardId,
    })> services,
  }) => _repo.updateAppointmentWithServices(
    id: id,
    operatorId: operatorId,
    clientId: clientId,
    cabinId: cabinId,
    startDateTime: startDateTime,
    endDateTime: endDateTime,
    notes: notes,
    services: services,
  );

  // ---------------------------------------------------------------------------
  // COPY + PASTE
  // ---------------------------------------------------------------------------

  void copyToClipboard(AppointmentData appointment) {
    debugPrint('DEBUG copyToClipboard: ${appointment.id}');
    _ref.read(clipboardAppointmentProvider.notifier).copy(appointment);
  }

  void cutToClipboard(AppointmentData appointment) {
    debugPrint('DEBUG cutToClipboard: ${appointment.id}');
    _ref.read(clipboardAppointmentProvider.notifier).cut(appointment);
  }

  void clearClipboard() =>
      _ref.read(clipboardAppointmentProvider.notifier).clear();

  ClipboardItem? get clipboard => _ref.read(clipboardAppointmentProvider);

  /// Pastes the clipboard appointment to [targetDateTime], optionally changing
  /// [newOperatorId]. Handles both copy and cut scenarios.
  Future<void> pasteAppointment({
    required DateTime targetDateTime,
    int? newOperatorId,
  }) async {
    final item = clipboard;
    if (item == null) return;

    final source = item.appointment;
    final duration = source.endDateTime.difference(source.startDateTime);
    final newEndDateTime = targetDateTime.add(duration);

    if (item.operation == ClipboardOperation.cut) {
      final success = await _repo.moveAppointment(
        id: source.id,
        newStartDateTime: targetDateTime,
        newEndDateTime: newEndDateTime,
        newOperatorId: newOperatorId ?? source.operatorId,
      );
      if (!success) {
        throw StateError('Cannot move appointment: offline mode (read-only)');
      }
      clearClipboard();
    } else {
      await _repo.duplicateAppointment(
        sourceId: source.id,
        newStartDateTime: targetDateTime,
        newEndDateTime: newEndDateTime,
        newOperatorId: newOperatorId,
      );
    }
  }

  // ---------------------------------------------------------------------------
  // DELETE
  // ---------------------------------------------------------------------------

  Future<void> deleteAppointment(String id) => _repo.deleteAppointment(id);

  // ---------------------------------------------------------------------------
  // READ
  // ---------------------------------------------------------------------------

  Future<AppointmentData?> getById(String id) => _repo.getAppointmentById(id);

  // ---------------------------------------------------------------------------
  // APPOINTMENT SERVICES
  // ---------------------------------------------------------------------------

  Future<List<AppointmentServiceData>> getAppointmentServicesByAppointmentId(
    String appointmentId,
  ) => _repo.getAppointmentServicesByAppointmentId(appointmentId);

  Future<String> createAppointmentService({
    required String appointmentId,
    required String serviceId,
    required double lockedPrice,
    required int lockedDuration,
    String? packageItemId,
    String? fidelityCardId,
    required String paymentSource,
  }) => _repo.createAppointmentService(
    appointmentId: appointmentId,
    serviceId: serviceId,
    lockedPrice: lockedPrice,
    lockedDuration: lockedDuration,
    packageItemId: packageItemId,
    fidelityCardId: fidelityCardId,
    paymentSource: paymentSource,
  );

  Future<void> deleteAppointmentServicesByAppointmentId(
    String appointmentId,
  ) => _repo.deleteAppointmentServicesByAppointmentId(appointmentId);
}
