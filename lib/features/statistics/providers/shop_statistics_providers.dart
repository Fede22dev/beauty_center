import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

import '../../../../core/database/app_database.dart';
import '../../../../core/database/providers/app_database_provider.dart';
import '../../treatments/providers/treatments_providers.dart';

part 'shop_statistics_providers.g.dart';

// ============================================================================
// SHOP OVERVIEW KPIs
// ============================================================================

/// Shop overview key metrics
@riverpod
Future<ShopOverviewData> shopOverview(Ref ref) async {
  final results = await Future.wait([
    ref.watch(allClientsStreamProvider.future),
    ref.watch(allAppointmentsStreamProvider.future),
    ref.watch(allPaymentsStreamProvider.future),
    ref.watch(activePackagesStreamProvider.future),
    ref.watch(activeFidelityCardsStreamProvider.future),
  ]);

  final clients = results[0] as List<Client>;
  final appointments = results[1] as List<AppointmentData>;
  final payments = results[2] as List<PaymentData>;
  final packages = results[3] as List<PackageData>;
  final fidelityCards = results[4] as List<FidelityCardData>;

  final now = DateTime.now();
  final today = DateTime(now.year, now.month, now.day);
  final thisMonthStart = DateTime(now.year, now.month, 1);
  final lastMonthStart = DateTime(now.year, now.month - 1, 1);

  // Revenue calculations
  final totalRevenue = payments
      .where((p) => p.amount > 0)
      .fold<double>(0, (sum, p) => sum + p.amount);

  final todayRevenue = payments
      .where((p) => p.amount > 0 && p.paidAt.isAfter(today))
      .fold<double>(0, (sum, p) => sum + p.amount);

  final thisMonthRevenue = payments
      .where((p) => p.amount > 0 && p.paidAt.isAfter(thisMonthStart))
      .fold<double>(0, (sum, p) => sum + p.amount);

  final lastMonthRevenue = payments
      .where(
        (p) =>
            p.amount > 0 &&
            p.paidAt.isAfter(lastMonthStart) &&
            p.paidAt.isBefore(thisMonthStart),
      )
      .fold<double>(0, (sum, p) => sum + p.amount);

  // Growth rate
  final revenueGrowthRate = lastMonthRevenue > 0
      ? ((thisMonthRevenue - lastMonthRevenue) / lastMonthRevenue) * 100
      : 0.0;

  // Client metrics
  final newClientsThisMonth = clients
      .where((c) => c.createdAt.isAfter(thisMonthStart))
      .length;

  // Appointments today
  final appointmentsToday = appointments.where(
    (a) =>
        a.startDateTime.year == now.year &&
        a.startDateTime.month == now.month &&
        a.startDateTime.day == now.day,
  );

  // Average ticket
  final avgTicket = payments.isNotEmpty ? totalRevenue / payments.length : 0;

  return ShopOverviewData(
    totalRevenue: totalRevenue,
    todayRevenue: todayRevenue,
    thisMonthRevenue: thisMonthRevenue,
    revenueGrowthRate: revenueGrowthRate,
    totalClients: clients.length,
    newClientsThisMonth: newClientsThisMonth,
    totalAppointments: appointments.length,
    appointmentsToday: appointmentsToday.length,
    activePackages: packages.where((p) => p.status == 'active').length,
    totalFidelityBalance: fidelityCards.fold<double>(
      0,
      (sum, c) => sum + c.balance,
    ),
    averageTicket: avgTicket.toDouble(),
  );
}

// ============================================================================
// REVENUE ANALYTICS
// ============================================================================

/// Monthly revenue trend (last 12 months)
@riverpod
Future<List<MonthlyRevenueData>> monthlyRevenueTrend(Ref ref) async {
  final payments = await ref.watch(allPaymentsStreamProvider.future);
  final now = DateTime.now();

  final monthlyData = <int, MonthlyRevenueData>{};

  // Initialize last 12 months
  for (int i = 0; i < 12; i++) {
    final date = DateTime(now.year, now.month - i, 1);
    final key = date.year * 12 + date.month;
    monthlyData[key] = MonthlyRevenueData(
      year: date.year,
      month: date.month,
      monthName: _getMonthName(date.month),
      revenue: 0,
      paymentCount: 0,
    );
  }

  // Aggregate payments
  for (final payment in payments.where((p) => p.amount > 0)) {
    final key = payment.paidAt.year * 12 + payment.paidAt.month;
    if (monthlyData.containsKey(key)) {
      final current = monthlyData[key]!;
      monthlyData[key] = MonthlyRevenueData(
        year: payment.paidAt.year,
        month: payment.paidAt.month,
        monthName: current.monthName,
        revenue: current.revenue + payment.amount,
        paymentCount: current.paymentCount + 1,
      );
    }
  }

  return monthlyData.values.toList()
    ..sort((a, b) => (a.year * 12 + a.month).compareTo(b.year * 12 + b.month));
}

/// Revenue breakdown by service category
@riverpod
Future<List<RevenueByCategory>> revenueByCategory(Ref ref) async {
  final payments = await ref.watch(allPaymentsStreamProvider.future);
  final db = ref.read(appDatabaseProvider);

  final categories = <String, double>{};

  // Pre-load package items once to avoid N+1 query
  final packageItems = await db.select(db.packageItemsTable).get();
  final packageIdsWithItems = packageItems.map((i) => i.packageId).toSet();

  for (final payment in payments.where((p) => p.amount > 0)) {
    String category = 'Altro';

    if (payment.packageId != null && packageIdsWithItems.contains(payment.packageId)) {
      category = 'Pacchetti';
    } else if (payment.productSaleId != null) {
      category = 'Prodotti';
    } else if (payment.appointmentId != null) {
      category = 'Servizi Singoli';
    }

    categories[category] = (categories[category] ?? 0) + payment.amount;
  }

  final total = categories.values.fold<double>(0, (sum, v) => sum + v);

  return categories.entries
      .map(
        (e) => RevenueByCategory(
          category: e.key,
          amount: e.value,
          percentage: total > 0 ? (e.value / total) * 100 : 0,
        ),
      )
      .toList()
    ..sort((a, b) => b.amount.compareTo(a.amount));
}

// ============================================================================
// CLIENT ANALYTICS
// ============================================================================

/// Client acquisition trend (last 12 months)
@riverpod
Future<List<ClientAcquisitionData>> clientAcquisitionTrend(Ref ref) async {
  final clients = await ref.watch(allClientsStreamProvider.future);
  final now = DateTime.now();

  final monthlyData = <int, ClientAcquisitionData>{};

  // Initialize last 12 months
  for (int i = 0; i < 12; i++) {
    final date = DateTime(now.year, now.month - i, 1);
    final key = date.year * 12 + date.month;
    monthlyData[key] = ClientAcquisitionData(
      year: date.year,
      month: date.month,
      monthName: _getMonthName(date.month),
      newClients: 0,
    );
  }

  // Aggregate client registrations
  for (final client in clients) {
    final key = client.createdAt.year * 12 + client.createdAt.month;
    if (monthlyData.containsKey(key)) {
      final current = monthlyData[key]!;
      monthlyData[key] = ClientAcquisitionData(
        year: current.year,
        month: current.month,
        monthName: current.monthName,
        newClients: current.newClients + 1,
      );
    }
  }

  return monthlyData.values.toList()
    ..sort((a, b) => (a.year * 12 + a.month).compareTo(b.year * 12 + b.month));
}

/// Top clients by revenue
@riverpod
Future<List<TopClientData>> topClientsByRevenue(
  Ref ref, {
  int limit = 10,
}) async {
  final payments = await ref.watch(allPaymentsStreamProvider.future);
  final clients = await ref.watch(allClientsStreamProvider.future);

  final clientRevenue = <String, double>{};

  for (final payment in payments.where((p) => p.amount > 0)) {
    if (payment.clientId != null) {
      clientRevenue[payment.clientId!] =
          (clientRevenue[payment.clientId!] ?? 0) + payment.amount;
    }
  }

  final sorted = clientRevenue.entries.toList()
    ..sort((a, b) => b.value.compareTo(a.value));

  return sorted.take(limit).map((e) {
    final client = clients.firstWhere(
      (c) => c.id == e.key,
      orElse: () => Client(
        id: e.key,
        firstName: 'Sconosciuto',
        lastName: '',
        phoneNumber: '',
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
        isActive: true,
      ),
    );

    return TopClientData(
      clientId: e.key,
      clientName: '${client.firstName} ${client.lastName}',
      totalRevenue: e.value,
    );
  }).toList();
}

/// Client retention metrics
@riverpod
Future<ClientRetentionMetrics> clientRetentionMetrics(Ref ref) async {
  final clients = await ref.watch(allClientsStreamProvider.future);
  final appointments = await ref.watch(allAppointmentsStreamProvider.future);
  final now = DateTime.now();

  final threeMonthsAgo = now.subtract(const Duration(days: 90));
  final sixMonthsAgo = now.subtract(const Duration(days: 180));

  // Active clients (appointment in last 3 months)
  final activeClientIds = appointments
      .where((a) => a.startDateTime.isAfter(threeMonthsAgo))
      .map((a) => a.clientId)
      .where((id) => id != null)
      .toSet();

  // At-risk clients (no appointment in 3-6 months)
  final atRiskClientIds = appointments
      .where(
        (a) =>
            a.startDateTime.isAfter(sixMonthsAgo) &&
            a.startDateTime.isBefore(threeMonthsAgo),
      )
      .map((a) => a.clientId)
      .where((id) => id != null && !activeClientIds.contains(id))
      .toSet();

  // Lost clients (no appointment in 6+ months)
  final lostClientIds = clients
      .where(
        (c) =>
            !activeClientIds.contains(c.id) && !atRiskClientIds.contains(c.id),
      )
      .map((c) => c.id)
      .toSet();

  final total = clients.length;

  return ClientRetentionMetrics(
    totalClients: total,
    activeClients: activeClientIds.length,
    atRiskClients: atRiskClientIds.length,
    lostClients: lostClientIds.length,
    activePercentage: total > 0 ? (activeClientIds.length / total) * 100 : 0,
    atRiskPercentage: total > 0 ? (atRiskClientIds.length / total) * 100 : 0,
    lostPercentage: total > 0 ? (lostClientIds.length / total) * 100 : 0,
  );
}

// ============================================================================
// SERVICE ANALYTICS
// ============================================================================

/// Top performing services
@riverpod
Future<List<TopServiceData>> topPerformingServices(
  Ref ref, {
  int limit = 10,
}) async {
  final db = ref.read(appDatabaseProvider);
  final appointments = await ref.watch(allAppointmentsStreamProvider.future);
  final services = await ref.watch(servicesStreamProvider.future);

  final serviceUsage = <String, int>{};

  // Single query for all relevant appointment services (avoids N+1)
  final appointmentIds = appointments.map((a) => a.id).toSet();
  if (appointmentIds.isNotEmpty) {
    final allApptServices = await (db.select(db.appointmentServicesTable)
          ..where((t) => t.appointmentId.isIn(appointmentIds)))
        .get();

    for (final apptService in allApptServices) {
      serviceUsage[apptService.serviceId] =
          (serviceUsage[apptService.serviceId] ?? 0) + 1;
    }
  }

  final sorted = serviceUsage.entries.toList()
    ..sort((a, b) => b.value.compareTo(a.value));

  return sorted.take(limit).map((e) {
    final service = services.firstWhere(
      (s) => s.id == e.key,
      orElse: () => ServiceData(
        id: e.key,
        name: 'Servizio sconosciuto',
        durationMinutes: 30,
        price: 0,
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
        isActive: true,
      ),
    );

    return TopServiceData(
      serviceId: e.key,
      serviceName: service.name,
      usageCount: e.value,
      price: service.price,
    );
  }).toList();
}

/// Service popularity by time slot
@riverpod
Future<List<TimeSlotPopularity>> servicePopularityByTimeSlot(Ref ref) async {
  final appointments = await ref.watch(allAppointmentsStreamProvider.future);

  final slots = <String, int>{
    'Mattina (8-12)': 0,
    'Pomeriggio (12-17)': 0,
    'Sera (17-21)': 0,
  };

  for (final appointment in appointments) {
    final hour = appointment.startDateTime.hour;
    if (hour >= 8 && hour < 12) {
      slots['Mattina (8-12)'] = slots['Mattina (8-12)']! + 1;
    } else if (hour >= 12 && hour < 17) {
      slots['Pomeriggio (12-17)'] = slots['Pomeriggio (12-17)']! + 1;
    } else if (hour >= 17 && hour < 21) {
      slots['Sera (17-21)'] = slots['Sera (17-21)']! + 1;
    }
  }

  final total = slots.values.fold<int>(0, (sum, v) => sum + v);

  return slots.entries
      .map(
        (e) => TimeSlotPopularity(
          timeSlot: e.key,
          appointmentCount: e.value,
          percentage: total > 0 ? (e.value / total) * 100 : 0,
        ),
      )
      .toList();
}

// ============================================================================
// APPOINTMENT ANALYTICS
// ============================================================================

/// Daily appointment distribution (week view)
@riverpod
Future<List<DailyAppointmentStats>> weeklyAppointmentDistribution(
  Ref ref,
) async {
  final appointments = await ref.watch(allAppointmentsStreamProvider.future);
  final now = DateTime.now();

  // Get last 30 days for average
  final thirtyDaysAgo = now.subtract(const Duration(days: 30));
  final recentAppointments = appointments.where(
    (a) => a.startDateTime.isAfter(thirtyDaysAgo),
  );

  final days = ['Lun', 'Mar', 'Mer', 'Gio', 'Ven', 'Sab', 'Dom'];
  final counts = List<int>.filled(7, 0);

  for (final appointment in recentAppointments) {
    final weekday = appointment.startDateTime.weekday - 1; // 0 = Monday
    counts[weekday]++;
  }

  return List.generate(
    7,
    (i) => DailyAppointmentStats(dayName: days[i], appointmentCount: counts[i]),
  );
}

/// Cancellation rate metrics
@riverpod
Future<AppointmentMetrics> appointmentMetrics(Ref ref) async {
  final appointments = await ref.watch(allAppointmentsStreamProvider.future);

  final total = appointments.length;
  final completed = appointments.where((a) => a.isActive).length;
  final cancelled = total - completed;

  return AppointmentMetrics(
    totalAppointments: total,
    completedAppointments: completed,
    cancelledAppointments: cancelled,
    completionRate: total > 0 ? (completed / total) * 100 : 0,
    cancellationRate: total > 0 ? (cancelled / total) * 100 : 0,
  );
}

// ============================================================================
// DATA CLASSES
// ============================================================================

class ShopOverviewData {
  final double totalRevenue;
  final double todayRevenue;
  final double thisMonthRevenue;
  final double revenueGrowthRate;
  final int totalClients;
  final int newClientsThisMonth;
  final int totalAppointments;
  final int appointmentsToday;
  final int activePackages;
  final double totalFidelityBalance;
  final double averageTicket;

  const ShopOverviewData({
    required this.totalRevenue,
    required this.todayRevenue,
    required this.thisMonthRevenue,
    required this.revenueGrowthRate,
    required this.totalClients,
    required this.newClientsThisMonth,
    required this.totalAppointments,
    required this.appointmentsToday,
    required this.activePackages,
    required this.totalFidelityBalance,
    required this.averageTicket,
  });
}

class MonthlyRevenueData {
  final int year;
  final int month;
  final String monthName;
  final double revenue;
  final int paymentCount;

  const MonthlyRevenueData({
    required this.year,
    required this.month,
    required this.monthName,
    required this.revenue,
    required this.paymentCount,
  });
}

class RevenueByCategory {
  final String category;
  final double amount;
  final double percentage;

  const RevenueByCategory({
    required this.category,
    required this.amount,
    required this.percentage,
  });
}

class ClientAcquisitionData {
  final int year;
  final int month;
  final String monthName;
  final int newClients;

  const ClientAcquisitionData({
    required this.year,
    required this.month,
    required this.monthName,
    required this.newClients,
  });
}

class TopClientData {
  final String clientId;
  final String clientName;
  final double totalRevenue;

  const TopClientData({
    required this.clientId,
    required this.clientName,
    required this.totalRevenue,
  });
}

class ClientRetentionMetrics {
  final int totalClients;
  final int activeClients;
  final int atRiskClients;
  final int lostClients;
  final double activePercentage;
  final double atRiskPercentage;
  final double lostPercentage;

  const ClientRetentionMetrics({
    required this.totalClients,
    required this.activeClients,
    required this.atRiskClients,
    required this.lostClients,
    required this.activePercentage,
    required this.atRiskPercentage,
    required this.lostPercentage,
  });
}

class TopServiceData {
  final String serviceId;
  final String serviceName;
  final int usageCount;
  final double price;

  const TopServiceData({
    required this.serviceId,
    required this.serviceName,
    required this.usageCount,
    required this.price,
  });
}

class TimeSlotPopularity {
  final String timeSlot;
  final int appointmentCount;
  final double percentage;

  const TimeSlotPopularity({
    required this.timeSlot,
    required this.appointmentCount,
    required this.percentage,
  });
}

class DailyAppointmentStats {
  final String dayName;
  final int appointmentCount;

  const DailyAppointmentStats({
    required this.dayName,
    required this.appointmentCount,
  });
}

class AppointmentMetrics {
  final int totalAppointments;
  final int completedAppointments;
  final int cancelledAppointments;
  final double completionRate;
  final double cancellationRate;

  const AppointmentMetrics({
    required this.totalAppointments,
    required this.completedAppointments,
    required this.cancelledAppointments,
    required this.completionRate,
    required this.cancellationRate,
  });
}

// ============================================================================
// HELPER FUNCTIONS
// ============================================================================

String _getMonthName(int month) {
  const months = [
    'Gen',
    'Feb',
    'Mar',
    'Apr',
    'Mag',
    'Giu',
    'Lug',
    'Ago',
    'Set',
    'Ott',
    'Nov',
    'Dic',
  ];
  return months[month - 1];
}

// ============================================================================
// ALL DATA PROVIDERS (for aggregating data)
// ============================================================================

/// All clients for shop statistics
final allClientsStreamProvider = StreamProvider<List<Client>>(
  (ref) => ref.read(appDatabaseProvider).managers.clientsTable.watch(),
);

/// All appointments for shop statistics
final allAppointmentsStreamProvider = StreamProvider<List<AppointmentData>>(
  (ref) => ref.read(appDatabaseProvider).managers.appointmentsTable.watch(),
);

/// All payments for shop statistics
final allPaymentsStreamProvider = StreamProvider<List<PaymentData>>(
  (ref) => ref.read(appDatabaseProvider).managers.paymentsTable.watch(),
);

/// Active packages stream
final activePackagesStreamProvider = StreamProvider<List<PackageData>>(
  (ref) => ref
      .read(appDatabaseProvider)
      .managers.packagesTable
      .watch()
      .map((list) => list.where((p) => p.status == 'active').toList()),
);

/// Active fidelity cards stream
final activeFidelityCardsStreamProvider =
    StreamProvider<List<FidelityCardData>>(
      (ref) => ref
          .read(appDatabaseProvider)
          .managers.fidelityCardsTable
          .watch()
          .map((list) => list.where((c) => c.status == 'active').toList()),
    );
