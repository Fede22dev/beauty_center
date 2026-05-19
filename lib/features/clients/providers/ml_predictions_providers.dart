import 'dart:math';
import 'dart:ui' show Color;

import 'package:drift/drift.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

import '../../../core/database/app_database.dart';
import '../../../core/database/providers/app_database_provider.dart';
import 'clients_providers.dart';

part 'ml_predictions_providers.g.dart';

// ============================================================================
// MACHINE LEARNING PREDICTIONS FOR BEAUTY CENTER
// ============================================================================

/// ML Risk Score for a client (0.0 - 1.0)
/// Combines multiple risk factors: no-show probability, churn risk, upsell potential
final clientMLProfileProvider = FutureProvider.family<ClientMLProfile, String>(
  (ref, clientId) async {
    final db = ref.read(appDatabaseProvider);
    final clientAsync = await ref.read(clientStreamProvider(clientId).future);

    if (clientAsync == null) {
      throw Exception('Client not found');
    }

    // Fetch all client appointments with status
    final allAppointments = await (db.select(db.appointmentsTable)
          ..where((a) => a.clientId.equals(clientId))
          ..orderBy([(a) => OrderingTerm.desc(a.startDateTime)]))
        .get();

    final completedAppointments = allAppointments
        .where((a) => a.startDateTime.isBefore(DateTime.now()))
        .toList();

    // Calculate No-Show Probability
    final noShowScore = _calculateNoShowProbability(
      appointments: completedAppointments,
      totalAppointments: allAppointments.length,
    );

    // Calculate Churn Risk
    final churnScore = _calculateChurnRisk(
      client: clientAsync,
      appointments: completedAppointments,
    );

    // Calculate Upsell Potential
    final upsellScore = _calculateUpsellPotential(
      client: clientAsync,
      appointments: completedAppointments,
      db: db,
    );

    // Calculate Next Visit Prediction
    final nextVisitPrediction = _predictNextVisit(
      appointments: completedAppointments,
    );

    // Calculate Optimal Slot Recommendation
    final optimalSlots = _calculateOptimalSlots(
      appointments: completedAppointments,
    );

    // Generate Service Recommendations
    final serviceRecommendations = await _generateServiceRecommendations(
      clientId: clientId,
      appointments: completedAppointments,
      db: db,
    );

    return ClientMLProfile(
      clientId: clientId,
      noShowProbability: noShowScore,
      churnRisk: churnScore,
      upsellPotential: upsellScore,
      predictedNextVisit: nextVisitPrediction,
      optimalTimeSlots: optimalSlots,
      serviceRecommendations: serviceRecommendations,
      lastUpdated: DateTime.now(),
    );
  },
);

/// Dashboard-level ML insights for the entire center
final centerMLInsightsProvider = FutureProvider<CenterMLInsights>(
  (ref) async {
    final db = ref.read(appDatabaseProvider);

    // Get all clients and their appointments
    final allClients = await db.select(db.clientsTable).get();
    final allAppointments = await (db.select(db.appointmentsTable)
          ..where((a) => a.isActive.equals(true)))
        .get();

    // Calculate center-wide metrics
    final totalNoShowRisk = <ClientNoShowRisk>[];
    final highValueClients = <ClientValueProfile>[];
    final slotOptimization = <SlotOptimization>[];

    for (final client in allClients.take(100)) { // Limit to top 100 for performance
      final clientAppointments = allAppointments
          .where((a) => a.clientId == client.id)
          .toList();

      final completed = clientAppointments
          .where((a) => a.startDateTime.isBefore(DateTime.now()))
          .toList();

      if (completed.isNotEmpty) {
        final noShowRisk = _calculateNoShowProbability(
          appointments: completed,
          totalAppointments: clientAppointments.length,
        );

        if (noShowRisk > 0.3) {
          totalNoShowRisk.add(ClientNoShowRisk(
            clientId: client.id,
            clientName: '${client.firstName} ${client.lastName}',
            riskScore: noShowRisk,
            upcomingAppointment: clientAppointments
                .where((a) => a.startDateTime.isAfter(DateTime.now()))
                .firstOrNull,
          ));
        }
      }
    }

    // Sort by risk
    totalNoShowRisk.sort((a, b) => b.riskScore.compareTo(a.riskScore));

    return CenterMLInsights(
      highRiskNoShows: totalNoShowRisk.take(10).toList(),
      highValueClients: highValueClients.take(10).toList(),
      slotOptimization: slotOptimization,
      generatedAt: DateTime.now(),
    );
  },
);

/// ML-powered appointment risk prediction
/// Suggests when an appointment might be problematic
@riverpod
Future<List<AppointmentRisk>> appointmentRisks(Ref ref) async {
  final db = ref.read(appDatabaseProvider);
  final upcomingAppointments = await (db.select(db.appointmentsTable)
        ..where((a) => a.startDateTime.isBiggerThanValue(DateTime.now()))
        ..where((a) => a.isActive.equals(true))
        ..orderBy([(a) => OrderingTerm.asc(a.startDateTime)]))
      .get();

  final risks = <AppointmentRisk>[];

  for (final appointment in upcomingAppointments.take(50)) {
    final clientProfile = await ref.read(
      clientMLProfileProvider(appointment.clientId!).future,
    );

    double riskScore = 0.0;
    final riskFactors = <String>[];

    // High no-show risk
    if (clientProfile.noShowProbability > 0.5) {
      riskScore += 0.4;
      riskFactors.add(
        'Alto rischio no-show (${(clientProfile.noShowProbability * 100).toStringAsFixed(0)}%)',
      );
    }

    // Churn risk + no recent visits
    if (clientProfile.churnRisk > 0.6) {
      riskScore += 0.3;
      riskFactors.add('Rischio churn elevato');
    }

    // Monday/Friday patterns (common no-show days)
    final weekday = appointment.startDateTime.weekday;
    if (weekday == 1 || weekday == 5) {
      riskScore += 0.1;
      riskFactors.add('Giorno a rischio (lun/ven)');
    }

    // Early morning appointments
    final hour = appointment.startDateTime.hour;
    if (hour < 9) {
      riskScore += 0.1;
      riskFactors.add('Appuntamento mattino presto');
    }

    if (riskScore > 0.3) {
      final client = await (db.select(db.clientsTable)
            ..where((c) => c.id.equals(appointment.clientId!)))
          .getSingleOrNull();

      risks.add(AppointmentRisk(
        appointmentId: appointment.id,
        clientName: client != null
            ? '${client.firstName} ${client.lastName}'
            : 'Sconosciuto',
        appointmentTime: appointment.startDateTime,
        riskScore: riskScore.clamp(0.0, 1.0),
        riskFactors: riskFactors,
        suggestedAction: _suggestAction(riskScore, riskFactors),
      ));
    }
  }

  risks.sort((a, b) => b.riskScore.compareTo(a.riskScore));
  return risks;
}

// ============================================================================
// ML CALCULATION METHODS
// ============================================================================

/// Calculate no-show probability based on appointment history
double _calculateNoShowProbability({
  required List<AppointmentData> appointments,
  required int totalAppointments,
}) {
  if (appointments.isEmpty) return 0.0;

  // Factors that contribute to no-shows:
  // 1. Irregular booking patterns
  // 2. Long gaps between appointments
  // 3. Few appointments = unknown pattern

  double score = 0.0;

  // Check for irregular patterns
  if (appointments.length >= 3) {
    final intervals = <int>[];
    for (var i = 0; i < appointments.length - 1; i++) {
      final days = appointments[i + 1]
          .startDateTime
          .difference(appointments[i].startDateTime)
          .inDays
          .abs();
      intervals.add(days);
    }

    if (intervals.isNotEmpty) {
      final avg = intervals.reduce((a, b) => a + b) / intervals.length;
      final variance = intervals
          .map((i) => pow(i - avg, 2))
          .reduce((a, b) => a + b) / intervals.length;

      // High variance = irregular pattern = higher no-show risk
      if (variance > 900) score += 0.25; // variance > 30 days^2
    }
  }

  // Long gap since last appointment (if they had regular appointments before)
  if (appointments.isNotEmpty) {
    final lastAppointment = appointments.first.startDateTime;
    final daysSince = DateTime.now().difference(lastAppointment).inDays;

    // If last appointment was > 90 days ago and they book again
    if (daysSince > 90 && appointments.length > 1) {
      score += 0.2;
    }
  }

  // Few appointments = unknown pattern = moderate risk
  if (appointments.length <= 2) {
    score += 0.15;
  }

  return score.clamp(0.0, 1.0);
}

/// Calculate churn risk based on client engagement
double _calculateChurnRisk({
  required Client client,
  required List<AppointmentData> appointments,
}) {
  if (appointments.isEmpty) return 0.8; // No appointments = high churn risk

  double score = 0.0;

  // Days since last appointment
  final lastAppointment = appointments.first.startDateTime;
  final daysSinceLast = DateTime.now().difference(lastAppointment).inDays;

  // Churn risk increases with time since last visit
  if (daysSinceLast > 180) score += 0.5; // 6+ months
  else if (daysSinceLast > 90) score += 0.3; // 3+ months
  else if (daysSinceLast > 60) score += 0.15; // 2+ months

  // Frequency decline detection
  if (appointments.length >= 4) {
    final recentAvg = _calculateAverageInterval(
      appointments.take(3).toList(),
    );
    final olderAvg = _calculateAverageInterval(
      appointments.skip(appointments.length - 3).toList(),
    );

    if (recentAvg > olderAvg * 1.5) {
      score += 0.25; // Increasing gaps between visits
    }
  }

  // Low visit frequency overall
  if (appointments.length == 1) {
    score += 0.2;
  }

  return score.clamp(0.0, 1.0);
}

/// Calculate upsell potential based on client behavior
double _calculateUpsellPotential({
  required Client client,
  required List<AppointmentData> appointments,
  required AppDatabase db,
}) {
  if (appointments.isEmpty) return 0.0;

  double score = 0.0;

  // Regular customers are better upsell targets
  if (appointments.length >= 5) {
    score += 0.2;
  }

  // Recent activity indicates engagement
  final lastAppointment = appointments.first.startDateTime;
  final daysSinceLast = DateTime.now().difference(lastAppointment).inDays;

  if (daysSinceLast < 30) {
    score += 0.2; // Active customer
  }

  return score.clamp(0.0, 1.0);
}

/// Predict when client will likely book next
DateTimePrediction? _predictNextVisit({
  required List<AppointmentData> appointments,
}) {
  if (appointments.length < 2) return null;

  final intervals = <int>[];
  for (var i = 0; i < appointments.length - 1; i++) {
    final days = appointments[i]
        .startDateTime
        .difference(appointments[i + 1].startDateTime)
        .inDays
        .abs();
    intervals.add(days);
  }

  if (intervals.isEmpty) return null;

  final avgInterval = intervals.reduce((a, b) => a + b) / intervals.length;
  final lastVisit = appointments.first.startDateTime;
  final predictedNext = lastVisit.add(Duration(days: avgInterval.round()));

  return DateTimePrediction(
    predictedDate: predictedNext,
    confidence: (intervals.length / 10).clamp(0.1, 0.9),
    averageIntervalDays: avgInterval,
  );
}

/// Calculate optimal time slots for a client
List<OptimalSlot> _calculateOptimalSlots({
  required List<AppointmentData> appointments,
}) {
  if (appointments.isEmpty) return [];

  final hourDistribution = <int, int>{};
  final weekdayDistribution = <int, int>{};

  for (final appt in appointments) {
    final hour = appt.startDateTime.hour;
    final weekday = appt.startDateTime.weekday;

    hourDistribution[hour] = (hourDistribution[hour] ?? 0) + 1;
    weekdayDistribution[weekday] = (weekdayDistribution[weekday] ?? 0) + 1;
  }

  // Find preferred hours
  final preferredHours = hourDistribution.entries
      .where((e) => e.value >= 2)
      .map((e) => e.key)
      .toList();

  // Find preferred weekdays
  final preferredWeekdays = weekdayDistribution.entries
      .where((e) => e.value >= 2)
      .map((e) => e.key)
      .toList();

  final slots = <OptimalSlot>[];

  for (final hour in preferredHours) {
    for (final weekday in preferredWeekdays) {
      slots.add(OptimalSlot(
        preferredHour: hour,
        preferredWeekday: weekday,
        confidence: 0.7,
        reason: 'Basato su ${appointments.length} appuntamenti precedenti',
      ));
    }
  }

  return slots.take(3).toList();
}

/// Generate personalized service recommendations
Future<List<ServiceRecommendation>> _generateServiceRecommendations({
  required String clientId,
  required List<AppointmentData> appointments,
  required AppDatabase db,
}) async {
  final recommendations = <ServiceRecommendation>[];

  if (appointments.isEmpty) {
    // New client - suggest popular services
    recommendations.add(ServiceRecommendation(
      serviceName: 'Consulenza Iniziale',
      confidence: 0.9,
      reason: 'Prima visita - consulenza necessaria',
    ));
    return recommendations;
  }

  // Get services from recent appointments
  final recentServiceIds = <String>[];
  for (final appt in appointments.take(5)) {
    final services = await (db.select(db.appointmentServicesTable)
          ..where((s) => s.appointmentId.equals(appt.id)))
        .get();
    recentServiceIds.addAll(services.map((s) => s.serviceId));
  }

  // If client has recurring appointments, suggest complementary services
  if (appointments.length >= 3) {
    recommendations.add(ServiceRecommendation(
      serviceName: 'Trattamento di Mantenimento',
      confidence: 0.75,
      reason: 'Cliente abituale - valuta pacchetto mantenimento',
    ));
  }

  // If last appointment was > 60 days ago, suggest re-engagement
  final daysSinceLast = DateTime.now().difference(
    appointments.first.startDateTime,
  ).inDays;
  if (daysSinceLast > 60) {
    recommendations.add(ServiceRecommendation(
      serviceName: 'Trattamento di Rientro',
      confidence: 0.8,
      reason: 'Mancanza prolungata - offerta rientro',
    ));
  }

  return recommendations;
}

/// Calculate average interval between appointments
int _calculateAverageInterval(List<AppointmentData> appointments) {
  if (appointments.length < 2) return 0;

  var totalDays = 0;
  for (var i = 0; i < appointments.length - 1; i++) {
    totalDays += appointments[i]
        .startDateTime
        .difference(appointments[i + 1].startDateTime)
        .inDays
        .abs();
  }

  return totalDays ~/ (appointments.length - 1);
}

/// Suggest action based on risk score
String _suggestAction(double riskScore, List<String> riskFactors) {
  if (riskScore > 0.7) {
    return 'Invia SMS di conferma 24h prima, considera overbooking';
  } else if (riskScore > 0.5) {
    return 'Invia reminder WhatsApp 48h prima';
  } else if (riskFactors.any((f) => f.contains('churn'))) {
    return 'Offerta speciale riattivazione cliente';
  } else {
    return 'Monitora e invia reminder standard';
  }
}

// ============================================================================
// DATA CLASSES
// ============================================================================

/// Complete ML profile for a client
class ClientMLProfile {
  final String clientId;
  final double noShowProbability;
  final double churnRisk;
  final double upsellPotential;
  final DateTimePrediction? predictedNextVisit;
  final List<OptimalSlot> optimalTimeSlots;
  final List<ServiceRecommendation> serviceRecommendations;
  final DateTime lastUpdated;

  ClientMLProfile({
    required this.clientId,
    required this.noShowProbability,
    required this.churnRisk,
    required this.upsellPotential,
    this.predictedNextVisit,
    required this.optimalTimeSlots,
    required this.serviceRecommendations,
    required this.lastUpdated,
  });

  String get riskLevel {
    final maxRisk = [noShowProbability, churnRisk].reduce((a, b) => a > b ? a : b);
    if (maxRisk > 0.7) return 'Alto';
    if (maxRisk > 0.4) return 'Medio';
    return 'Basso';
  }

  Color get riskColor {
    final maxRisk = [noShowProbability, churnRisk].reduce((a, b) => a > b ? a : b);
    if (maxRisk > 0.7) return const Color(0xFFE53935); // Red
    if (maxRisk > 0.4) return const Color(0xFFFFA726); // Orange
    return const Color(0xFF66BB6A); // Green
  }
}

/// Prediction for next visit date
class DateTimePrediction {
  final DateTime predictedDate;
  final double confidence;
  final double averageIntervalDays;

  DateTimePrediction({
    required this.predictedDate,
    required this.confidence,
    required this.averageIntervalDays,
  });
}

/// Optimal time slot recommendation
class OptimalSlot {
  final int preferredHour;
  final int preferredWeekday;
  final double confidence;
  final String reason;

  OptimalSlot({
    required this.preferredHour,
    required this.preferredWeekday,
    required this.confidence,
    required this.reason,
  });

  String get weekdayName {
    const names = ['', 'Lunedì', 'Martedì', 'Mercoledì', 'Giovedì', 'Venerdì', 'Sabato', 'Domenica'];
    return names[preferredWeekday];
  }

  String get timeLabel => '$preferredHour:00';
}

/// Service recommendation
class ServiceRecommendation {
  final String serviceName;
  final double confidence;
  final String reason;

  ServiceRecommendation({
    required this.serviceName,
    required this.confidence,
    required this.reason,
  });
}

/// Center-wide ML insights
class CenterMLInsights {
  final List<ClientNoShowRisk> highRiskNoShows;
  final List<ClientValueProfile> highValueClients;
  final List<SlotOptimization> slotOptimization;
  final DateTime generatedAt;

  CenterMLInsights({
    required this.highRiskNoShows,
    required this.highValueClients,
    required this.slotOptimization,
    required this.generatedAt,
  });
}

/// Individual client no-show risk
class ClientNoShowRisk {
  final String clientId;
  final String clientName;
  final double riskScore;
  final AppointmentData? upcomingAppointment;

  ClientNoShowRisk({
    required this.clientId,
    required this.clientName,
    required this.riskScore,
    this.upcomingAppointment,
  });
}

/// Client value profile for segmentation
class ClientValueProfile {
  final String clientId;
  final String clientName;
  final double lifetimeValue;
  final double monthlyAverage;
  final String segment;

  ClientValueProfile({
    required this.clientId,
    required this.clientName,
    required this.lifetimeValue,
    required this.monthlyAverage,
    required this.segment,
  });
}

/// Slot optimization suggestion
class SlotOptimization {
  final DateTime slotTime;
  final int suggestedDuration;
  final String reason;
  final double expectedUtilization;

  SlotOptimization({
    required this.slotTime,
    required this.suggestedDuration,
    required this.reason,
    required this.expectedUtilization,
  });
}

/// Appointment risk assessment
class AppointmentRisk {
  final String appointmentId;
  final String clientName;
  final DateTime appointmentTime;
  final double riskScore;
  final List<String> riskFactors;
  final String suggestedAction;

  AppointmentRisk({
    required this.appointmentId,
    required this.clientName,
    required this.appointmentTime,
    required this.riskScore,
    required this.riskFactors,
    required this.suggestedAction,
  });

  String get riskLevel {
    if (riskScore > 0.7) return 'Critico';
    if (riskScore > 0.5) return 'Alto';
    return 'Moderato';
  }
}
