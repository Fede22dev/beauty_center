import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:material_symbols_icons/symbols.dart';

import '../../../../core/constants/app_constants.dart';
import '../../../../core/tabs/app_tabs.dart';
import '../../providers/notifications_hub_provider.dart';

/// Main widget for the Notifications Hub
/// Displays notifications with priority on birthdays
class NotificationsHubWidget extends ConsumerWidget {
  const NotificationsHubWidget({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final hub = ref.watch(notificationsHubProvider);
    final colorScheme = Theme.of(context).colorScheme;

    if (hub.isLoading) {
      return _buildLoadingState(colorScheme);
    }

    if (hub.error != null) {
      return _buildErrorState(colorScheme, hub.error!, ref);
    }

    if (hub.notifications.isEmpty) {
      return _buildEmptyState(colorScheme);
    }

    return _buildNotificationsList(hub, colorScheme, ref);
  }

  Widget _buildLoadingState(ColorScheme colorScheme) {
    return Card(
      child: Container(
        padding: EdgeInsets.all(kIsWindows ? 24 : 24.sp),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            CircularProgressIndicator(color: colorScheme.primary),
            SizedBox(height: kIsWindows ? 16 : 16.h),
            Text(
              'Caricamento notifiche...',
              style: TextStyle(color: colorScheme.onSurfaceVariant),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildErrorState(
    ColorScheme colorScheme,
    String error,
    WidgetRef ref,
  ) {
    return Card(
      child: Container(
        padding: EdgeInsets.all(kIsWindows ? 24 : 24.sp),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Symbols.error_rounded,
              color: colorScheme.error,
              size: kIsWindows ? 48 : 48.sp,
            ),
            SizedBox(height: kIsWindows ? 16 : 16.h),
            Text(
              error,
              style: TextStyle(color: colorScheme.error),
              textAlign: TextAlign.center,
            ),
            SizedBox(height: kIsWindows ? 16 : 16.h),
            FilledButton.tonal(
              onPressed: () =>
                  ref.read(notificationsHubProvider.notifier).refresh(),
              child: const Text('Riprova'),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildEmptyState(ColorScheme colorScheme) {
    return Card(
      child: Container(
        padding: EdgeInsets.all(kIsWindows ? 32 : 32.sp),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Symbols.notifications_off_rounded,
              color: colorScheme.outline,
              size: kIsWindows ? 64 : 64.sp,
            ),
            SizedBox(height: kIsWindows ? 16 : 16.h),
            Text(
              'Nessuna notifica',
              style: TextStyle(
                fontSize: kIsWindows ? 18 : 18.sp,
                fontWeight: FontWeight.bold,
                color: colorScheme.onSurface,
              ),
            ),
            SizedBox(height: kIsWindows ? 8 : 8.h),
            Text(
              'Tutto è aggiornato! Non ci sono compleanni o scadenze imminenti.',
              style: TextStyle(color: colorScheme.onSurfaceVariant),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildNotificationsList(
    NotificationsHubState hub,
    ColorScheme colorScheme,
    WidgetRef ref,
  ) {
    // Separate birthdays from other notifications
    final birthdays = hub.notifications
        .where((n) => n.type == NotificationType.birthday)
        .toList();
    final otherNotifications = hub.notifications
        .where((n) => n.type != NotificationType.birthday)
        .toList();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Birthdays Section (if any)
        if (birthdays.isNotEmpty) ...[
          _BirthdaysSection(birthdays: birthdays),
          SizedBox(height: kIsWindows ? 16 : 16.h),
        ],

        // Other Notifications Section
        if (otherNotifications.isNotEmpty) ...[
          _OtherNotificationsSection(
            notifications: otherNotifications,
            onMarkAllRead: () =>
                ref.read(notificationsHubProvider.notifier).markAllAsRead(),
          ),
        ],
      ],
    );
  }
}

/// Birthdays Section Widget
class _BirthdaysSection extends StatelessWidget {
  final List<HubNotification> birthdays;

  const _BirthdaysSection({required this.birthdays});

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final today = DateTime.now();

    // Separate today's birthdays from upcoming
    final todayBirthdays = birthdays.where((b) {
      return b.createdAt.day == today.day && b.createdAt.month == today.month;
    }).toList();

    final upcomingBirthdays = birthdays.where((b) {
      return b.actionDeadline != null &&
          (b.createdAt.day != today.day || b.createdAt.month != today.month);
    }).toList();

    return Card(
      clipBehavior: Clip.antiAlias,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header
          Container(
            padding: EdgeInsets.all(kIsWindows ? 16 : 16.sp),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [
                  AppTabs.clients.color.withValues(alpha: 0.8),
                  AppTabs.clients.color,
                ],
              ),
            ),
            child: Row(
              children: [
                Container(
                  padding: EdgeInsets.all(kIsWindows ? 8 : 8.sp),
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.2),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: const Icon(Symbols.cake_rounded, color: Colors.white),
                ),
                SizedBox(width: kIsWindows ? 12 : 12.w),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        '🎂 Compleanni',
                        style: TextStyle(
                          fontSize: kIsWindows ? 18 : 18.sp,
                          fontWeight: FontWeight.bold,
                          color: Colors.white,
                        ),
                      ),
                      if (todayBirthdays.isNotEmpty)
                        Text(
                          '${todayBirthdays.length} oggi!',
                          style: TextStyle(
                            fontSize: kIsWindows ? 14 : 14.sp,
                            color: Colors.white.withValues(alpha: 0.9),
                          ),
                        ),
                    ],
                  ),
                ),
                Container(
                  padding: EdgeInsets.symmetric(
                    horizontal: kIsWindows ? 12 : 12.w,
                    vertical: kIsWindows ? 6 : 6.sp,
                  ),
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.2),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Text(
                    '${birthdays.length} totali',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: kIsWindows ? 12 : 12.sp,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ],
            ),
          ),

          // Today's Birthdays (highlighted)
          if (todayBirthdays.isNotEmpty) ...[
            Container(
              padding: EdgeInsets.symmetric(
                horizontal: kIsWindows ? 16 : 16.sp,
                vertical: kIsWindows ? 12 : 12.sp,
              ),
              color: colorScheme.primaryContainer.withValues(alpha: 0.3),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'OGGI',
                    style: TextStyle(
                      fontSize: kIsWindows ? 12 : 12.sp,
                      fontWeight: FontWeight.bold,
                      color: colorScheme.primary,
                    ),
                  ),
                  SizedBox(height: kIsWindows ? 8 : 8.h),
                  ...todayBirthdays.map(
                    (b) => _BirthdayCard(notification: b, isToday: true),
                  ),
                ],
              ),
            ),
            Divider(
              height: 1,
              color: colorScheme.outline.withValues(alpha: 0.2),
            ),
          ],

          // Upcoming Birthdays
          if (upcomingBirthdays.isNotEmpty)
            Padding(
              padding: EdgeInsets.all(kIsWindows ? 16 : 16.sp),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'PROSSIMAMENTE',
                    style: TextStyle(
                      fontSize: kIsWindows ? 12 : 12.sp,
                      fontWeight: FontWeight.bold,
                      color: colorScheme.onSurfaceVariant,
                    ),
                  ),
                  SizedBox(height: kIsWindows ? 12 : 12.h),
                  ...upcomingBirthdays.map(
                    (b) => _BirthdayCard(notification: b, isToday: false),
                  ),
                ],
              ),
            ),
        ],
      ),
    ).animate().fadeIn(duration: 300.ms).slideY(begin: 0.1, end: 0);
  }
}

/// Birthday Card Widget
class _BirthdayCard extends StatelessWidget {
  final HubNotification notification;
  final bool isToday;

  const _BirthdayCard({required this.notification, required this.isToday});

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final daysUntil = notification.metadata?['daysUntil'] as int? ?? 0;
    final age = notification.metadata?['age'] as int? ?? 0;
    final phoneNumber = notification.metadata?['phoneNumber'] as String? ?? '';

    return Card(
      margin: EdgeInsets.only(bottom: kIsWindows ? 8 : 8.h),
      color: isToday
          ? colorScheme.secondaryContainer
          : colorScheme.surfaceContainerHighest.withValues(alpha: 0.5),
      elevation: isToday ? 2 : 0,
      child: Padding(
        padding: EdgeInsets.all(kIsWindows ? 12 : 12.sp),
        child: Row(
          children: [
            // Avatar/Icon
            Container(
              width: kIsWindows ? 48 : 48.w,
              height: kIsWindows ? 48 : 48.h,
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: isToday
                      ? [Colors.pink.shade300, Colors.purple.shade300]
                      : [
                          colorScheme.primary.withValues(alpha: 0.5),
                          colorScheme.primary.withValues(alpha: 0.3),
                        ],
                ),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Center(
                child: Text(
                  '🎂',
                  style: TextStyle(fontSize: kIsWindows ? 24 : 24.sp),
                ),
              ),
            ),
            SizedBox(width: kIsWindows ? 12 : 12.w),

            // Info
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    notification.clientName ?? 'Cliente',
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: kIsWindows ? 16 : 16.sp,
                    ),
                  ),
                  SizedBox(height: kIsWindows ? 4 : 4.h),
                  Text(
                    isToday
                        ? 'Compie $age anni oggi! 🎉'
                        : 'Compie $age anni tra $daysUntil giorni',
                    style: TextStyle(
                      fontSize: kIsWindows ? 13 : 13.sp,
                      color: colorScheme.onSurfaceVariant,
                    ),
                  ),
                ],
              ),
            ),

            // Action Button
            if (phoneNumber.isNotEmpty)
              IconButton(
                onPressed: () => _showContactOptions(context, phoneNumber),
                icon: const Icon(Symbols.send_rounded),
                style: IconButton.styleFrom(
                  backgroundColor: isToday
                      ? colorScheme.primary
                      : colorScheme.surfaceContainerHighest,
                  foregroundColor: isToday
                      ? colorScheme.onPrimary
                      : colorScheme.primary,
                ),
              ),
          ],
        ),
      ),
    );
  }

  void _showContactOptions(BuildContext context, String phoneNumber) {
    showModalBottomSheet<void>(
      context: context,
      builder: (context) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(Symbols.chat_rounded),
              title: const Text('Invia messaggio WhatsApp'),
              onTap: () {
                // Launch WhatsApp
                Navigator.pop(context);
              },
            ),
            ListTile(
              leading: const Icon(Symbols.sms_rounded),
              title: const Text('Invia SMS'),
              onTap: () {
                // Launch SMS
                Navigator.pop(context);
              },
            ),
            ListTile(
              leading: const Icon(Symbols.call_rounded),
              title: const Text('Chiama'),
              onTap: () {
                // Launch call
                Navigator.pop(context);
              },
            ),
          ],
        ),
      ),
    );
  }
}

/// Other Notifications Section
class _OtherNotificationsSection extends StatelessWidget {
  final List<HubNotification> notifications;
  final VoidCallback onMarkAllRead;

  const _OtherNotificationsSection({
    required this.notifications,
    required this.onMarkAllRead,
  });

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return Card(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header
          Padding(
            padding: EdgeInsets.all(kIsWindows ? 16 : 16.sp),
            child: Row(
              children: [
                Icon(Symbols.notifications_rounded, color: colorScheme.primary),
                SizedBox(width: kIsWindows ? 12 : 12.w),
                Expanded(
                  child: Text(
                    'Altre Notifiche',
                    style: TextStyle(
                      fontSize: kIsWindows ? 16 : 16.sp,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
                TextButton(
                  onPressed: onMarkAllRead,
                  child: const Text('Segna tutti letti'),
                ),
              ],
            ),
          ),

          // List
          ...notifications
              .take(5)
              .map((n) => _NotificationListTile(notification: n)),

          if (notifications.length > 5)
            Padding(
              padding: EdgeInsets.all(kIsWindows ? 16 : 16.sp),
              child: Center(
                child: TextButton(
                  onPressed: () {
                    // Show all notifications
                  },
                  child: Text('Vedi altri ${notifications.length - 5}'),
                ),
              ),
            ),
        ],
      ),
    );
  }
}

/// Single Notification List Tile
class _NotificationListTile extends StatelessWidget {
  final HubNotification notification;

  const _NotificationListTile({required this.notification});

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    final isUrgent = notification.priority == NotificationPriority.urgent;

    return ListTile(
      leading: Container(
        width: kIsWindows ? 40 : 40.w,
        height: kIsWindows ? 40 : 40.h,
        decoration: BoxDecoration(
          color: isUrgent
              ? colorScheme.errorContainer
              : colorScheme.surfaceContainerHighest,
          borderRadius: BorderRadius.circular(10),
        ),
        child: Center(
          child: Text(
            notification.icon,
            style: TextStyle(fontSize: kIsWindows ? 20 : 20.sp),
          ),
        ),
      ),
      title: Text(
        notification.title,
        style: TextStyle(
          fontWeight: notification.isRead ? FontWeight.normal : FontWeight.bold,
        ),
      ),
      subtitle: Text(
        notification.message,
        maxLines: 2,
        overflow: TextOverflow.ellipsis,
        style: TextStyle(
          color: colorScheme.onSurfaceVariant,
          fontSize: kIsWindows ? 12 : 12.sp,
        ),
      ),
      trailing: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Text(
            notification.timeAgo,
            style: TextStyle(
              fontSize: kIsWindows ? 11 : 11.sp,
              color: colorScheme.outline,
            ),
          ),
          if (isUrgent)
            Container(
              margin: EdgeInsets.only(top: kIsWindows ? 4 : 4.h),
              padding: EdgeInsets.symmetric(
                horizontal: kIsWindows ? 6 : 6.w,
                vertical: kIsWindows ? 2 : 2.sp,
              ),
              decoration: BoxDecoration(
                color: colorScheme.error,
                borderRadius: BorderRadius.circular(8),
              ),
              child: Text(
                'URGENTE',
                style: TextStyle(
                  color: colorScheme.onError,
                  fontSize: kIsWindows ? 9 : 9.sp,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
        ],
      ),
      onTap: () {
        // Handle notification tap
      },
    );
  }
}

/// Notification Bell Button with Badge for AppBar
/// Shows a bell icon with a badge count of unread notifications
class NotificationBellButton extends ConsumerWidget {
  const NotificationBellButton({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final hub = ref.watch(notificationsHubProvider);
    final colorScheme = Theme.of(context).colorScheme;

    // Count unread/high priority notifications
    final unreadCount = hub.notifications.where((n) => !n.isRead).length;
    final totalCount = hub.notifications.length;

    return Stack(
      children: [
        IconButton(
          onPressed: () => _showNotificationsDialog(context, ref),
          icon: Icon(
            totalCount > 0
                ? Symbols.notifications_active_rounded
                : Symbols.notifications_rounded,
            color: totalCount > 0 ? colorScheme.primary : colorScheme.onSurface,
          ),
          tooltip: 'Notifiche',
        ),
        // Badge with count
        if (totalCount > 0)
          Positioned(
            right: kIsWindows ? 4 : 4.w,
            top: kIsWindows ? 4 : 4.sp,
            child: Container(
              padding: EdgeInsets.symmetric(
                horizontal: kIsWindows ? 4 : 4.w,
                vertical: kIsWindows ? 2 : 2.sp,
              ),
              decoration: BoxDecoration(
                color: unreadCount > 0
                    ? colorScheme.error
                    : colorScheme.primary,
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: colorScheme.surface, width: 2),
              ),
              constraints: BoxConstraints(
                minWidth: kIsWindows ? 16 : 16.w,
                minHeight: kIsWindows ? 16 : 16.sp,
              ),
              child: Text(
                totalCount > 99 ? '99+' : '$totalCount',
                style: TextStyle(
                  color: unreadCount > 0
                      ? colorScheme.onError
                      : colorScheme.onPrimary,
                  fontSize: kIsWindows ? 10 : 10.sp,
                  fontWeight: FontWeight.bold,
                ),
                textAlign: TextAlign.center,
              ),
            ),
          ),
      ],
    );
  }

  void _showNotificationsDialog(BuildContext context, WidgetRef ref) {
    showDialog<void>(
      context: context,
      builder: (context) => const NotificationsDialog(),
    );
  }
}

/// Dialog showing all notifications
class NotificationsDialog extends ConsumerWidget {
  const NotificationsDialog({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final hub = ref.watch(notificationsHubProvider);
    final colorScheme = Theme.of(context).colorScheme;

    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      child: Container(
        width: kIsWindows ? 500 : double.maxFinite,
        constraints: BoxConstraints(
          maxHeight: kIsWindows
              ? 600
              : MediaQuery.of(context).size.height * 0.7,
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Header
              Container(
                padding: EdgeInsets.all(kIsWindows ? 20 : 20.sp),
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [
                      colorScheme.primaryContainer,
                      colorScheme.primaryContainer.withValues(alpha: 0.7),
                    ],
                  ),
                ),
                child: Row(
                  children: [
                    Container(
                      padding: EdgeInsets.all(kIsWindows ? 10 : 10.sp),
                      decoration: BoxDecoration(
                        color: colorScheme.primary,
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Icon(
                        Symbols.notifications_rounded,
                        color: colorScheme.onPrimary,
                        size: kIsWindows ? 24 : 24.sp,
                      ),
                    ),
                    SizedBox(width: kIsWindows ? 16 : 16.w),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Notifiche',
                            style: TextStyle(
                              fontSize: kIsWindows ? 20 : 20.sp,
                              fontWeight: FontWeight.bold,
                              color: colorScheme.onPrimaryContainer,
                            ),
                          ),
                          if (hub.notifications.isNotEmpty)
                            Text(
                              '${hub.notifications.length} notifiche',
                              style: TextStyle(
                                fontSize: kIsWindows ? 14 : 14.sp,
                                color: colorScheme.onPrimaryContainer
                                    .withValues(alpha: 0.7),
                              ),
                            ),
                        ],
                      ),
                    ),
                    IconButton(
                      onPressed: () => Navigator.pop(context),
                      icon: Icon(
                        Symbols.close_rounded,
                        color: colorScheme.onPrimaryContainer,
                      ),
                    ),
                  ],
                ),
              ),

              // Content
              Flexible(child: _buildDialogContent(hub, colorScheme, ref)),

              // Footer
              if (hub.notifications.isNotEmpty)
                Container(
                  padding: EdgeInsets.all(kIsWindows ? 16 : 16.sp),
                  decoration: BoxDecoration(
                    border: Border(
                      top: BorderSide(
                        color: colorScheme.outlineVariant.withValues(
                          alpha: 0.5,
                        ),
                      ),
                    ),
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                    children: [
                      TextButton.icon(
                        onPressed: () {
                          ref
                              .read(notificationsHubProvider.notifier)
                              .markAllAsRead();
                        },
                        icon: Icon(
                          Symbols.done_all_rounded,
                          size: kIsWindows ? 18 : 18.sp,
                        ),
                        label: Text(
                          'Segna tutti letti',
                          style: TextStyle(fontSize: kIsWindows ? 14 : 14.sp),
                        ),
                      ),
                      FilledButton.icon(
                        onPressed: () {
                          ref.read(notificationsHubProvider.notifier).refresh();
                        },
                        icon: Icon(
                          Symbols.refresh_rounded,
                          size: kIsWindows ? 18 : 18.sp,
                        ),
                        label: Text(
                          'Aggiorna',
                          style: TextStyle(fontSize: kIsWindows ? 14 : 14.sp),
                        ),
                      ),
                    ],
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildDialogContent(
    NotificationsHubState hub,
    ColorScheme colorScheme,
    WidgetRef ref,
  ) {
    if (hub.isLoading) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            CircularProgressIndicator(color: colorScheme.primary),
            SizedBox(height: kIsWindows ? 16 : 16.h),
            Text(
              'Caricamento...',
              style: TextStyle(color: colorScheme.onSurfaceVariant),
            ),
          ],
        ),
      );
    }

    if (hub.error != null) {
      return Center(
        child: Padding(
          padding: EdgeInsets.all(kIsWindows ? 24 : 24.sp),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                Symbols.error_rounded,
                color: colorScheme.error,
                size: kIsWindows ? 48 : 48.sp,
              ),
              SizedBox(height: kIsWindows ? 16 : 16.h),
              Text(
                hub.error!,
                style: TextStyle(color: colorScheme.error),
                textAlign: TextAlign.center,
              ),
              SizedBox(height: kIsWindows ? 16 : 16.h),
              FilledButton.tonal(
                onPressed: () =>
                    ref.read(notificationsHubProvider.notifier).refresh(),
                child: const Text('Riprova'),
              ),
            ],
          ),
        ),
      );
    }

    if (hub.notifications.isEmpty) {
      return Center(
        child: Padding(
          padding: EdgeInsets.all(kIsWindows ? 32 : 32.sp),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                Symbols.notifications_off_rounded,
                color: colorScheme.outline,
                size: kIsWindows ? 64 : 64.sp,
              ),
              SizedBox(height: kIsWindows ? 16 : 16.h),
              Text(
                'Nessuna notifica',
                style: TextStyle(
                  fontSize: kIsWindows ? 18 : 18.sp,
                  fontWeight: FontWeight.bold,
                  color: colorScheme.onSurface,
                ),
              ),
              SizedBox(height: kIsWindows ? 8 : 8.h),
              Text(
                'Tutto è aggiornato! Non ci sono compleanni o scadenze.',
                style: TextStyle(color: colorScheme.onSurfaceVariant),
                textAlign: TextAlign.center,
              ),
            ],
          ),
        ),
      );
    }

    // Separate birthdays from other notifications
    final birthdays = hub.notifications
        .where((n) => n.type == NotificationType.birthday)
        .toList();
    final otherNotifications = hub.notifications
        .where((n) => n.type != NotificationType.birthday)
        .toList();

    return SingleChildScrollView(
      padding: EdgeInsets.all(kIsWindows ? 16 : 16.sp),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          // Birthdays Section
          if (birthdays.isNotEmpty) ...[
            _DialogBirthdaysSection(birthdays: birthdays),
            if (otherNotifications.isNotEmpty)
              SizedBox(height: kIsWindows ? 16 : 16.h),
          ],

          // Other Notifications Section
          if (otherNotifications.isNotEmpty)
            _DialogOtherNotificationsSection(
              notifications: otherNotifications,
              onMarkAllRead: () =>
                  ref.read(notificationsHubProvider.notifier).markAllAsRead(),
            ),
        ],
      ),
    );
  }
}

/// Birthdays Section for Dialog
class _DialogBirthdaysSection extends StatelessWidget {
  final List<HubNotification> birthdays;

  const _DialogBirthdaysSection({required this.birthdays});

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final today = DateTime.now();

    final todayBirthdays = birthdays.where((b) {
      return b.createdAt.day == today.day && b.createdAt.month == today.month;
    }).toList();

    final upcomingBirthdays = birthdays.where((b) {
      return b.actionDeadline != null &&
          (b.createdAt.day != today.day || b.createdAt.month != today.month);
    }).toList();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Section Header
        Container(
          padding: EdgeInsets.symmetric(
            horizontal: kIsWindows ? 12 : 12.w,
            vertical: kIsWindows ? 8 : 8.sp,
          ),
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: [
                AppTabs.clients.color.withValues(alpha: 0.8),
                AppTabs.clients.color,
              ],
            ),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Row(
            children: [
              const Text('🎂', style: TextStyle(fontSize: 18)),
              SizedBox(width: kIsWindows ? 8 : 8.w),
              Text(
                'Compleanni',
                style: TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.bold,
                  fontSize: kIsWindows ? 16 : 16.sp,
                ),
              ),
              const Spacer(),
              Container(
                padding: EdgeInsets.symmetric(
                  horizontal: kIsWindows ? 8 : 8.w,
                  vertical: kIsWindows ? 4 : 4.sp,
                ),
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.2),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  '${birthdays.length}',
                  style: const TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.bold,
                    fontSize: 12,
                  ),
                ),
              ),
            ],
          ),
        ),
        SizedBox(height: kIsWindows ? 12 : 12.h),

        // Today's Birthdays
        if (todayBirthdays.isNotEmpty) ...[
          Container(
            padding: EdgeInsets.all(kIsWindows ? 12 : 12.sp),
            decoration: BoxDecoration(
              color: colorScheme.primaryContainer.withValues(alpha: 0.3),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'OGGI 🎉',
                  style: TextStyle(
                    fontSize: kIsWindows ? 12 : 12.sp,
                    fontWeight: FontWeight.bold,
                    color: colorScheme.primary,
                  ),
                ),
                SizedBox(height: kIsWindows ? 8 : 8.h),
                ...todayBirthdays.map(
                  (b) => _CompactBirthdayCard(notification: b, isToday: true),
                ),
              ],
            ),
          ),
          if (upcomingBirthdays.isNotEmpty)
            SizedBox(height: kIsWindows ? 12 : 12.h),
        ],

        // Upcoming Birthdays
        if (upcomingBirthdays.isNotEmpty) ...[
          Text(
            'Prossimamente',
            style: TextStyle(
              fontSize: kIsWindows ? 12 : 12.sp,
              fontWeight: FontWeight.bold,
              color: colorScheme.onSurfaceVariant,
            ),
          ),
          SizedBox(height: kIsWindows ? 8 : 8.h),
          ...upcomingBirthdays.map(
            (b) => _CompactBirthdayCard(notification: b, isToday: false),
          ),
        ],
      ],
    );
  }
}

/// Compact Birthday Card for Dialog
class _CompactBirthdayCard extends StatelessWidget {
  final HubNotification notification;
  final bool isToday;

  const _CompactBirthdayCard({
    required this.notification,
    required this.isToday,
  });

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final daysUntil = notification.metadata?['daysUntil'] as int? ?? 0;
    final age = notification.metadata?['age'] as int? ?? 0;

    return Card(
      margin: EdgeInsets.only(bottom: kIsWindows ? 8 : 8.h),
      color: isToday ? colorScheme.secondaryContainer : null,
      elevation: isToday ? 2 : 0,
      child: ListTile(
        dense: true,
        leading: Container(
          width: kIsWindows ? 40 : 40.w,
          height: kIsWindows ? 40 : 40.h,
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: isToday
                  ? [Colors.pink.shade300, Colors.purple.shade300]
                  : [
                      colorScheme.primary.withValues(alpha: 0.5),
                      colorScheme.primary.withValues(alpha: 0.3),
                    ],
            ),
            borderRadius: BorderRadius.circular(8),
          ),
          child: const Center(
            child: Text('🎂', style: TextStyle(fontSize: 18)),
          ),
        ),
        title: Text(
          notification.clientName ?? 'Cliente',
          style: TextStyle(
            fontWeight: FontWeight.bold,
            fontSize: kIsWindows ? 14 : 14.sp,
          ),
        ),
        subtitle: Text(
          isToday
              ? 'Compie $age anni oggi! 🎉'
              : 'Compie $age anni tra $daysUntil giorni',
          style: TextStyle(
            fontSize: kIsWindows ? 12 : 12.sp,
            color: colorScheme.onSurfaceVariant,
          ),
        ),
      ),
    );
  }
}

/// Other Notifications Section for Dialog
class _DialogOtherNotificationsSection extends StatelessWidget {
  final List<HubNotification> notifications;
  final VoidCallback onMarkAllRead;

  const _DialogOtherNotificationsSection({
    required this.notifications,
    required this.onMarkAllRead,
  });

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Section Header
        Row(
          children: [
            Icon(Symbols.notifications_rounded, color: colorScheme.primary),
            SizedBox(width: kIsWindows ? 8 : 8.w),
            Text(
              'Altre Notifiche',
              style: TextStyle(
                fontSize: kIsWindows ? 16 : 16.sp,
                fontWeight: FontWeight.bold,
              ),
            ),
            const Spacer(),
            TextButton(
              onPressed: onMarkAllRead,
              child: Text(
                'Segna letti',
                style: TextStyle(fontSize: kIsWindows ? 12 : 12.sp),
              ),
            ),
          ],
        ),
        SizedBox(height: kIsWindows ? 12 : 12.h),

        // List
        ...notifications.map((n) => _DialogNotificationTile(notification: n)),
      ],
    );
  }
}

/// Dialog Notification Tile
class _DialogNotificationTile extends StatelessWidget {
  final HubNotification notification;

  const _DialogNotificationTile({required this.notification});

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final isUrgent = notification.priority == NotificationPriority.urgent;

    return Card(
      margin: EdgeInsets.only(bottom: kIsWindows ? 8 : 8.h),
      elevation: 0,
      color: isUrgent
          ? colorScheme.errorContainer.withValues(alpha: 0.3)
          : colorScheme.surfaceContainerHighest.withValues(alpha: 0.5),
      child: ListTile(
        dense: true,
        leading: Container(
          width: kIsWindows ? 36 : 36.w,
          height: kIsWindows ? 36 : 36.h,
          decoration: BoxDecoration(
            color: isUrgent
                ? colorScheme.errorContainer
                : colorScheme.surfaceContainerHighest,
            borderRadius: BorderRadius.circular(8),
          ),
          child: Center(
            child: Text(
              notification.icon,
              style: TextStyle(fontSize: kIsWindows ? 18 : 18.sp),
            ),
          ),
        ),
        title: Text(
          notification.title,
          style: TextStyle(
            fontWeight: notification.isRead
                ? FontWeight.normal
                : FontWeight.bold,
            fontSize: kIsWindows ? 14 : 14.sp,
          ),
        ),
        subtitle: Text(
          notification.message,
          maxLines: 2,
          overflow: TextOverflow.ellipsis,
          style: TextStyle(
            color: colorScheme.onSurfaceVariant,
            fontSize: kIsWindows ? 12 : 12.sp,
          ),
        ),
        trailing: isUrgent
            ? Container(
                padding: EdgeInsets.symmetric(
                  horizontal: kIsWindows ? 6 : 6.w,
                  vertical: kIsWindows ? 2 : 2.sp,
                ),
                decoration: BoxDecoration(
                  color: colorScheme.error,
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Text(
                  'URG',
                  style: TextStyle(
                    color: colorScheme.onError,
                    fontSize: kIsWindows ? 9 : 9.sp,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              )
            : null,
      ),
    );
  }
}
