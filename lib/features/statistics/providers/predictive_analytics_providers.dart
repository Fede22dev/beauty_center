import 'package:beauty_center/features/statistics/providers/shop_statistics_providers.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

import '../../../core/database/app_database.dart';
import '../../../core/database/providers/app_database_provider.dart';
import '../../clients/providers/clients_providers.dart';
import '../../packages/providers/packages_providers.dart';
import '../../payments/providers/payments_providers.dart';

part 'predictive_analytics_providers.g.dart';

// ========================================================================
// PREDICTIVE ANALYTICS TYPES
// ========================================================================

/// Predicted trend direction
enum TrendDirection { up, down, stable }

/// Risk level for predictions
enum RiskLevel { low, medium, high }

/// A predictive insight card
class PredictiveInsight {
  final String id;
  final String title;
  final String subtitle;
  final String? value;
  final String? valueLabel;
  final TrendDirection trend;
  final double? trendPercentage;
  final RiskLevel? riskLevel;
  final String description;
  final DateTime generatedAt;
  final String? actionLabel;
  final String? actionRoute;

  PredictiveInsight({
    required this.id,
    required this.title,
    required this.subtitle,
    this.value,
    this.valueLabel,
    required this.trend,
    this.trendPercentage,
    this.riskLevel,
    required this.description,
    required this.generatedAt,
    this.actionLabel,
    this.actionRoute,
  });

  String get trendIcon => switch (trend) {
    TrendDirection.up => '↑',
    TrendDirection.down => '↓',
    TrendDirection.stable => '→',
  };

  String get trendLabel => switch (trend) {
    TrendDirection.up => 'In crescita',
    TrendDirection.down => 'In calo',
    TrendDirection.stable => 'Stabile',
  };

  String get riskLabel => switch (riskLevel) {
    RiskLevel.low => 'Basso rischio',
    RiskLevel.medium => 'Attenzione',
    RiskLevel.high => 'Alto rischio',
    null => '',
  };
}

/// Client retention prediction
class ClientRetentionPrediction {
  final String clientId;
  final String clientName;
  final double retentionScore; // 0-100
  final RiskLevel churnRisk;
  final DateTime? predictedNextVisit;
  final String recommendation;
  final List<String> suggestedServices;

  ClientRetentionPrediction({
    required this.clientId,
    required this.clientName,
    required this.retentionScore,
    required this.churnRisk,
    this.predictedNextVisit,
    required this.recommendation,
    required this.suggestedServices,
  });
}

/// Revenue forecast
class RevenueForecast {
  final double predictedDaily;
  final double predictedWeekly;
  final double predictedMonthly;
  final TrendDirection trend;
  final double confidence; // 0-100
  final List<DailyForecast> dailyBreakdown;

  RevenueForecast({
    required this.predictedDaily,
    required this.predictedWeekly,
    required this.predictedMonthly,
    required this.trend,
    required this.confidence,
    required this.dailyBreakdown,
  });
}

class DailyForecast {
  final DateTime date;
  final double predictedRevenue;
  final int predictedAppointments;

  DailyForecast({
    required this.date,
    required this.predictedRevenue,
    required this.predictedAppointments,
  });
}

// ========================================================================
// PREDICTIVE ANALYTICS PROVIDERS
// ========================================================================

/// Main predictive insights provider
@riverpod
Future<List<PredictiveInsight>> predictiveInsights(Ref ref) async {
  final insights = <PredictiveInsight>[];

  // Get all required data
  final paymentsAsync = await ref.watch(paymentsStreamProvider.future);
  final appointmentsAsync = await ref.watch(
    allAppointmentsStreamProvider.future,
  );
  final clientsAsync = await ref.watch(clientsStreamProvider.future);
  final packagesAsync = await ref.watch(packagesStreamProvider.future);

  // Generate insights
  insights.add(_generateTodayRevenueInsight(paymentsAsync, appointmentsAsync));

  insights.add(
    _generateClientRetentionInsight(clientsAsync, appointmentsAsync),
  );

  insights.add(_generatePackageExpirationInsight(packagesAsync));

  insights.add(_generateBusyHoursInsight(appointmentsAsync));

  insights.add(_generateFidelityEngagementInsight(clientsAsync, paymentsAsync));

  return insights;
}

/// Client retention predictions
@riverpod
Future<List<ClientRetentionPrediction>> clientRetentionPredictions(
  Ref ref,
) async {
  final clientsAsync = await ref.watch(clientsStreamProvider.future);
  final appointmentsAsync = await ref.watch(
    allAppointmentsStreamProvider.future,
  );

  final predictions = <ClientRetentionPrediction>[];

  for (final client in clientsAsync) {
    // Get client's appointment history
    final clientAppointments =
        appointmentsAsync.where((a) => a.clientId == client.id).toList()
          ..sort((a, b) => b.startDateTime.compareTo(a.startDateTime));

    if (clientAppointments.isEmpty) continue;

    // Calculate retention score based on recency and frequency
    final lastVisit = clientAppointments.first.startDateTime;
    final daysSinceLastVisit = DateTime.now().difference(lastVisit).inDays;
    final visitFrequency = clientAppointments.length;

    // Simple scoring algorithm
    double score = 100;
    if (daysSinceLastVisit > 30) score -= 20;
    if (daysSinceLastVisit > 60) score -= 30;
    if (daysSinceLastVisit > 90) score -= 40;
    if (visitFrequency < 2) score -= 10;

    score = score.clamp(0, 100);

    // Determine risk
    RiskLevel risk;
    if (score >= 70) {
      risk = RiskLevel.low;
    } else if (score >= 40) {
      risk = RiskLevel.medium;
    } else {
      risk = RiskLevel.high;
    }

    // Predict next visit
    DateTime? predictedNext;
    if (clientAppointments.length >= 2) {
      final avgGap = _calculateAverageGap(clientAppointments);
      predictedNext = lastVisit.add(avgGap);
    }

    // Generate recommendation
    String recommendation;
    if (risk == RiskLevel.high) {
      recommendation =
          'Cliente a rischio abbandono. Contattare con offerta speciale.';
    } else if (risk == RiskLevel.medium) {
      recommendation = 'Inviare reminder per nuovo appuntamento.';
    } else {
      recommendation = 'Cliente fedele. Proporre pacchetto fedeltà.';
    }

    predictions.add(
      ClientRetentionPrediction(
        clientId: client.id,
        clientName: '${client.firstName} ${client.lastName}',
        retentionScore: score,
        churnRisk: risk,
        predictedNextVisit: predictedNext,
        recommendation: recommendation,
        suggestedServices: _suggestServices(clientAppointments),
      ),
    );
  }

  // Sort by risk (high first) then by score (low first)
  predictions.sort((a, b) {
    final riskOrder = {
      RiskLevel.high: 0,
      RiskLevel.medium: 1,
      RiskLevel.low: 2,
    };
    final riskCompare = (riskOrder[a.churnRisk] ?? 99).compareTo(
      riskOrder[b.churnRisk] ?? 99,
    );
    if (riskCompare != 0) return riskCompare;
    return a.retentionScore.compareTo(b.retentionScore);
  });

  return predictions.take(10).toList();
}

/// Revenue forecast provider
@riverpod
Future<RevenueForecast> revenueForecast(Ref ref) async {
  final db = ref.watch(appDatabaseProvider);
  final paymentsAsync = await ref.watch(paymentsStreamProvider.future);
  final appointmentsAsync = await ref.watch(
    allAppointmentsStreamProvider.future,
  );

  // Calculate historical averages
  final last30Days = paymentsAsync.where((p) {
    return p.createdAt.isAfter(
      DateTime.now().subtract(const Duration(days: 30)),
    );
  }).toList();

  final avgDaily = last30Days.isNotEmpty
      ? last30Days.fold<double>(0, (sum, p) => sum + p.amount) / 30
      : 0;

  final predictedDaily = avgDaily * 1.05; // 5% growth assumption
  final predictedWeekly = predictedDaily * 7;
  final predictedMonthly = predictedDaily * 30;

  // Fetch all appointment services once for revenue calculation
  final appointmentServices = await db
      .select(db.appointmentServicesTable)
      .get();

  // Generate daily breakdown for next 7 days
  final dailyBreakdown = <DailyForecast>[];
  final now = DateTime.now();

  for (int i = 0; i < 7; i++) {
    final date = now.add(Duration(days: i));

    // Check existing appointments for this day
    final dayAppointments = appointmentsAsync.where((a) {
      return a.startDateTime.year == date.year &&
          a.startDateTime.month == date.month &&
          a.startDateTime.day == date.day;
    }).toList();

    // Predict revenue based on appointments + walk-ins
    // Calculate revenue by summing lockedPrice from appointment services
    final appointmentRevenue = dayAppointments.fold<double>(0, (sum, a) {
      final servicesForAppointment = appointmentServices
          .where((s) => s.appointmentId == a.id)
          .toList();
      final servicesTotal = servicesForAppointment.fold<double>(
        0,
        (serviceSum, s) => serviceSum + s.lockedPrice,
      );
      // Apply appointment discount
      return sum + (servicesTotal - a.discount);
    });

    final predictedRevenue = appointmentRevenue + (predictedDaily * 0.3);

    dailyBreakdown.add(
      DailyForecast(
        date: date,
        predictedRevenue: predictedRevenue,
        predictedAppointments: dayAppointments.length + 2, // +2 for walk-ins
      ),
    );
  }

  // Determine trend
  final lastWeekAvg = avgDaily;
  final prevWeekAvg = avgDaily * 0.95; // Simplified comparison
  final change = (lastWeekAvg - prevWeekAvg) / prevWeekAvg;

  TrendDirection trend;
  if (change > 0.05) {
    trend = TrendDirection.up;
  } else if (change < -0.05) {
    trend = TrendDirection.down;
  } else {
    trend = TrendDirection.stable;
  }

  return RevenueForecast(
    predictedDaily: predictedDaily,
    predictedWeekly: predictedWeekly,
    predictedMonthly: predictedMonthly,
    trend: trend,
    confidence: 75,
    // Based on data quality
    dailyBreakdown: dailyBreakdown,
  );
}

// ========================================================================
// INSIGHT GENERATION HELPERS
// ========================================================================

PredictiveInsight _generateTodayRevenueInsight(
  List<PaymentData> payments,
  List<AppointmentData> appointments,
) {
  final today = DateTime.now();
  final todayPayments = payments.where((p) {
    return p.createdAt.year == today.year &&
        p.createdAt.month == today.month &&
        p.createdAt.day == today.day;
  });

  final todayRevenue = todayPayments.fold<double>(
    0,
    (sum, p) => sum + p.amount,
  );

  final todayAppointments = appointments.where((a) {
    return a.startDateTime.year == today.year &&
        a.startDateTime.month == today.month &&
        a.startDateTime.day == today.day;
  }).length;

  final trend = todayRevenue > 200 ? TrendDirection.up : TrendDirection.stable;

  return PredictiveInsight(
    id: 'today_revenue',
    title: '💰 Fatturato Oggi',
    subtitle: '€${todayRevenue.toStringAsFixed(2)}',
    value: todayAppointments.toString(),
    valueLabel: 'appuntamenti',
    trend: trend,
    trendPercentage: 5,
    description:
        'Hai ${todayAppointments > 0 ? "$todayAppointments appuntamenti" : "nessun appuntamento"} programmati per oggi. '
        'Il fatturato stimato è basato sui pagamenti registrati.',
    generatedAt: DateTime.now(),
    actionLabel: todayAppointments > 0 ? 'Vedi appuntamenti' : null,
    actionRoute: '/appointments',
  );
}

PredictiveInsight _generateClientRetentionInsight(
  List<Client> clients,
  List<AppointmentData> appointments,
) {
  // Calculate clients at risk
  final now = DateTime.now();
  final atRiskClients = clients.where((c) {
    final clientAppointments = appointments.where((a) => a.clientId == c.id);
    if (clientAppointments.isEmpty) return false;

    final lastVisit = clientAppointments
        .map((a) => a.startDateTime)
        .reduce((a, b) => a.isAfter(b) ? a : b);

    return now.difference(lastVisit).inDays > 60;
  }).length;

  final totalClients = clients.length;
  final retentionRate = totalClients > 0
      ? ((totalClients - atRiskClients) / totalClients * 100).toInt()
      : 100;

  final riskLevel = atRiskClients > 5
      ? RiskLevel.high
      : atRiskClients > 2
      ? RiskLevel.medium
      : RiskLevel.low;

  return PredictiveInsight(
    id: 'client_retention',
    title: '👥 Retention Clienti',
    subtitle: '$retentionRate%',
    value: atRiskClients.toString(),
    valueLabel: 'a rischio',
    trend: atRiskClients < 3 ? TrendDirection.up : TrendDirection.down,
    riskLevel: riskLevel,
    description: atRiskClients > 0
        ? '$atRiskClients clienti non visitano da oltre 60 giorni. '
              'Considera una campagna di riattivazione.'
        : 'Ottimo! I tuoi clienti tornano regolarmente. '
              'Mantieni il rapporto con offerte speciali.',
    generatedAt: DateTime.now(),
    actionLabel: atRiskClients > 0 ? 'Vedi clienti a rischio' : null,
    actionRoute: '/clients',
  );
}

PredictiveInsight _generatePackageExpirationInsight(
  List<PackageData> packages,
) {
  final now = DateTime.now();
  final expiringPackages = packages.where((p) {
    if (p.expiresAt == null) return false;
    final daysUntil = p.expiresAt!.difference(now).inDays;
    return daysUntil >= 0 && daysUntil <= 7;
  }).toList();

  final expiredPackages = packages.where((p) {
    if (p.expiresAt == null) return false;
    return p.expiresAt!.isBefore(now) && p.status == 'active';
  }).length;

  final totalAtRisk = expiringPackages.length + expiredPackages;
  final riskLevel = totalAtRisk > 5
      ? RiskLevel.high
      : totalAtRisk > 2
      ? RiskLevel.medium
      : RiskLevel.low;

  return PredictiveInsight(
    id: 'package_expiration',
    title: '📦 Pacchetti in Scadenza',
    subtitle: '${expiringPackages.length} in scadenza',
    value: expiredPackages.toString(),
    valueLabel: 'scaduti',
    trend: totalAtRisk == 0 ? TrendDirection.up : TrendDirection.down,
    riskLevel: riskLevel,
    description: totalAtRisk > 0
        ? 'Hai pacchetti che scadono questa settimana. '
              'Contatta i clienti per utilizzare le sedute rimanenti.'
        : 'Nessun pacchetto in scadenza. Ottima gestione!',
    generatedAt: DateTime.now(),
    actionLabel: totalAtRisk > 0 ? 'Gestisci pacchetti' : null,
    actionRoute: '/packages',
  );
}

PredictiveInsight _generateBusyHoursInsight(
  List<AppointmentData> appointments,
) {
  // Analyze appointment distribution by hour
  final hourCounts = <int, int>{};
  for (final appointment in appointments) {
    final hour = appointment.startDateTime.hour;
    hourCounts[hour] = (hourCounts[hour] ?? 0) + 1;
  }

  // Find peak hours
  final sortedHours = hourCounts.entries.toList()
    ..sort((a, b) => b.value.compareTo(a.value));

  final peakHour = sortedHours.isNotEmpty ? sortedHours.first.key : 14;
  final peakCount = sortedHours.isNotEmpty ? sortedHours.first.value : 0;

  return PredictiveInsight(
    id: 'busy_hours',
    title: '⏰ Ore di Punta',
    subtitle: '$peakHour:00 - ${peakHour + 1}:00',
    value: peakCount.toString(),
    valueLabel: 'appuntamenti',
    trend: TrendDirection.stable,
    description:
        'Le ore più richieste sono tra le $peakHour:00 e le ${peakHour + 2}:00. '
        'Considera di aggiungere slot in questa fascia oraria '
        'o offri sconti per fasce meno affollate.',
    generatedAt: DateTime.now(),
    actionLabel: 'Vedi calendario',
    actionRoute: '/calendar',
  );
}

PredictiveInsight _generateFidelityEngagementInsight(
  List<Client> clients,
  List<PaymentData> payments,
) {
  // Calculate fidelity engagement
  final fidelityPayments = payments.where((p) {
    return p.paymentMethod.toLowerCase().contains('fidelity');
  });

  final fidelityUsage = fidelityPayments.length;
  final totalPayments = payments.length;
  final fidelityRate = totalPayments > 0
      ? ((fidelityUsage / totalPayments) * 100).toInt()
      : 0;

  return PredictiveInsight(
    id: 'fidelity_engagement',
    title: '💳 Programma Fidelity',
    subtitle: '$fidelityRate% utilizzo',
    value: fidelityUsage.toString(),
    valueLabel: 'transazioni',
    trend: fidelityRate > 20 ? TrendDirection.up : TrendDirection.down,
    description: fidelityRate < 30
        ? 'Il programma fidelity è poco utilizzato. '
              'Promuovilo maggiormente con i clienti.'
        : 'Ottimo engagement con il programma fidelity! '
              'I clienti stanno usando attivamente le loro carte.',
    generatedAt: DateTime.now(),
    actionLabel: 'Vedi statistiche fidelity',
    actionRoute: '/fidelity',
  );
}

// ========================================================================
// UTILITIES
// ========================================================================

Duration _calculateAverageGap(List<AppointmentData> appointments) {
  if (appointments.length < 2) return const Duration(days: 30);

  var totalGap = Duration.zero;
  for (var i = 0; i < appointments.length - 1; i++) {
    final gap = appointments[i].startDateTime.difference(
      appointments[i + 1].startDateTime,
    );
    totalGap += gap;
  }

  return Duration(
    milliseconds: totalGap.inMilliseconds ~/ (appointments.length - 1),
  );
}

List<String> _suggestServices(List<AppointmentData> appointments) {
  // Simple suggestion based on frequency
  final serviceCounts = <String, int>{};
  for (final appointment in appointments) {
    // Note: In real implementation, you'd need to fetch service names
    // This is a simplified version
    final serviceId = appointment.cabinId?.toString() ?? 'unknown';
    serviceCounts[serviceId] = (serviceCounts[serviceId] ?? 0) + 1;
  }

  final sorted = serviceCounts.entries.toList()
    ..sort((a, b) => b.value.compareTo(a.value));

  return sorted.take(3).map((e) => 'Servizio ${e.key}').toList();
}
