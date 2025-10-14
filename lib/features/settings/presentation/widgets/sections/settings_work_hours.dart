import 'package:beauty_center/core/database/extensions/db_models_extensions.dart';
import 'package:beauty_center/core/localizations/extensions/l10n_extensions.dart';
import 'package:beauty_center/core/tabs/app_tabs.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:material_symbols_icons/symbols.dart';

import '../../../../../core/connectivity/connectivity_provider.dart';
import '../../../../../core/constants/app_constants.dart';
import '../../../../../core/database/app_database.dart';
import '../../../../../core/supabase/supabase_auth_provider.dart';
import '../../../../../core/widgets/custom_snackbar.dart';
import '../../../../../core/widgets/section_card.dart';
import '../../providers/settings_provider.dart';

class WorkHoursSection extends ConsumerWidget {
  const WorkHoursSection({required this.workHours, super.key});

  final WorkHours workHours;

  @override
  Widget build(final BuildContext context, final WidgetRef ref) {
    final colorScheme = Theme.of(context).colorScheme;

    final isOffline = ref.watch(isOfflineProvider);
    final isDisconnectedSup = ref.watch(supabaseAuthProvider).isDisconnected;

    final hours = workHours.workDayMinutes ~/ 60;
    final minutes = workHours.workDayMinutes % 60;

    return SectionCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(
                Symbols.schedule,
                size: kIsWindows ? 28 : 28.sp,
                color: colorScheme.primary,
              ),
              SizedBox(width: kIsWindows ? 8 : 8.w),
              Text(
                context.l10n.workHours,
                style: TextStyle(
                  fontSize: kIsWindows ? 24 : 24.sp,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
          SizedBox(height: kIsWindows ? 16 : 16.h),
          Row(
            children: [
              Expanded(
                child: _TimeCard(
                  label: context.l10n.start,
                  subtitle: '06:00 - 12:00',
                  time: workHours.startTime.format(context),
                  icon: Symbols.wb_sunny_rounded,
                  onTap: () {
                    if (isOffline || isDisconnectedSup) {
                      showCustomSnackBar(
                        context: context,
                        message: context.l10n.offlineNoChangeData,
                        okColor: AppTabs.settings.color,
                      );
                    } else {
                      _pickTime(
                        context: context,
                        ref: ref,
                        isStart: true,
                        currentTime: workHours.startTime,
                      );
                    }
                  },
                  isOffline: isOffline || isDisconnectedSup,
                ),
              ),
              SizedBox(width: kIsWindows ? 12 : 12.w),
              Expanded(
                child: _TimeCard(
                  label: context.l10n.end,
                  subtitle: '14:00 - 22:00',
                  time: workHours.endTime.format(context),
                  icon: Symbols.nightlight_round,
                  onTap: () {
                    if (isOffline || isDisconnectedSup) {
                      showCustomSnackBar(
                        context: context,
                        message: context.l10n.offlineNoChangeData,
                        okColor: AppTabs.settings.color,
                      );
                    } else {
                      _pickTime(
                        context: context,
                        ref: ref,
                        isStart: false,
                        currentTime: workHours.endTime,
                      );
                    }
                  },
                  isOffline: isOffline || isDisconnectedSup,
                ),
              ),
            ],
          ),
          SizedBox(height: kIsWindows ? 12 : 12.h),
          Container(
            padding: EdgeInsets.all(kIsWindows ? 12 : 12.w),
            decoration: BoxDecoration(
              color: colorScheme.primaryContainer.withValues(alpha: 0.3),
              borderRadius: BorderRadius.circular(kIsWindows ? 8 : 8.r),
              border: Border.all(
                color: colorScheme.primary.withValues(alpha: 0.2),
              ),
            ),
            child: Row(
              children: [
                Icon(
                  Symbols.info_rounded,
                  size: kIsWindows ? 18 : 18.sp,
                  color: colorScheme.primary,
                ),
                SizedBox(width: kIsWindows ? 8 : 8.w),
                Expanded(
                  child: Text(
                    context.l10n.workDayDuration(hours, minutes),
                    style: TextStyle(
                      fontSize: kIsWindows ? 14 : 14.sp,
                      color: colorScheme.onSurface,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _pickTime({
    required final BuildContext context,
    required final WidgetRef ref,
    required final bool isStart,
    required final TimeOfDay currentTime,
  }) async {
    final picked = await showTimePicker(
      context: context,
      initialTime: currentTime,
      builder: (final context, final child) => MediaQuery(
        data: MediaQuery.of(context).copyWith(alwaysUse24HourFormat: true),
        child: child!,
      ),
    );

    if (picked == null) {
      return;
    }

    final totalMinutes = picked.hour * 60 + picked.minute;
    if (isStart) {
      // Range 6:00 - 12:00
      if (totalMinutes < 360 || totalMinutes > 720) {
        if (context.mounted) {
          showCustomSnackBar(
            context: context,
            message: context.l10n.rangeStartWorkHours,
            okColor: AppTabs.settings.color,
          );
        }
        return;
      }
    } else {
      // Range 14:00 - 22:00
      if (totalMinutes < 840 || totalMinutes > 1320) {
        if (context.mounted) {
          showCustomSnackBar(
            context: context,
            message: context.l10n.rangeEndWorkHours,
            okColor: AppTabs.settings.color,
          );
        }
        return;
      }
    }

    final actions = ref.read(settingsActionsProvider);
    if (isStart) {
      await actions.updateWorkHours(
        startTime: picked,
        endTime: workHours.endTime,
      );
    } else {
      await actions.updateWorkHours(
        startTime: workHours.startTime,
        endTime: picked,
      );
    }
  }
}

class _TimeCard extends StatelessWidget {
  const _TimeCard({
    required this.label,
    required this.subtitle,
    required this.time,
    required this.icon,
    required this.onTap,
    required this.isOffline,
  });

  final String label;
  final String subtitle;
  final String time;
  final IconData icon;
  final VoidCallback onTap;
  final bool isOffline;

  @override
  Widget build(final BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(kIsWindows ? 12 : 12.r),
      child: Opacity(
        opacity: isOffline ? 0.6 : 1.0,
        child: Container(
          padding: EdgeInsets.all(kIsWindows ? 16 : 16.w),
          decoration: BoxDecoration(
            color: colorScheme.surfaceContainerHighest,
            borderRadius: BorderRadius.circular(kIsWindows ? 12 : 12.r),
            border: Border.all(
              color: colorScheme.outline.withValues(alpha: 0.2),
            ),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Icon(
                    icon,
                    size: kIsWindows ? 20 : 20.sp,
                    color: colorScheme.primary,
                  ),
                  SizedBox(width: kIsWindows ? 6 : 6.w),
                  Text(
                    label,
                    style: TextStyle(
                      fontSize: kIsWindows ? 18 : 18.sp,
                      color: colorScheme.onSurfaceVariant,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ],
              ),
              SizedBox(height: kIsWindows ? 8 : 8.h),
              Text(
                time,
                style: TextStyle(
                  fontSize: kIsWindows ? 22 : 22.sp,
                  fontWeight: FontWeight.bold,
                  color: colorScheme.onSurface,
                ),
              ),
              SizedBox(height: kIsWindows ? 4 : 4.h),
              Text(
                subtitle,
                style: TextStyle(
                  fontSize: kIsWindows ? 16 : 16.sp,
                  color: colorScheme.onSurfaceVariant.withValues(alpha: 0.7),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
