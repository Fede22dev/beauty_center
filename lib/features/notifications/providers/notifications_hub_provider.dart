import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

import '../../../core/database/app_database.dart';
import '../../clients/providers/clients_providers.dart';

part 'notifications_hub_provider.g.dart';

/// Types of notifications in the hub
enum NotificationType {
  birthday,
  packageExpiring,
  appointmentReminder,
  lowFidelityBalance,
  clientInactive,
  pendingSync,
}

/// Priority levels for notifications
enum NotificationPriority {
  low,
  normal,
  high,
  urgent,
}

/// A notification item in the hub
class HubNotification {
  final String id;
  final NotificationType type;
  final NotificationPriority priority;
  final String title;
  final String message;
  final String? clientId;
  final String? clientName;
  final DateTime createdAt;
  final DateTime? actionDeadline;
  final Map<String, dynamic>? metadata;
  bool isRead;

  HubNotification({
    required this.id,
    required this.type,
    required this.priority,
    required this.title,
    required this.message,
    this.clientId,
    this.clientName,
    required this.createdAt,
    this.actionDeadline,
    this.metadata,
    this.isRead = false,
  });

  String get icon => switch (type) {
        NotificationType.birthday => '🎂',
        NotificationType.packageExpiring => '⏰',
        NotificationType.appointmentReminder => '📅',
        NotificationType.lowFidelityBalance => '💳',
        NotificationType.clientInactive => '💤',
        NotificationType.pendingSync => '☁️',
      };

  String get typeLabel => switch (type) {
        NotificationType.birthday => 'Compleanno',
        NotificationType.packageExpiring => 'Scadenza',
        NotificationType.appointmentReminder => 'Appuntamento',
        NotificationType.lowFidelityBalance => 'Fidelity',
        NotificationType.clientInactive => 'Cliente',
        NotificationType.pendingSync => 'Sync',
      };

  bool get isUrgent => priority == NotificationPriority.urgent;
  bool get isActionRequired => actionDeadline != null;

  String get timeAgo {
    final now = DateTime.now();
    final diff = now.difference(createdAt);

    if (diff.inMinutes < 1) return 'Adesso';
    if (diff.inHours < 1) return '${diff.inMinutes}m fa';
    if (diff.inDays < 1) return '${diff.inHours}h fa';
    if (diff.inDays < 7) return '${diff.inDays}g fa';
    return '${createdAt.day}/${createdAt.month}';
  }
}

/// Notifications Hub State
class NotificationsHubState {
  final List<HubNotification> notifications;
  final bool isLoading;
  final String? error;
  final DateTime lastUpdated;

  const NotificationsHubState({
    this.notifications = const [],
    this.isLoading = false,
    this.error,
    required this.lastUpdated,
  });

  NotificationsHubState copyWith({
    List<HubNotification>? notifications,
    bool? isLoading,
    String? error,
    DateTime? lastUpdated,
  }) {
    return NotificationsHubState(
      notifications: notifications ?? this.notifications,
      isLoading: isLoading ?? this.isLoading,
      error: error ?? this.error,
      lastUpdated: lastUpdated ?? this.lastUpdated,
    );
  }

  // Getters for filtering
  List<HubNotification> get unreadNotifications =>
      notifications.where((n) => !n.isRead).toList();

  List<HubNotification> get urgentNotifications =>
      notifications.where((n) => n.isUrgent).toList();

  List<HubNotification> get todayBirthdays => notifications
      .where((n) =>
          n.type == NotificationType.birthday &&
          n.createdAt.day == DateTime.now().day)
      .toList();

  List<HubNotification> get byTypeBirthday =>
      notifications.where((n) => n.type == NotificationType.birthday).toList();

  int get unreadCount => unreadNotifications.length;
  int get urgentCount => urgentNotifications.length;
}

/// Main notifier for the Notifications Hub
@riverpod
class NotificationsHub extends _$NotificationsHub {
  @override
  NotificationsHubState build() {
    // Watch clients stream to auto-refresh notifications
    ref.watch(clientsStreamProvider);

    // Initialize with empty state and load
    final initialState = NotificationsHubState(
      lastUpdated: DateTime.now(),
    );

    // Schedule loading after build
    Future.microtask(() => loadNotifications());

    return initialState;
  }

  Future<void> loadNotifications() async {
    state = state.copyWith(isLoading: true, error: null);

    try {
      final clients = await ref.read(clientsActionsProvider).getAllClients();
      final now = DateTime.now();

      final notifications = <HubNotification>[];

      // Generate birthday notifications
      notifications.addAll(_generateBirthdayNotifications(clients, now));

      // Sort by priority and date
      notifications.sort((a, b) {
        final priorityOrder = {
          NotificationPriority.urgent: 0,
          NotificationPriority.high: 1,
          NotificationPriority.normal: 2,
          NotificationPriority.low: 3,
        };

        final priorityCompare = (priorityOrder[a.priority] ?? 99)
            .compareTo(priorityOrder[b.priority] ?? 99);
        if (priorityCompare != 0) return priorityCompare;

        return b.createdAt.compareTo(a.createdAt);
      });

      state = state.copyWith(
        notifications: notifications,
        isLoading: false,
        lastUpdated: DateTime.now(),
      );
    } catch (e) {
      state = state.copyWith(
        isLoading: false,
        error: 'Errore caricamento notifiche: $e',
      );
    }
  }

  List<HubNotification> _generateBirthdayNotifications(
    List<Client> clients,
    DateTime now,
  ) {
    final notifications = <HubNotification>[];

    for (final client in clients) {
      if (client.birthDate == null) continue;

      final birthDate = client.birthDate!;

      // Check if birthday is today
      if (birthDate.month == now.month && birthDate.day == now.day) {
        final age = now.year - birthDate.year;

        notifications.add(
          HubNotification(
            id: 'birthday_${client.id}_${now.year}',
            type: NotificationType.birthday,
            priority: NotificationPriority.normal,
            title: '🎂 Buon Compleanno ${client.firstName}!',
            message: 'Oggi ${client.firstName} ${client.lastName} '
                'compie ${age > 0 ? age : 1} anni. '
                'Invia un messaggio di auguri!',
            clientId: client.id,
            clientName: '${client.firstName} ${client.lastName}',
            createdAt: now,
            metadata: {
              'age': age,
              'phoneNumber': client.phoneNumber,
            },
          ),
        );
      }

      // Birthday coming in next 7 days
      final nextBirthday = DateTime(
        now.year,
        birthDate.month,
        birthDate.day,
      );

      // If birthday already passed this year, check next year
      var targetBirthday = nextBirthday;
      if (nextBirthday.isBefore(now)) {
        targetBirthday = DateTime(now.year + 1, birthDate.month, birthDate.day);
      }

      final daysUntil = targetBirthday.difference(now).inDays;

      if (daysUntil > 0 && daysUntil <= 7) {
        final age = targetBirthday.year - birthDate.year;

        notifications.add(
          HubNotification(
            id: 'birthday_upcoming_${client.id}_$daysUntil',
            type: NotificationType.birthday,
            priority: daysUntil <= 3
                ? NotificationPriority.high
                : NotificationPriority.normal,
            title: '🎂 Compleanno tra $daysUntil ${daysUntil == 1 ? 'giorno' : 'giorni'}',
            message:
                '${client.firstName} ${client.lastName} compierà $age anni '
                'il ${targetBirthday.day}/${targetBirthday.month}. '
                'Preparati per gli auguri!',
            clientId: client.id,
            clientName: '${client.firstName} ${client.lastName}',
            createdAt: now,
            actionDeadline: targetBirthday,
            metadata: {
              'age': age,
              'daysUntil': daysUntil,
              'phoneNumber': client.phoneNumber,
            },
          ),
        );
      }
    }

    return notifications;
  }

  void markAsRead(String notificationId) {
    final updatedNotifications = state.notifications.map((n) {
      if (n.id == notificationId) {
        return HubNotification(
          id: n.id,
          type: n.type,
          priority: n.priority,
          title: n.title,
          message: n.message,
          clientId: n.clientId,
          clientName: n.clientName,
          createdAt: n.createdAt,
          actionDeadline: n.actionDeadline,
          metadata: n.metadata,
          isRead: true,
        );
      }
      return n;
    }).toList();

    state = state.copyWith(notifications: updatedNotifications);
  }

  void markAllAsRead() {
    final updatedNotifications = state.notifications.map((n) {
      return HubNotification(
        id: n.id,
        type: n.type,
        priority: n.priority,
        title: n.title,
        message: n.message,
        clientId: n.clientId,
        clientName: n.clientName,
        createdAt: n.createdAt,
        actionDeadline: n.actionDeadline,
        metadata: n.metadata,
        isRead: true,
      );
    }).toList();

    state = state.copyWith(notifications: updatedNotifications);
  }

  void dismissNotification(String notificationId) {
    state = state.copyWith(
      notifications:
          state.notifications.where((n) => n.id != notificationId).toList(),
    );
  }

  void refresh() => loadNotifications();
}

/// Provider for today's birthday notifications only
@riverpod
List<HubNotification> todaysBirthdays(Ref ref) {
  final hub = ref.watch(notificationsHubProvider);
  final now = DateTime.now();

  return hub.notifications.where((n) {
    return n.type == NotificationType.birthday &&
        n.createdAt.day == now.day &&
        n.createdAt.month == now.month;
  }).toList();
}

/// Provider for upcoming birthday notifications
@riverpod
List<HubNotification> upcomingBirthdays(Ref ref) {
  final hub = ref.watch(notificationsHubProvider);

  return hub.notifications.where((n) {
    return n.type == NotificationType.birthday &&
        (n.actionDeadline?.isAfter(DateTime.now()) ?? false);
  }).toList();
}

/// Provider for unread count badge
@riverpod
int unreadNotificationsCount(Ref ref) {
  final hub = ref.watch(notificationsHubProvider);
  return hub.unreadCount;
}
