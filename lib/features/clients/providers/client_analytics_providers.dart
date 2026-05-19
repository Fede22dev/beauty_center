import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:path/path.dart';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';
import 'package:syncfusion_flutter_pdf/pdf.dart';

import '../../../core/database/app_database.dart';
import '../../../core/logging/app_logger.dart';
import '../../../features/appointments/providers/appointments_providers.dart';
import '../../../features/fidelity/providers/fidelity_providers.dart';
import '../../../features/packages/providers/packages_providers.dart';
import '../../../features/payments/providers/payments_providers.dart';
import '../../../features/product_sales/providers/product_sales_providers.dart';
import '../../../features/products/providers/products_providers.dart';
import '../../../features/quotes/providers/quotes_providers.dart';
import '../../../features/treatments/providers/treatments_providers.dart';
import 'clients_providers.dart';

// ============================================================================
// CLIENT STATISTICS
// ============================================================================

/// Client statistics computed from various data sources
final clientStatisticsProvider = FutureProvider.family<ClientStats, String>((
  ref,
  clientId,
) async {
  // Watch all required data streams in parallel for better performance
  final results = await Future.wait([
    ref.watch(paymentsByClientStreamProvider(clientId).future),
    ref.watch(packagesByClientStreamProvider(clientId).future),
    ref.watch(clientAppointmentsStreamProvider(clientId).future),
    ref.watch(fidelityCardsByClientStreamProvider(clientId).future),
    ref.watch(quotesByClientStreamProvider(clientId).future),
    ref.watch(productSalesByClientStreamProvider(clientId).future),
  ]);

  final paymentsAsync = results[0] as List<PaymentData>;
  final packagesAsync = results[1] as List<PackageData>;
  final appointmentsAsync = results[2] as List<AppointmentData>;
  final fidelityAsync = results[3] as List<FidelityCardData>;
  final quotesAsync = results[4] as List<QuoteData>;
  final salesAsync = results[5] as List<ProductSaleData>;

  // Calculate total spent from payments
  final totalSpent = paymentsAsync.fold<double>(
    0,
    (sum, p) => sum + (p.amount > 0 ? p.amount : 0),
  );

  // Calculate total refunds
  final totalRefunds = paymentsAsync.fold<double>(
    0,
    (sum, p) => sum + (p.amount < 0 ? p.amount.abs() : 0),
  );

  // Package counts
  final activePackages = packagesAsync
      .where((p) => p.status == 'active')
      .length;
  final completedPackages = packagesAsync
      .where((p) => p.status == 'completed')
      .length;
  final expiredPackages = packagesAsync
      .where((p) => p.status == 'expired')
      .length;

  // Total appointments count
  final totalAppointments = appointmentsAsync.length;

  // Appointments this month
  final now = DateTime.now();
  final appointmentsThisMonth = appointmentsAsync
      .where(
        (a) =>
            a.startDateTime.year == now.year &&
            a.startDateTime.month == now.month,
      )
      .length;

  // Total fidelity balance
  final totalFidelityBalance = fidelityAsync.fold<double>(
    0,
    (sum, f) => sum + f.balance,
  );

  // Active fidelity cards count
  final activeFidelityCards = fidelityAsync
      .where((f) => f.status == 'active')
      .length;

  // Quotes counts
  final totalQuotes = quotesAsync.length;
  final acceptedQuotes = quotesAsync
      .where((q) => q.status == 'accepted')
      .length;
  final pendingQuotes = quotesAsync.where((q) => q.status == 'pending').length;

  // Total products purchased
  final totalProductsPurchased = salesAsync.fold<int>(
    0,
    (sum, s) => sum + s.quantity,
  );

  // Calculate visit dates
  final sortedAppointments = appointmentsAsync.toList()
    ..sort((a, b) => a.startDateTime.compareTo(b.startDateTime));
  final firstVisitDate = sortedAppointments.isNotEmpty
      ? sortedAppointments.first.startDateTime
      : null;
  final lastVisitDate = sortedAppointments.isNotEmpty
      ? sortedAppointments.last.startDateTime
      : null;

  // Days since last visit
  final daysSinceLastVisit = lastVisitDate != null
      ? now.difference(lastVisitDate).inDays
      : null;

  return ClientStats(
    totalSpent: totalSpent,
    totalRefunds: totalRefunds,
    netSpent: totalSpent - totalRefunds,
    activePackages: activePackages,
    completedPackages: completedPackages,
    expiredPackages: expiredPackages,
    totalAppointments: totalAppointments,
    appointmentsThisMonth: appointmentsThisMonth,
    totalFidelityBalance: totalFidelityBalance,
    activeFidelityCards: activeFidelityCards,
    totalQuotes: totalQuotes,
    acceptedQuotes: acceptedQuotes,
    pendingQuotes: pendingQuotes,
    totalProductsPurchased: totalProductsPurchased,
    firstVisitDate: firstVisitDate,
    lastVisitDate: lastVisitDate,
    daysSinceLastVisit: daysSinceLastVisit,
  );
});

/// Client statistics data class
class ClientStats {
  final double totalSpent;
  final double totalRefunds;
  final double netSpent;
  final int activePackages;
  final int completedPackages;
  final int expiredPackages;
  final int totalAppointments;
  final int appointmentsThisMonth;
  final double totalFidelityBalance;
  final int activeFidelityCards;
  final int totalQuotes;
  final int acceptedQuotes;
  final int pendingQuotes;
  final int totalProductsPurchased;
  final DateTime? firstVisitDate;
  final DateTime? lastVisitDate;
  final int? daysSinceLastVisit;

  const ClientStats({
    required this.totalSpent,
    required this.totalRefunds,
    required this.netSpent,
    required this.activePackages,
    required this.completedPackages,
    required this.expiredPackages,
    required this.totalAppointments,
    required this.appointmentsThisMonth,
    required this.totalFidelityBalance,
    required this.activeFidelityCards,
    required this.totalQuotes,
    required this.acceptedQuotes,
    required this.pendingQuotes,
    required this.totalProductsPurchased,
    this.firstVisitDate,
    this.lastVisitDate,
    this.daysSinceLastVisit,
  });
}

// ============================================================================
// CLIENT PREFERENCES (Services & Products)
// ============================================================================

/// Client service preferences - most used services
final clientServicePreferencesProvider =
    FutureProvider.family<List<ServicePreference>, String>((
      ref,
      clientId,
    ) async {
      final packagesAsync = await ref.watch(
        packagesByClientStreamProvider(clientId).future,
      );
      final serviceUsage = <String, ServiceUsage>{};

      // Collect service usage from packages
      final packagesRepo = ref.read(packagesRepositoryProvider);
      for (final package in packagesAsync) {
        final items = await packagesRepo.getPackageItemsByPackageId(package.id);
        for (final item in items) {
          final serviceId = item.serviceId;
          final serviceName = item.lockedServiceName;

          if (serviceUsage.containsKey(serviceId)) {
            serviceUsage[serviceId] = serviceUsage[serviceId]!.copyWith(
              count: serviceUsage[serviceId]!.count + item.totalSessions,
              usedSessions:
                  serviceUsage[serviceId]!.usedSessions + item.usedSessions,
            );
          } else {
            serviceUsage[serviceId] = ServiceUsage(
              serviceId: serviceId,
              serviceName: serviceName,
              count: item.totalSessions,
              usedSessions: item.usedSessions,
            );
          }
        }
      }

      // Sort by usage count
      final sorted = serviceUsage.values.toList()
        ..sort((a, b) => b.count.compareTo(a.count));

      return sorted
          .map(
            (s) => ServicePreference(
              serviceId: s.serviceId,
              serviceName: s.serviceName,
              totalSessions: s.count,
              usedSessions: s.usedSessions,
              remainingSessions: s.count - s.usedSessions,
            ),
          )
          .toList();
    });

/// Client product preferences - most purchased products
final clientProductPreferencesProvider =
    FutureProvider.family<List<ProductPreference>, String>((
      ref,
      clientId,
    ) async {
      final salesAsync = await ref.watch(
        productSalesByClientStreamProvider(clientId).future,
      );
      final productUsage = <String, ProductUsage>{};

      for (final sale in salesAsync) {
        final productId = sale.productId;
        final productName = sale.lockedProductName;

        if (productUsage.containsKey(productId)) {
          productUsage[productId] = productUsage[productId]!.copyWith(
            quantity: productUsage[productId]!.quantity + sale.quantity,
            totalSpent: productUsage[productId]!.totalSpent + sale.lineTotal,
          );
        } else {
          productUsage[productId] = ProductUsage(
            productId: productId,
            productName: productName,
            quantity: sale.quantity,
            totalSpent: sale.lineTotal,
          );
        }
      }

      // Sort by quantity purchased
      final sorted = productUsage.values.toList()
        ..sort((a, b) => b.quantity.compareTo(a.quantity));

      return sorted
          .map(
            (p) => ProductPreference(
              productId: p.productId,
              productName: p.productName,
              totalQuantity: p.quantity,
              totalSpent: p.totalSpent,
            ),
          )
          .toList();
    });

@immutable
class ServiceUsage {
  final String serviceId;
  final String serviceName;
  final int count;
  final int usedSessions;

  const ServiceUsage({
    required this.serviceId,
    required this.serviceName,
    required this.count,
    required this.usedSessions,
  });

  ServiceUsage copyWith({int? count, int? usedSessions}) => ServiceUsage(
    serviceId: serviceId,
    serviceName: serviceName,
    count: count ?? this.count,
    usedSessions: usedSessions ?? this.usedSessions,
  );
}

@immutable
class ProductUsage {
  final String productId;
  final String productName;
  final int quantity;
  final double totalSpent;

  const ProductUsage({
    required this.productId,
    required this.productName,
    required this.quantity,
    required this.totalSpent,
  });

  ProductUsage copyWith({int? quantity, double? totalSpent}) => ProductUsage(
    productId: productId,
    productName: productName,
    quantity: quantity ?? this.quantity,
    totalSpent: totalSpent ?? this.totalSpent,
  );
}

@immutable
class ServicePreference {
  final String serviceId;
  final String serviceName;
  final int totalSessions;
  final int usedSessions;
  final int remainingSessions;

  const ServicePreference({
    required this.serviceId,
    required this.serviceName,
    required this.totalSessions,
    required this.usedSessions,
    required this.remainingSessions,
  });
}

@immutable
class ProductPreference {
  final String productId;
  final String productName;
  final int totalQuantity;
  final double totalSpent;

  const ProductPreference({
    required this.productId,
    required this.productName,
    required this.totalQuantity,
    required this.totalSpent,
  });
}

// ============================================================================
// PACKAGE EXPIRATION ALERTS
// ============================================================================

/// Package expiration alerts for a client
final clientPackageExpirationAlertsProvider =
    FutureProvider.family<List<PackageExpirationAlert>, String>((
      ref,
      clientId,
    ) async {
      final packagesAsync = await ref.watch(
        packagesByClientStreamProvider(clientId).future,
      );
      final now = DateTime.now();
      final alerts = <PackageExpirationAlert>[];
      final packagesRepo = ref.read(packagesRepositoryProvider);

      for (final package in packagesAsync) {
        if (package.expiresAt == null || package.status != 'active') continue;

        final daysUntilExpiration = package.expiresAt!.difference(now).inDays;

        // Alert if expiring within 30 days or already expired
        if (daysUntilExpiration <= 30) {
          final items = await packagesRepo.getPackageItemsByPackageId(
            package.id,
          );
          final totalSessions = items.fold<int>(
            0,
            (sum, i) => sum + i.totalSessions,
          );
          final usedSessions = items.fold<int>(
            0,
            (sum, i) => sum + i.usedSessions,
          );

          alerts.add(
            PackageExpirationAlert(
              packageId: package.id,
              packageName: package.name,
              expiresAt: package.expiresAt!,
              daysUntilExpiration: daysUntilExpiration,
              isExpired: daysUntilExpiration < 0,
              isExpiringSoon:
                  daysUntilExpiration >= 0 && daysUntilExpiration <= 7,
              totalSessions: totalSessions,
              usedSessions: usedSessions,
              remainingSessions: totalSessions - usedSessions,
            ),
          );
        }
      }

      // Sort: expired first, then expiring soon, then by days
      alerts.sort((a, b) {
        if (a.isExpired != b.isExpired) return a.isExpired ? -1 : 1;
        if (a.isExpiringSoon != b.isExpiringSoon)
          return a.isExpiringSoon ? -1 : 1;
        return a.daysUntilExpiration.compareTo(b.daysUntilExpiration);
      });

      return alerts;
    });

@immutable
class PackageExpirationAlert {
  final String packageId;
  final String packageName;
  final DateTime expiresAt;
  final int daysUntilExpiration;
  final bool isExpired;
  final bool isExpiringSoon;
  final int totalSessions;
  final int usedSessions;
  final int remainingSessions;

  const PackageExpirationAlert({
    required this.packageId,
    required this.packageName,
    required this.expiresAt,
    required this.daysUntilExpiration,
    required this.isExpired,
    required this.isExpiringSoon,
    required this.totalSessions,
    required this.usedSessions,
    required this.remainingSessions,
  });
}

// ============================================================================
// HISTORY FILTERS STATE
// ============================================================================

enum HistoryFilterType { all, payments, appointments, fidelity }

@immutable
class HistoryFilters {
  final HistoryFilterType type;
  final DateTime? dateFrom;
  final DateTime? dateTo;
  final String searchQuery;

  const HistoryFilters({
    this.type = HistoryFilterType.all,
    this.dateFrom,
    this.dateTo,
    this.searchQuery = '',
  });

  HistoryFilters copyWith({
    HistoryFilterType? type,
    DateTime? dateFrom,
    DateTime? dateTo,
    String? searchQuery,
  }) => HistoryFilters(
    type: type ?? this.type,
    dateFrom: dateFrom ?? this.dateFrom,
    dateTo: dateTo ?? this.dateTo,
    searchQuery: searchQuery ?? this.searchQuery,
  );
}

/// State notifier for history filters
class HistoryFiltersNotifier extends Notifier<HistoryFilters> {
  @override
  HistoryFilters build() => const HistoryFilters();

  void setType(HistoryFilterType type) {
    state = state.copyWith(type: type);
  }

  void setDateRange(DateTime? from, DateTime? to) {
    state = state.copyWith(dateFrom: from, dateTo: to);
  }

  void setSearchQuery(String query) {
    state = state.copyWith(searchQuery: query);
  }

  void clearFilters() {
    state = const HistoryFilters();
  }
}

/// History filters provider
final historyFiltersProvider =
    NotifierProvider<HistoryFiltersNotifier, HistoryFilters>(
      HistoryFiltersNotifier.new,
    );

// ============================================================================
// FILTERED HISTORY
// ============================================================================

final filteredClientHistoryProvider =
    FutureProvider.family<List<HistoryItemData>, String>((ref, clientId) async {
      final filters = ref.watch(historyFiltersProvider);

      final appointmentsAsync = await ref.watch(
        clientAppointmentsStreamProvider(clientId).future,
      );
      final paymentsAsync = await ref.watch(
        paymentsByClientStreamProvider(clientId).future,
      );
      final items = <HistoryItemData>[];

      if (filters.type == HistoryFilterType.all ||
          filters.type == HistoryFilterType.appointments) {
        for (final appointment in appointmentsAsync) {
          if (_matchesDateFilter(
                appointment.startDateTime,
                filters.dateFrom,
                filters.dateTo,
              ) &&
              _matchesSearch(appointment.notes ?? '', filters.searchQuery)) {
            items.add(
              HistoryItemData(
                type: HistoryItemType.appointment,
                date: appointment.startDateTime,
                title: 'Appuntamento',
                subtitle: 'Cabina ${appointment.cabinId ?? '-'}',
                amount: null,
                appointmentData: appointment,
              ),
            );
          }
        }
      }

      if (filters.type == HistoryFilterType.all ||
          filters.type == HistoryFilterType.payments) {
        for (final payment in paymentsAsync) {
          if (_matchesDateFilter(
                payment.paidAt,
                filters.dateFrom,
                filters.dateTo,
              ) &&
              (_matchesSearch(payment.paymentMethod, filters.searchQuery) ||
               _matchesSearch(payment.notes ?? '', filters.searchQuery))) {
            items.add(
              HistoryItemData(
                type: HistoryItemType.payment,
                date: payment.paidAt,
                title: 'Pagamento',
                subtitle: payment.paymentMethod,
                amount: payment.amount,
                paymentData: payment,
              ),
            );
          }
        }
      }

      items.sort((a, b) => b.date.compareTo(a.date));
      return items;
    });

bool _matchesDateFilter(DateTime date, DateTime? from, DateTime? to) {
  if (from != null && date.isBefore(from)) return false;
  if (to != null &&
      date.isAfter(
        to
            .add(const Duration(days: 1))
            .subtract(const Duration(microseconds: 1)),
      ))
    return false;
  return true;
}

bool _matchesSearch(String text, String query) {
  if (query.isEmpty) return true;
  return text.toLowerCase().contains(query.toLowerCase());
}

enum HistoryItemType { appointment, payment }

@immutable
class HistoryItemData {
  final HistoryItemType type;
  final DateTime date;
  final String title;
  final String subtitle;
  final double? amount;
  final AppointmentData? appointmentData;
  final PaymentData? paymentData;

  const HistoryItemData({
    required this.type,
    required this.date,
    required this.title,
    required this.subtitle,
    this.amount,
    this.appointmentData,
    this.paymentData,
  });
}

// ============================================================================
// CHART DATA PROVIDERS
// ============================================================================

final clientMonthlySpendingProvider =
    FutureProvider.family<List<MonthlySpendingData>, String>((
      ref,
      clientId,
    ) async {
      final paymentsAsync = await ref.watch(
        paymentsByClientStreamProvider(clientId).future,
      );
      final now = DateTime.now();
      final monthlyData = <int, MonthlySpendingData>{};

      // Initialize last 12 months with zero
      for (int i = 0; i < 12; i++) {
        final date = DateTime(now.year, now.month - i, 1);
        final key = date.year * 12 + date.month;
        monthlyData[key] = MonthlySpendingData(
          year: date.year,
          month: date.month,
          monthName: _getMonthName(date.month),
          amount: 0,
          paymentCount: 0,
        );
      }

      // Aggregate payments by month
      for (final payment in paymentsAsync) {
        if (payment.amount > 0) {
          final key = payment.paidAt.year * 12 + payment.paidAt.month;
          if (monthlyData.containsKey(key)) {
            final current = monthlyData[key]!;
            monthlyData[key] = MonthlySpendingData(
              year: payment.paidAt.year,
              month: payment.paidAt.month,
              monthName: _getMonthName(payment.paidAt.month),
              amount: current.amount + payment.amount,
              paymentCount: current.paymentCount + 1,
            );
          }
        }
      }

      return monthlyData.values.toList()..sort(
        (a, b) => (a.year * 12 + a.month).compareTo(b.year * 12 + b.month),
      );
    });

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

@immutable
class MonthlySpendingData {
  final int year;
  final int month;
  final String monthName;
  final double amount;
  final int paymentCount;

  const MonthlySpendingData({
    required this.year,
    required this.month,
    required this.monthName,
    required this.amount,
    required this.paymentCount,
  });
}

final clientServiceDistributionProvider =
    FutureProvider.family<List<ServiceUsageData>, String>((
      ref,
      clientId,
    ) async {
      final services = await ref.watch(
        clientServicePreferencesProvider(clientId).future,
      );

      if (services.isEmpty) return [];

      final totalSessions = services.fold<int>(
        0,
        (sum, s) => sum + s.totalSessions,
      );

      return services.map((s) {
        final percentage = totalSessions > 0
            ? (s.totalSessions / totalSessions) * 100
            : 0.0;
        return ServiceUsageData(
          serviceName: s.serviceName,
          sessions: s.totalSessions,
          percentage: percentage,
        );
      }).toList();
    });

@immutable
class ServiceUsageData {
  final String serviceName;
  final int sessions;
  final double percentage;

  const ServiceUsageData({
    required this.serviceName,
    required this.sessions,
    required this.percentage,
  });
}

// ============================================================================
// FIDELITY TRANSACTIONS
// ============================================================================

final clientFidelityTransactionsProvider =
    FutureProvider.family<List<FidelityTransactionWithCard>, String>((
      ref,
      clientId,
    ) async {
      final cards = await ref.watch(
        fidelityCardsByClientStreamProvider(clientId).future,
      );
      final transactions = <FidelityTransactionWithCard>[];

      for (final card in cards) {
        final cardTransactions = await ref.watch(
          fidelityTransactionsStreamProvider(card.id).future,
        );
        for (final transaction in cardTransactions) {
          transactions.add(
            FidelityTransactionWithCard(
              transaction: transaction,
              cardNumber: card.cardNumber,
              cardId: card.id,
            ),
          );
        }
      }

      transactions.sort(
        (a, b) => b.transaction.createdAt.compareTo(a.transaction.createdAt),
      );
      return transactions;
    });

@immutable
class FidelityTransactionWithCard {
  final FidelityTransactionData transaction;
  final String cardNumber;
  final String cardId;

  const FidelityTransactionWithCard({
    required this.transaction,
    required this.cardNumber,
    required this.cardId,
  });
}

// ============================================================================
// CALENDAR APPOINTMENTS
// ============================================================================

final clientAppointmentsByMonthProvider =
    FutureProvider.family<Map<String, List<AppointmentData>>, String>((
      ref,
      clientId,
    ) async {
      final appointments = await ref.watch(
        clientAppointmentsStreamProvider(clientId).future,
      );
      final grouped = <String, List<AppointmentData>>{};

      for (final appointment in appointments) {
        final key =
            '${appointment.startDateTime.year}-${appointment.startDateTime.month.toString().padLeft(2, '0')}';
        grouped.putIfAbsent(key, () => []);
        grouped[key]!.add(appointment);
      }

      return grouped;
    });

final clientAppointmentsForDateProvider =
    FutureProvider.family<
      List<AppointmentData>,
      ({String clientId, DateTime date})
    >((ref, params) async {
      final appointments = await ref.watch(
        clientAppointmentsStreamProvider(params.clientId).future,
      );

      return appointments
          .where(
            (a) =>
                a.startDateTime.year == params.date.year &&
                a.startDateTime.month == params.date.month &&
                a.startDateTime.day == params.date.day,
          )
          .toList();
    });

// ============================================================================
// LIST SEARCH FILTERS
// ============================================================================

/// Simple notifier for primitive types (modern Riverpod 2.x)
class ValueNotifier<T> extends Notifier<T> {
  final T _initialValue;

  ValueNotifier(this._initialValue);

  @override
  T build() => _initialValue;

  void set(T value) => state = value;
}

/// Search query for quotes list
final quotesSearchQueryProvider =
    NotifierProvider<ValueNotifier<String>, String>(() => ValueNotifier(''));

/// Search query for packages list
final packagesSearchQueryProvider =
    NotifierProvider<ValueNotifier<String>, String>(() => ValueNotifier(''));

/// Search query for products list
final productsSearchQueryProvider =
    NotifierProvider<ValueNotifier<String>, String>(() => ValueNotifier(''));

enum PackageStatusFilter { all, active, completed, expired }

/// Package status filter
final packagesStatusFilterProvider =
    NotifierProvider<ValueNotifier<PackageStatusFilter>, PackageStatusFilter>(
      () => ValueNotifier(PackageStatusFilter.all),
    );

enum QuoteStatusFilter { all, pending, accepted, rejected }

/// Quote status filter
final quotesStatusFilterProvider =
    NotifierProvider<ValueNotifier<QuoteStatusFilter>, QuoteStatusFilter>(
      () => ValueNotifier(QuoteStatusFilter.all),
    );

// ============================================================================
// CLIENT TAGS PROVIDERS
// ============================================================================

/// Stream of client tags
final clientTagsStreamProvider =
    StreamProvider.family<List<ClientTagData>, String>((ref, clientId) {
      final repo = ref.watch(clientsRepositoryProvider);
      return repo.watchClientTags(clientId);
    });

/// All unique tags across clients (for autocomplete)
final allUniqueTagsProvider = FutureProvider<List<String>>((ref) {
  final repo = ref.watch(clientsRepositoryProvider);
  return repo.getAllUniqueTags();
});

/// Actions for client tags (add/remove)
final clientTagsActionsProvider = Provider<ClientTagsActions>(
  (ref) => ClientTagsActions(ref),
);

class ClientTagsActions {
  final Ref _ref;

  ClientTagsActions(this._ref);

  Future<String?> addTag({
    required String clientId,
    required String tag,
    String? colorHex,
  }) async {
    final repo = _ref.read(clientsRepositoryProvider);
    return repo.addClientTag(clientId: clientId, tag: tag, colorHex: colorHex);
  }

  Future<bool> removeTag(String tagId) async {
    final repo = _ref.read(clientsRepositoryProvider);
    return repo.removeClientTag(tagId);
  }
}

// ============================================================================
// CUSTOMER LIFETIME VALUE (CLV)
// ============================================================================

/// Estimated Customer Lifetime Value
final clientCLVProvider = FutureProvider.family<CLVData, String>((
  ref,
  clientId,
) async {
  final stats = await ref.watch(clientStatisticsProvider(clientId).future);
  final history = await ref.watch(
    clientMonthlySpendingProvider(clientId).future,
  );

  // Calculate average monthly spend (last 6 months with data)
  final recentMonths = history.where((m) => m.amount > 0).toList();
  final avgMonthlySpend = recentMonths.isNotEmpty
      ? recentMonths.fold<double>(0, (sum, m) => sum + m.amount) /
            recentMonths.length
      : stats.totalSpent / 12; // fallback

  // Estimate customer lifespan (based on visit frequency)
  final monthsAsCustomer = stats.firstVisitDate != null
      ? DateTime.now().difference(stats.firstVisitDate!).inDays / 30
      : 12.0;

  final visitFrequency = monthsAsCustomer > 0
      ? stats.totalAppointments / monthsAsCustomer
      : 1.0;

  // CLV = Average Monthly Spend × Estimated Lifespan (months)
  // Estimated lifespan: 24 months for regular, 12 for infrequent visitors
  double estimatedLifespanMonths;
  if (visitFrequency >= 2) {
    estimatedLifespanMonths = 36; // Frequent visitor
  } else if (visitFrequency >= 1) {
    estimatedLifespanMonths = 24; // Regular visitor
  } else {
    estimatedLifespanMonths = 12; // Infrequent visitor
  }

  final clv = avgMonthlySpend * estimatedLifespanMonths;

  // Risk assessment
  String riskLevel;
  Color riskColor;
  if (stats.daysSinceLastVisit != null) {
    if (stats.daysSinceLastVisit! > 90) {
      riskLevel = 'Alto rischio abbandono';
      riskColor = Colors.red;
    } else if (stats.daysSinceLastVisit! > 60) {
      riskLevel = 'Rischio medio';
      riskColor = Colors.orange;
    } else {
      riskLevel = 'Attivo';
      riskColor = Colors.green;
    }
  } else {
    riskLevel = 'Nuovo cliente';
    riskColor = Colors.blue;
  }

  return CLVData(
    estimatedValue: clv,
    averageMonthlySpend: avgMonthlySpend,
    estimatedLifespanMonths: estimatedLifespanMonths.toInt(),
    visitFrequency: visitFrequency,
    riskLevel: riskLevel,
    riskColor: riskColor,
  );
});

@immutable
class CLVData {
  final double estimatedValue;
  final double averageMonthlySpend;
  final int estimatedLifespanMonths;
  final double visitFrequency;
  final String riskLevel;
  final Color riskColor;

  const CLVData({
    required this.estimatedValue,
    required this.averageMonthlySpend,
    required this.estimatedLifespanMonths,
    required this.visitFrequency,
    required this.riskLevel,
    required this.riskColor,
  });
}

// ============================================================================
// ML RECOMMENDATIONS (Lightweight Rule-Based)
// ============================================================================

/// Service recommendations based on client history
final clientServiceRecommendationsProvider =
    FutureProvider.family<List<ServiceRecommendation>, String>((
      ref,
      clientId,
    ) async {
      final preferences = await ref.watch(
        clientServicePreferencesProvider(clientId).future,
      );
      final stats = await ref.watch(clientStatisticsProvider(clientId).future);
      final allServices = await ref.watch(servicesStreamProvider.future);

      final recommendations = <ServiceRecommendation>[];

      // Rule 1: Suggest completing partially used services
      for (final pref in preferences.where((p) => p.remainingSessions > 0)) {
        recommendations.add(
          ServiceRecommendation(
            serviceName: pref.serviceName,
            confidence: 0.9,
            reason: 'Hai ${pref.remainingSessions} sedute rimanenti',
            action: 'Prenota',
          ),
        );
      }

      // Rule 2: Suggest complementary services (cross-sell)
      final usedServiceIds = preferences.map((p) => p.serviceId).toSet();
      for (final service in allServices) {
        if (!usedServiceIds.contains(service.id)) {
          // Simple cross-sell logic based on service names
          double confidence = 0.3;
          String reason = 'Potrebbe interessarti';

          final serviceName = service.name.toLowerCase();
          if (preferences.any(
            (p) =>
                p.serviceName.toLowerCase().contains('viso') &&
                serviceName.contains('corpo'),
          )) {
            confidence = 0.6;
            reason = 'Complementare ai trattamenti viso già effettuati';
          } else if (preferences.any(
            (p) =>
                p.serviceName.toLowerCase().contains('massaggio') &&
                serviceName.contains('massaggio'),
          )) {
            confidence = 0.5;
            reason = 'Variante del massaggio che ti piace';
          }

          if (confidence > 0.3) {
            recommendations.add(
              ServiceRecommendation(
                serviceId: service.id,
                serviceName: service.name,
                confidence: confidence,
                reason: reason,
                action: 'Scopri',
              ),
            );
          }
        }
      }

      // Rule 3: Reactivation suggestions for inactive clients
      if (stats.daysSinceLastVisit != null && stats.daysSinceLastVisit! > 60) {
        if (preferences.isNotEmpty) {
          final lastService = preferences.first;
          recommendations.insert(
            0,
            ServiceRecommendation(
              serviceName: lastService.serviceName,
              confidence: 0.95,
              reason:
                  'Ti manchiamo! Ultimo trattamento: ${lastService.serviceName}',
              action: 'Prenota ora',
              isUrgent: true,
            ),
          );
        }
      }

      // Sort by confidence
      recommendations.sort((a, b) => b.confidence.compareTo(a.confidence));
      return recommendations.take(5).toList();
    });

@immutable
class ServiceRecommendation {
  final String? serviceId;
  final String serviceName;
  final double confidence; // 0.0 - 1.0
  final String reason;
  final String action;
  final bool isUrgent;

  const ServiceRecommendation({
    this.serviceId,
    required this.serviceName,
    required this.confidence,
    required this.reason,
    required this.action,
    this.isUrgent = false,
  });

  String get confidenceLabel {
    if (confidence >= 0.8) return 'Consigliato';
    if (confidence >= 0.5) return 'Potrebbe interessarti';
    return 'Scopri';
  }

  Color get confidenceColor {
    if (confidence >= 0.8) return Colors.green;
    if (confidence >= 0.5) return Colors.orange;
    return Colors.blue;
  }
}

// ============================================================================
// CLIENT PRODUCT BLACKLIST
// ============================================================================

/// Stream of client's blacklisted products
final clientProductBlacklistStreamProvider =
    StreamProvider.family<List<ClientProductBlacklistData>, String>((
      ref,
      clientId,
    ) {
      final repo = ref.watch(clientsRepositoryProvider);
      return repo.watchClientProductBlacklist(clientId);
    });

/// Actions for product blacklist
final clientProductBlacklistActionsProvider =
    Provider<ClientProductBlacklistActions>(
      (ref) => ClientProductBlacklistActions(ref),
    );

class ClientProductBlacklistActions {
  final Ref _ref;

  ClientProductBlacklistActions(this._ref);

  Future<String?> addToBlacklist({
    required String clientId,
    required String productId,
    String? reason,
  }) async {
    final repo = _ref.read(clientsRepositoryProvider);
    return repo.addProductToBlacklist(
      clientId: clientId,
      productId: productId,
      reason: reason,
    );
  }

  Future<bool> removeFromBlacklist(String blacklistId) async {
    final repo = _ref.read(clientsRepositoryProvider);
    return repo.removeProductFromBlacklist(blacklistId);
  }

  Future<bool> isBlacklisted({
    required String clientId,
    required String productId,
  }) async {
    final repo = _ref.read(clientsRepositoryProvider);
    return repo.isProductBlacklisted(clientId: clientId, productId: productId);
  }
}

// ============================================================================
// PDF EXPORT
// ============================================================================

/// Export client summary to PDF
final clientPdfExportProvider = Provider<ClientPdfExporter>(
  (ref) => ClientPdfExporter(ref),
);

class ClientPdfExporter {
  final Ref _ref;

  ClientPdfExporter(this._ref);

  Future<String?> exportClientSummary({
    required String clientId,
    required String clientName,
  }) async {
    try {
      final repo = _ref.read(clientsRepositoryProvider);
      final productsRepo = _ref.read(productsRepositoryProvider);

      // Fetch all data
      final client = await repo.getClientById(clientId);
      final tags = await repo.getClientTags(clientId);
      final blacklist = await repo.getClientProductBlacklist(clientId);
      final statsAsync = await _ref.read(
        clientStatisticsProvider(clientId).future,
      );
      final clvAsync = await _ref.read(clientCLVProvider(clientId).future);

      // Get product names for blacklist
      final blacklistWithNames = <Map<String, dynamic>>[];
      for (final item in blacklist) {
        final product = await productsRepo.getProductById(item.productId);
        blacklistWithNames.add({
          'name': product?.name ?? 'Prodotto sconosciuto',
          'reason': item.reason ?? 'Nessuna motivazione',
        });
      }

      // Create PDF document
      final document = PdfDocument();
      final page = document.pages.add();
      var graphics = page.graphics;
      final bounds = page.getClientSize();

      // Title
      final titleFont = PdfStandardFont(
        PdfFontFamily.helvetica,
        24,
        style: PdfFontStyle.bold,
      );
      graphics.drawString(
        'Scheda Cliente',
        titleFont,
        bounds: Rect.fromLTWH(0, 0, bounds.width, 40),
        format: PdfStringFormat(alignment: PdfTextAlignment.center),
      );

      // Client name
      final nameFont = PdfStandardFont(
        PdfFontFamily.helvetica,
        18,
        style: PdfFontStyle.bold,
      );
      graphics.drawString(
        '${client?.firstName} ${client?.lastName}',
        nameFont,
        bounds: Rect.fromLTWH(0, 50, bounds.width, 30),
        format: PdfStringFormat(alignment: PdfTextAlignment.center),
      );

      // Content
      var y = 100.0;
      final contentFont = PdfStandardFont(PdfFontFamily.helvetica, 12);
      final labelFont = PdfStandardFont(
        PdfFontFamily.helvetica,
        12,
        style: PdfFontStyle.bold,
      );

      // Helper to draw section
      void drawSection(String label, String value) {
        graphics.drawString(
          '$label:',
          labelFont,
          bounds: Rect.fromLTWH(20, y, 150, 20),
        );
        graphics.drawString(
          value,
          contentFont,
          bounds: Rect.fromLTWH(170, y, bounds.width - 190, 20),
        );
        y += 25;
      }

      // Contact info
      graphics.drawString(
        'CONTATTI',
        labelFont,
        bounds: Rect.fromLTWH(20, y, 200, 20),
      );
      y += 30;
      drawSection('Telefono', client?.phoneNumber ?? '-');
      drawSection('Email', client?.email ?? '-');
      drawSection('Indirizzo', client?.address ?? '-');
      drawSection(
        'Data nascita',
        client?.birthDate != null
            ? DateFormat('dd/MM/yyyy').format(client!.birthDate!)
            : '-',
      );
      drawSection(
        'Cliente dal',
        DateFormat('dd/MM/yyyy').format(client!.createdAt),
      );

      y += 20;
      graphics.drawString(
        'STATISTICHE',
        labelFont,
        bounds: Rect.fromLTWH(20, y, 200, 20),
      );
      y += 30;
      drawSection(
        'Totale speso',
        '€${statsAsync.totalSpent.toStringAsFixed(2)}',
      );
      drawSection('Pacchetti attivi', '${statsAsync.activePackages}');
      drawSection('Visite totali', '${statsAsync.totalAppointments}');
      drawSection(
        'Saldo Fidelity',
        '€${statsAsync.totalFidelityBalance.toStringAsFixed(2)}',
      );

      y += 20;
      graphics.drawString(
        'VALORE STIMATO (CLV)',
        labelFont,
        bounds: Rect.fromLTWH(20, y, 200, 20),
      );
      y += 30;
      drawSection(
        'Valore Lifetime',
        '€${clvAsync.estimatedValue.toStringAsFixed(2)}',
      );
      drawSection(
        'Spesa mensile media',
        '€${clvAsync.averageMonthlySpend.toStringAsFixed(2)}',
      );
      drawSection(
        'Frequenza visite',
        '${clvAsync.visitFrequency.toStringAsFixed(1)}/mese',
      );

      // Tags
      if (tags.isNotEmpty) {
        y += 20;
        graphics.drawString(
          'TAG',
          labelFont,
          bounds: Rect.fromLTWH(20, y, 200, 20),
        );
        y += 30;
        graphics.drawString(
          tags.map((t) => t.tag).join(', '),
          contentFont,
          bounds: Rect.fromLTWH(20, y, bounds.width - 40, 40),
        );
        y += 40;
      }

      // Notes
      if (client.notes != null && client.notes!.isNotEmpty) {
        y += 20;
        graphics.drawString(
          'NOTE',
          labelFont,
          bounds: Rect.fromLTWH(20, y, 200, 20),
        );
        y += 30;
        graphics.drawString(
          client.notes!,
          contentFont,
          bounds: Rect.fromLTWH(20, y, bounds.width - 40, 100),
        );
      }

      // Blacklist
      if (blacklistWithNames.isNotEmpty) {
        y += 20;
        graphics.drawString(
          'PRODOTTI DA NON PROPORRE',
          labelFont,
          bounds: Rect.fromLTWH(20, y, 300, 20),
        );
        y += 30;
        for (final item in blacklistWithNames) {
          graphics.drawString(
            '• ${item['name']} (${item['reason']})',
            contentFont,
            bounds: Rect.fromLTWH(20, y, bounds.width - 40, 20),
          );
          y += 25;
        }
      }

      // Footer
      final footerFont = PdfStandardFont(PdfFontFamily.helvetica, 10);
      graphics.drawString(
        'Generato il ${DateFormat('dd/MM/yyyy HH:mm').format(DateTime.now())}',
        footerFont,
        bounds: Rect.fromLTWH(0, bounds.height - 30, bounds.width, 20),
        format: PdfStringFormat(alignment: PdfTextAlignment.center),
      );

      // Save to temporary directory for sharing
      final tempDir = await getTemporaryDirectory();
      final timestamp = DateFormat('yyyyMMdd_HHmmss').format(DateTime.now());
      final sanitizedFirstName = client.firstName.replaceAll(
        RegExp(r'[^a-zA-Z0-9]'),
        '_',
      );
      final sanitizedLastName = client.lastName.replaceAll(
        RegExp(r'[^a-zA-Z0-9]'),
        '_',
      );
      final fileName =
          'scheda_cliente_${sanitizedFirstName}_${sanitizedLastName}_$timestamp.pdf';
      final filePath = join(tempDir.path, fileName);

      final file = File(filePath);
      final bytes = await document.save();
      await file.writeAsBytes(bytes);
      document.dispose();

      // Share the PDF file
      final xFile = XFile(filePath, mimeType: 'application/pdf');
      await Share.shareXFiles(
        [xFile],
        subject: 'Scheda Cliente - ${client.firstName} ${client.lastName}',
        text:
            'Ecco la scheda riepilogativa di ${client.firstName} ${client.lastName}',
      );

      return filePath;
    } catch (e, stackTrace) {
      AppLogger.getLogger(
        name: 'ClientPdfExporter',
      ).warning('Failed to export PDF', e, stackTrace);
      return null;
    }
  }

  /// Export technical sheet to PDF (medical/aesthetic record)
  Future<String?> exportTechnicalSheetPdf({
    required String clientId,
    required String clientName,
  }) async {
    try {
      final repo = _ref.read(clientsRepositoryProvider);
      final timelineAsync = await _ref.read(
        clientTreatmentTimelineProvider(clientId).future,
      );

      // Fetch all data
      final client = await repo.getClientById(clientId);
      final technicalSheet = await repo.getOrCreateTechnicalSheet(clientId);
      final tags = await repo.getClientTags(clientId);

      // Create PDF document
      final document = PdfDocument();
      final page = document.pages.add();
      var graphics = page.graphics;
      final bounds = page.getClientSize();

      // Title - Medical Header
      final titleFont = PdfStandardFont(
        PdfFontFamily.helvetica,
        20,
        style: PdfFontStyle.bold,
      );
      graphics.drawString(
        'SCHEDA TECNICA MEDICA',
        titleFont,
        bounds: Rect.fromLTWH(0, 0, bounds.width, 40),
        format: PdfStringFormat(alignment: PdfTextAlignment.center),
      );

      // Confidential watermark
      final watermarkFont = PdfStandardFont(PdfFontFamily.helvetica, 60);
      final watermarkBrush = PdfSolidBrush(PdfColor(200, 200, 200, 50));
      graphics.drawString(
        'CONFIDENZIALE',
        watermarkFont,
        bounds: Rect.fromLTWH(0, bounds.height / 2 - 50, bounds.width, 100),
        format: PdfStringFormat(alignment: PdfTextAlignment.center),
        brush: watermarkBrush,
      );

      // Client name
      final nameFont = PdfStandardFont(
        PdfFontFamily.helvetica,
        16,
        style: PdfFontStyle.bold,
      );
      graphics.drawString(
        '${client?.firstName} ${client?.lastName}',
        nameFont,
        bounds: Rect.fromLTWH(0, 50, bounds.width, 30),
        format: PdfStringFormat(alignment: PdfTextAlignment.center),
      );

      // Content
      var y = 100.0;
      final contentFont = PdfStandardFont(PdfFontFamily.helvetica, 11);
      final labelFont = PdfStandardFont(
        PdfFontFamily.helvetica,
        11,
        style: PdfFontStyle.bold,
      );
      final sectionFont = PdfStandardFont(
        PdfFontFamily.helvetica,
        13,
        style: PdfFontStyle.bold,
      );

      // Helper to draw section
      void drawSection(String label, String value) {
        graphics.drawString(
          '$label:',
          labelFont,
          bounds: Rect.fromLTWH(20, y, 150, 20),
        );
        graphics.drawString(
          value.isNotEmpty ? value : '-',
          contentFont,
          bounds: Rect.fromLTWH(170, y, bounds.width - 190, 20),
        );
        y += 22;
      }

      void drawMultiLine(String label, String? value) {
        if (y > bounds.height - 100) {
          // Add new page if needed
          final newPage = document.pages.add();
          graphics = newPage.graphics;
          y = 20;
        }
        graphics.drawString(
          '$label:',
          labelFont,
          bounds: Rect.fromLTWH(20, y, 150, 20),
        );
        y += 20;
        final text = value?.isNotEmpty == true ? value! : '-';
        final lines = _wrapText(text, contentFont, bounds.width - 190);
        for (final line in lines) {
          graphics.drawString(
            line,
            contentFont,
            bounds: Rect.fromLTWH(30, y, bounds.width - 190, 20),
          );
          y += 18;
        }
        y += 5;
      }

      // === SKIN INFORMATION ===
      graphics.drawString(
        'INFORMAZIONI PELLE',
        sectionFont,
        bounds: Rect.fromLTWH(20, y, 200, 20),
      );
      y += 28;

      drawSection('Tipo pelle', technicalSheet.skinType ?? '');
      drawSection(
        'Fitzpatrick',
        technicalSheet.fitzpatrickType != null
            ? 'Tipo ${technicalSheet.fitzpatrickType}'
            : '',
      );
      y += 5;

      drawMultiLine('Condizioni', technicalSheet.skinConditions);

      // === TAGS ===
      y += 10;
      graphics.drawString(
        'TAG',
        sectionFont,
        bounds: Rect.fromLTWH(20, y, 200, 20),
      );
      y += 28;

      if (tags.isEmpty) {
        drawSection('Nessun tag', '');
      } else {
        drawSection('Assegnati', tags.map((t) => t.tag).join(', '));
      }
      y += 5;

      // === MEDICAL FLAGS ===
      y += 10;
      graphics.drawString(
        'FLAG MEDICI',
        sectionFont,
        bounds: Rect.fromLTWH(20, y, 200, 20),
      );
      y += 28;

      final flags = <String>[];
      if (technicalSheet.isPregnant) flags.add('Gravidanza');
      if (technicalSheet.isBreastfeeding) flags.add('Allattamento');
      if (technicalSheet.hasSunSensitivity) flags.add('Fotosensibilità');
      if (technicalSheet.hasHerpesHistory) flags.add('Storia Herpes');
      if (technicalSheet.hasKeloidTendency) flags.add('Tendenza Cheloidi');
      if (technicalSheet.hasDiabetes) flags.add('Diabete');
      if (technicalSheet.hasPacemaker) flags.add('Pacemaker');

      if (flags.isEmpty) {
        drawSection('Nessun flag', '');
      } else {
        drawSection('Attivi', flags.join(', '));
      }
      y += 5;

      // === ALLERGIES & CONTRAINDICATIONS ===
      y += 10;
      graphics.drawString(
        'ALLERGIE E CONTROINDICAZIONI',
        sectionFont,
        bounds: Rect.fromLTWH(20, y, 300, 20),
      );
      y += 28;

      drawMultiLine('Allergie', technicalSheet.allergies);
      drawMultiLine('Controindicazioni', technicalSheet.contraindications);
      drawMultiLine('Farmaci in corso', technicalSheet.currentMedications);

      // === TREATMENT HISTORY ===
      y += 10;
      if (y > bounds.height - 150) {
        final newPage = document.pages.add();
        graphics = newPage.graphics;
        y = 20;
      }
      graphics.drawString(
        'STORIA TRATTAMENTI',
        sectionFont,
        bounds: Rect.fromLTWH(20, y, 200, 20),
      );
      y += 28;

      drawMultiLine(
        'Trattamenti precedenti',
        technicalSheet.previousTreatments,
      );
      drawMultiLine('Impostazioni macchinari', technicalSheet.machineSettings);

      // === TREATMENT TIMELINE ===
      y += 10;
      if (y > bounds.height - 150) {
        final newPage = document.pages.add();
        graphics = newPage.graphics;
        y = 20;
      }
      graphics.drawString(
        'CRONOLOGIA TRATTAMENTI',
        sectionFont,
        bounds: Rect.fromLTWH(20, y, 200, 20),
      );
      y += 28;

      if (timelineAsync.isEmpty) {
        graphics.drawString(
          'Nessun trattamento registrato',
          contentFont,
          bounds: Rect.fromLTWH(20, y, bounds.width - 40, 20),
        );
        y += 25;
      } else {
        for (final entry in timelineAsync.take(10)) {
          if (y > bounds.height - 80) {
            final newPage = document.pages.add();
            graphics = newPage.graphics;
            y = 20;
          }

          final dateStr = DateFormat('dd/MM/yyyy').format(entry.date);
          graphics.drawString(
            dateStr,
            labelFont,
            bounds: Rect.fromLTWH(20, y, 80, 20),
          );
          graphics.drawString(
            entry.serviceNames.join(', '),
            contentFont,
            bounds: Rect.fromLTWH(100, y, bounds.width - 120, 20),
          );
          y += 18;

          if (entry.operatorNotes?.isNotEmpty == true) {
            graphics.drawString(
              'Note: ${entry.operatorNotes}',
              contentFont,
              bounds: Rect.fromLTWH(30, y, bounds.width - 50, 20),
            );
            y += 18;
          }

          if (entry.skinReaction?.isNotEmpty == true) {
            graphics.drawString(
              'Reazione: ${entry.skinReaction}',
              contentFont,
              bounds: Rect.fromLTWH(30, y, bounds.width - 50, 20),
            );
            y += 18;
          }
          y += 5;
        }
      }

      // === NOTES ===
      y += 10;
      if (y > bounds.height - 100) {
        final newPage = document.pages.add();
        graphics = newPage.graphics;
        y = 20;
      }
      graphics.drawString(
        'NOTE MEDICHE',
        sectionFont,
        bounds: Rect.fromLTWH(20, y, 200, 20),
      );
      y += 28;
      drawMultiLine('Note', technicalSheet.medicalNotes);

      // Footer
      final footerFont = PdfStandardFont(PdfFontFamily.helvetica, 9);
      graphics.drawString(
        'Documento medico confidenziale - Generato il ${DateFormat('dd/MM/yyyy HH:mm').format(DateTime.now())}',
        footerFont,
        bounds: Rect.fromLTWH(0, bounds.height - 30, bounds.width, 20),
        format: PdfStringFormat(alignment: PdfTextAlignment.center),
      );

      // Save to temporary directory
      final tempDir = await getTemporaryDirectory();
      final timestamp = DateFormat('yyyyMMdd_HHmmss').format(DateTime.now());
      final sanitizedFirstName = client!.firstName.replaceAll(
        RegExp(r'[^a-zA-Z0-9]'),
        '_',
      );
      final sanitizedLastName = client.lastName.replaceAll(
        RegExp(r'[^a-zA-Z0-9]'),
        '_',
      );
      final fileName =
          'scheda_tecnica_${sanitizedFirstName}_${sanitizedLastName}_$timestamp.pdf';
      final filePath = join(tempDir.path, fileName);

      final file = File(filePath);
      final bytes = await document.save();
      await file.writeAsBytes(bytes);
      document.dispose();

      // Share the PDF file
      final xFile = XFile(filePath, mimeType: 'application/pdf');
      await Share.shareXFiles(
        [xFile],
        subject:
            'Scheda Tecnica Medica - ${client.firstName} ${client.lastName}',
        text: 'Scheda tecnica medica di ${client.firstName} ${client.lastName}',
      );

      return filePath;
    } catch (e, stackTrace) {
      AppLogger.getLogger(
        name: 'ClientPdfExporter',
      ).warning('Failed to export technical sheet PDF', e, stackTrace);
      return null;
    }
  }

  List<String> _wrapText(String text, PdfFont font, double maxWidth) {
    final words = text.split(' ');
    final lines = <String>[];
    var currentLine = '';

    for (final word in words) {
      final testLine = currentLine.isEmpty ? word : '$currentLine $word';
      final size = font.measureString(testLine);
      if (size.width > maxWidth && currentLine.isNotEmpty) {
        lines.add(currentLine);
        currentLine = word;
      } else {
        currentLine = testLine;
      }
    }
    if (currentLine.isNotEmpty) {
      lines.add(currentLine);
    }
    return lines.isEmpty ? [text] : lines;
  }
}
