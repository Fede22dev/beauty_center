import 'package:drift/drift.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

import '../../../../core/connectivity/connectivity_providers.dart';
import '../../../../core/database/app_database.dart';
import '../../../../core/database/providers/app_database_provider.dart';
import '../../../../core/providers/background_provider.dart';
import '../../../../core/providers/supabase_auth_provider.dart';
import '../../../../core/utils/fuzzy_search.dart';
import '../data/repositories/clients_repository.dart';

part 'clients_providers.g.dart';

// ========================================================================
// CORE PROVIDERS
// ========================================================================

/// Clients repository with automatic client management
/// Uses keepAlive to prevent memory leaks from rapid recreation
@Riverpod(keepAlive: true)
ClientsRepository clientsRepository(final Ref ref) {
  final db = ref.watch(appDatabaseProvider);
  final supabase = ref.watch(supabaseClientProvider);

  final supabaseAuthState = ref.watch(supabaseAuthProvider);
  final isOffline = ref.watch(isConnectionUnusableProvider);
  final isInForeground = ref.watch(appIsInForegroundProvider);

  final isOnline =
      !isOffline && supabaseAuthState.isConnected && isInForeground;

  final repo = ClientsRepository(
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
// STREAM PROVIDERS (Reactive UI updates) - LEGACY SYNTAX PER ERRORI TIPI DRIFT
// ========================================================================

/// Clients stream - automatically updates UI when data changes
final clientsStreamProvider = StreamProvider<List<Client>>(
  (final ref) => ref.watch(clientsRepositoryProvider).watchAllClients(),
);

/// Single client stream by ID
final clientStreamProvider = StreamProvider.family<Client?, String>(
  (final ref, final clientId) =>
      ref.watch(clientsRepositoryProvider).watchClientById(clientId),
);

// ========================================================================
// ACTIONS PROVIDER
// ========================================================================

/// Actions provider - All write operations go through here
@riverpod
ClientsActions clientsActions(final Ref ref) {
  final repo = ref.watch(clientsRepositoryProvider);
  return ClientsActions(repo);
}

class ClientsActions {
  ClientsActions(this._repo);

  final ClientsRepository _repo;

  // CREATE
  Future<String?> createClient({
    required final String firstName,
    required final String lastName,
    required final String phoneNumber,
    final String? email,
    final DateTime? birthDate,
    final String? address,
    final String? notes,
  }) => _repo.createClient(
    firstName: firstName,
    lastName: lastName,
    phoneNumber: phoneNumber,
    email: email,
    birthDate: birthDate,
    address: address,
    notes: notes,
  );

  // READ
  Future<Client?> getClientById(final String id) => _repo.getClientById(id);

  Future<List<Client>> getAllClients() => _repo.getAllClients();

  Future<List<Client>> searchClients(final String query) =>
      _repo.searchClients(query);

  Future<int> getClientsCount() => _repo.getClientsCount();

  // UPDATE
  Future<void> updateClient({
    required final String id,
    required final String firstName,
    required final String lastName,
    required final String phoneNumber,
    final String? email,
    final DateTime? birthDate,
    final String? address,
    final String? notes,
  }) => _repo.updateClient(
    id: id,
    firstName: firstName,
    lastName: lastName,
    phoneNumber: phoneNumber,
    email: email,
    birthDate: birthDate,
    address: address,
    notes: notes,
  );

  // DELETE
  Future<void> deleteClient(final String id) => _repo.deleteClient(id);

  // SYNC
  Future<void> syncWithSupabase() => _repo.syncWithSupabase();

  // TECHNICAL SHEET
  Future<ClientTechnicalSheetData> getOrCreateTechnicalSheet(
    final String clientId,
  ) => _repo.getOrCreateTechnicalSheet(clientId);

  Future<bool> updateTechnicalSheet({
    required final String clientId,
    final String? skinType,
    final String? skinConditions,
    final String? allergies,
    final String? contraindications,
    final String? currentMedications,
    final String? previousTreatments,
    final String? machineSettings,
    final String? treatmentGoals,
    final String? medicalNotes,
    final bool? isPregnant,
    final bool? isBreastfeeding,
    final bool? hasSunSensitivity,
    final bool? hasHerpesHistory,
    final bool? hasKeloidTendency,
    final bool? hasDiabetes,
    final bool? hasPacemaker,
    final int? fitzpatrickType,
  }) => _repo.updateTechnicalSheet(
    clientId: clientId,
    skinType: skinType,
    skinConditions: skinConditions,
    allergies: allergies,
    contraindications: contraindications,
    currentMedications: currentMedications,
    previousTreatments: previousTreatments,
    machineSettings: machineSettings,
    treatmentGoals: treatmentGoals,
    medicalNotes: medicalNotes,
    isPregnant: isPregnant,
    isBreastfeeding: isBreastfeeding,
    hasSunSensitivity: hasSunSensitivity,
    hasHerpesHistory: hasHerpesHistory,
    hasKeloidTendency: hasKeloidTendency,
    hasDiabetes: hasDiabetes,
    hasPacemaker: hasPacemaker,
    fitzpatrickType: fitzpatrickType,
  );
}

// ========================================================================
// TECHNICAL SHEET PROVIDERS
// ========================================================================

/// Technical sheet stream for a client
final clientTechnicalSheetStreamProvider =
    StreamProvider.family<ClientTechnicalSheetData?, String>(
      (final ref, final clientId) =>
          ref.watch(clientsRepositoryProvider).watchTechnicalSheet(clientId),
    );

/// Technical sheet actions provider
@riverpod
ClientTechnicalSheetActions clientTechnicalSheetActions(final Ref ref) {
  final repo = ref.watch(clientsRepositoryProvider);
  return ClientTechnicalSheetActions(repo);
}

class ClientTechnicalSheetActions {
  ClientTechnicalSheetActions(this._repo);

  final ClientsRepository _repo;

  Future<ClientTechnicalSheetData> getOrCreateTechnicalSheet(
    final String clientId,
  ) => _repo.getOrCreateTechnicalSheet(clientId);

  Future<bool> updateTechnicalSheet({
    required final String clientId,
    final String? skinType,
    final String? skinConditions,
    final String? allergies,
    final String? contraindications,
    final String? currentMedications,
    final String? previousTreatments,
    final String? machineSettings,
    final String? treatmentGoals,
    final String? medicalNotes,
    final bool? isPregnant,
    final bool? isBreastfeeding,
    final bool? hasSunSensitivity,
    final bool? hasHerpesHistory,
    final bool? hasKeloidTendency,
    final bool? hasDiabetes,
    final bool? hasPacemaker,
    final int? fitzpatrickType,
  }) => _repo.updateTechnicalSheet(
    clientId: clientId,
    skinType: skinType,
    skinConditions: skinConditions,
    allergies: allergies,
    contraindications: contraindications,
    currentMedications: currentMedications,
    previousTreatments: previousTreatments,
    machineSettings: machineSettings,
    treatmentGoals: treatmentGoals,
    medicalNotes: medicalNotes,
    isPregnant: isPregnant,
    isBreastfeeding: isBreastfeeding,
    hasSunSensitivity: hasSunSensitivity,
    hasHerpesHistory: hasHerpesHistory,
    hasKeloidTendency: hasKeloidTendency,
    hasDiabetes: hasDiabetes,
    hasPacemaker: hasPacemaker,
    fitzpatrickType: fitzpatrickType,
  );
}

// ========================================================================
// TREATMENT TIMELINE PROVIDER
// ========================================================================

/// Data class for treatment timeline entries
class TreatmentTimelineEntry {
  final String appointmentId;
  final DateTime date;
  final List<String> serviceNames;
  final String? operatorNotes;
  final String? skinReaction;
  final String? operatorName;
  final String? cabinName;

  TreatmentTimelineEntry({
    required this.appointmentId,
    required this.date,
    required this.serviceNames,
    this.operatorNotes,
    this.skinReaction,
    this.operatorName,
    this.cabinName,
  });
}

/// Stream of treatment timeline for a client (completed appointments)
final clientTreatmentTimelineProvider =
    StreamProvider.family<List<TreatmentTimelineEntry>, String>((
      final ref,
      final clientId,
    ) {
      final db = ref.watch(appDatabaseProvider);

      return (db.select(db.appointmentsTable)
            ..where((a) => a.clientId.equals(clientId))
            ..where((a) => a.isActive.equals(true))
            ..orderBy([(a) => OrderingTerm.desc(a.startDateTime)]))
          .watch()
          .asyncMap((appointments) async {
            final entries = <TreatmentTimelineEntry>[];

            for (final appt in appointments.where(
              (a) => a.startDateTime.isBefore(DateTime.now()),
            )) {
              // Get services for this appointment
              final servicesQuery = db.select(db.appointmentServicesTable)
                ..where((s) => s.appointmentId.equals(appt.id));
              final services = await servicesQuery.get();

              // Get service names by looking up serviceId in services table
              final serviceNames = <String>[];
              for (final svc in services) {
                final serviceData = await (db.select(
                  db.servicesTable,
                )..where((s) => s.id.equals(svc.serviceId))).getSingleOrNull();
                if (serviceData != null) {
                  serviceNames.add(serviceData.name);
                }
              }

              // Get operator name if available
              String? operatorName;
              if (appt.operatorId != null) {
                final operator =
                    await (db.select(db.operatorsTable)
                          ..where((o) => o.id.equals(appt.operatorId!)))
                        .getSingleOrNull();
                operatorName = operator?.name;
              }

              // Get cabin name if available
              String? cabinName;
              if (appt.cabinId != null) {
                final cabin = await (db.select(
                  db.cabinsTable,
                )..where((c) => c.id.equals(appt.cabinId!))).getSingleOrNull();
                cabinName = 'Cabina ${cabin!.id}';
              }

              entries.add(
                TreatmentTimelineEntry(
                  appointmentId: appt.id,
                  date: appt.startDateTime,
                  serviceNames: serviceNames,
                  operatorNotes: appt.operatorNotes,
                  skinReaction: appt.skinReaction,
                  operatorName: operatorName,
                  cabinName: cabinName,
                ),
              );
            }

            return entries;
          });
    });

// ========================================================================
// FUZZY SEARCH PROVIDERS - Modern Riverpod 2.x Syntax
// ========================================================================

/// Fuzzy search query notifier - Modern syntax using Notifier
@riverpod
class FuzzySearchQuery extends _$FuzzySearchQuery {
  @override
  String build() => '';

  void setQuery(String query) => state = query;

  void clear() => state = '';
}

/// Fuzzy search threshold (0.0 - 1.0, higher = stricter)
@riverpod
class FuzzySearchThreshold extends _$FuzzySearchThreshold {
  @override
  double build() => 0.6;

  void setThreshold(double threshold) => state = threshold.clamp(0.1, 1.0);
}

/// Clients filtered with fuzzy search
/// Matches names even with typos (e.g., "Mria" matches "Maria")
/// Using FutureProvider for AsyncValue compatibility
final fuzzyFilteredClientsProvider = FutureProvider<List<Client>>((ref) async {
  final clientsAsync = await ref.watch(clientsStreamProvider.future);
  final query = ref.watch(fuzzySearchQueryProvider);
  final threshold = ref.watch(fuzzySearchThresholdProvider);

  if (query.isEmpty) return clientsAsync;

  final filtered = FuzzySearch.filterAndSort<Client>(
    query,
    clientsAsync,
    (client) => '${client.firstName} ${client.lastName} ${client.phoneNumber}',
    threshold: threshold,
  );

  return filtered;
});

/// Quick fuzzy search for client names only (auto-dispose for performance)
final fuzzyClientNameSearchProvider = Provider.family<List<Client>, String>((
  ref,
  query,
) {
  final clientsAsync = ref.watch(clientsStreamProvider);

  return clientsAsync.when(
    data: (clients) {
      if (query.isEmpty) return [];

      return FuzzySearch.filter<Client>(
        query,
        clients.take(50).toList(), // Limit for performance
        (client) => '${client.firstName} ${client.lastName}',
        threshold: 0.5,
      );
    },
    loading: () => [],
    error: (_, __) => [],
  );
});
