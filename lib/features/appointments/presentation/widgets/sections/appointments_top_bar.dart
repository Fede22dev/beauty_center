import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:intl/intl.dart';
import 'package:material_symbols_icons/symbols.dart';
import 'package:timely_x/timely_x.dart';

import '../../../../../core/constants/app_constants.dart';
import '../../../providers/appointments_providers.dart';
import '../common/appointments_date_picker_dialog.dart';
import '../dialogs/blocked_slot_dialog.dart';

class AppointmentsTopBar extends ConsumerStatefulWidget {
  const AppointmentsTopBar(this.calendarController, {super.key});

  final CalendarController calendarController;

  @override
  ConsumerState<AppointmentsTopBar> createState() => _AppointmentsTopBarState();
}

class _AppointmentsTopBarState extends ConsumerState<AppointmentsTopBar> {
  late DateTime _selectedDay;

  @override
  void initState() {
    super.initState();
    _selectedDay = widget.calendarController.currentDate;
  }

  @override
  void didUpdateWidget(AppointmentsTopBar oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.calendarController.currentDate != _selectedDay) {
      setState(() => _selectedDay = widget.calendarController.currentDate);
    }
  }

  void _changeDay(int delta) {
    if (delta == 1) {
      widget.calendarController.next();
    } else {
      widget.calendarController.previous();
    }
    setState(() => _selectedDay = widget.calendarController.currentDate);
    ref.read(calendarDateProvider.notifier).update(_selectedDay);
  }

  Future<void> _showDatePicker() async {
    final picked = await showAppointmentsDatePickerDialog(
      context: context,
      selectedDay: _selectedDay,
    );
    if (picked != null && picked != _selectedDay) {
      widget.calendarController.goToDate(picked);
      setState(() => _selectedDay = picked);
      ref.read(calendarDateProvider.notifier).update(picked);
    }
  }

  void _openBlockedSlotDialog() {
    showDialog<void>(
      context: context,
      builder: (ctx) => BlockedSlotDialog(initialDate: _selectedDay),
    );
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final barHeight = kIsWindows ? 44.0 : 48.h;

    final isToday = _isToday(_selectedDay);

    // ── MAIN NAVIGATION BLOCK ──
    final Widget dateNavBlock = Material(
      color: cs.surfaceContainerHighest.withValues(alpha: 0.5),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(kIsWindows ? 14 : 14.r),
        side: BorderSide(color: cs.outlineVariant.withValues(alpha: 0.6)),
      ),
      clipBehavior: Clip.antiAlias,
      child: SizedBox(
        height: barHeight,
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            _NavArrow(
              icon: Symbols.chevron_left_rounded,
              tooltip: 'Giorno precedente',
              onPressed: () => _changeDay(-1),
            ),
            Expanded(
              child: InkWell(
                onTap: _showDatePicker,
                splashColor: cs.primary.withValues(alpha: 0.1),
                highlightColor: cs.primary.withValues(alpha: 0.05),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    if (kIsWindows) ...[
                      Icon(
                        Symbols.calendar_month_rounded,
                        size: 20,
                        weight: 700,
                        color: cs.primary,
                        fill: 1,
                      ),
                      const SizedBox(width: 12),
                    ],
                    Text(
                      _formatDate(_selectedDay),
                      key: ValueKey<String>(_selectedDay.toIso8601String()),
                      style: TextStyle(
                        fontSize: kIsWindows ? 18 : 16.sp,
                        fontWeight: FontWeight.w700,
                        letterSpacing: 0.3,
                        color: cs.onSurface,
                      ),
                    ),
                    if (kIsWindows) ...[
                      const SizedBox(width: 4),
                      Icon(
                        Symbols.arrow_drop_down_rounded,
                        size: 32,
                        weight: 700,
                        color: cs.onSurfaceVariant,
                      ),
                    ],
                  ],
                ),
              ),
            ),
            _NavArrow(
              icon: Symbols.chevron_right_rounded,
              tooltip: 'Giorno successivo',
              onPressed: () => _changeDay(1),
            ),
          ],
        ),
      ),
    );

    // ── ACTION BUTTONS BLOCK ──
    final actionButtons = [
      _ActionButton(
        label: 'OGGI',
        isPrimary: !isToday,
        onPressed: () async {
          final now = DateTime.now();
          widget.calendarController.scrollToTime(now);

          if (isToday) return;
          widget.calendarController.goToDate(now);
          setState(() => _selectedDay = widget.calendarController.currentDate);
          ref.read(calendarDateProvider.notifier).update(_selectedDay);
          await Future<void>.delayed(const Duration(milliseconds: 100));
          widget.calendarController.scrollToTime(now);
        },
      ),
      SizedBox(width: kIsWindows ? 8 : 6.w),
      _IconButton(
        icon: Symbols.block_rounded,
        tooltip: 'Aggiungi blocco operatore',
        backgroundColor: cs.errorContainer,
        foregroundColor: cs.onErrorContainer,
        onPressed: _openBlockedSlotDialog,
      ),
    ];

    return Padding(
      padding: EdgeInsets.symmetric(horizontal: kIsWindows ? 8 : 4.w),
      child: kIsWindows
          ? Row(
              children: [
                const Expanded(child: SizedBox.shrink()),
                SizedBox(width: 340, child: dateNavBlock),
                Expanded(
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.end,
                    children: actionButtons,
                  ),
                ),
              ],
            )
          : Row(
              children: [
                Expanded(child: dateNavBlock),
                SizedBox(width: 8.w),
                ...actionButtons,
              ],
            ),
    );
  }

  String _formatDate(DateTime date) {
    final dayName = DateFormat('EEE', 'it_IT').format(date).toUpperCase();
    final dateString = DateFormat('dd/MM/yy', 'it_IT').format(date);
    return '$dayName, $dateString';
  }

  bool _isToday(DateTime date) {
    final now = DateTime.now();
    return date.year == now.year &&
        date.month == now.month &&
        date.day == now.day;
  }
}

class _NavArrow extends StatelessWidget {
  const _NavArrow({
    required this.icon,
    required this.onPressed,
    required this.tooltip,
  });

  final IconData icon;
  final VoidCallback onPressed;
  final String tooltip;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;

    return Tooltip(
      message: tooltip,
      child: InkWell(
        onTap: onPressed,
        splashColor: cs.onSurface.withValues(alpha: 0.1),
        highlightColor: cs.onSurface.withValues(alpha: 0.05),
        child: Padding(
          padding: EdgeInsets.symmetric(horizontal: kIsWindows ? 16 : 4.w),
          child: Icon(
            icon,
            size: kIsWindows ? 32 : 32.sp,
            weight: 700,
            color: cs.onSurfaceVariant,
          ),
        ),
      ),
    );
  }
}

class _ActionButton extends StatelessWidget {
  const _ActionButton({
    required this.label,
    required this.onPressed,
    this.isPrimary = false,
  });

  final String label;
  final VoidCallback onPressed;
  final bool isPrimary;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final height = kIsWindows ? 44.0 : 48.h;

    return SizedBox(
      height: height,
      child: isPrimary
          ? FilledButton(
              onPressed: onPressed,
              style: FilledButton.styleFrom(
                elevation: 0,
                padding: EdgeInsets.symmetric(
                  horizontal: kIsWindows ? 20 : 16.w,
                ),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(kIsWindows ? 14 : 14.r),
                ),
              ),
              child: _buildText(),
            )
          : FilledButton.tonal(
              onPressed: onPressed,
              style: FilledButton.styleFrom(
                elevation: 0,
                backgroundColor: cs.surfaceContainerHighest,
                foregroundColor: cs.onSurfaceVariant,
                padding: EdgeInsets.symmetric(
                  horizontal: kIsWindows ? 20 : 16.w,
                ),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(kIsWindows ? 14 : 14.r),
                ),
              ),
              child: _buildText(),
            ),
    );
  }

  Widget _buildText() => Text(
    label,
    style: TextStyle(
      fontSize: kIsWindows ? 14 : 14.sp,
      fontWeight: FontWeight.w700,
      letterSpacing: 0.3,
    ),
  );
}

class _IconButton extends StatelessWidget {
  const _IconButton({
    required this.icon,
    required this.tooltip,
    required this.onPressed,
    required this.backgroundColor,
    required this.foregroundColor,
  });

  final IconData icon;
  final String tooltip;
  final VoidCallback onPressed;
  final Color backgroundColor;
  final Color foregroundColor;

  @override
  Widget build(BuildContext context) {
    final size = kIsWindows ? 44.0 : 48.h;

    return Tooltip(
      message: tooltip,
      child: SizedBox(
        height: size,
        width: size,
        child: FilledButton(
          style: FilledButton.styleFrom(
            backgroundColor: backgroundColor,
            foregroundColor: foregroundColor,
            padding: EdgeInsets.zero,
            elevation: 0,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(kIsWindows ? 14 : 14.r),
            ),
          ),
          onPressed: onPressed,
          child: Icon(icon, size: kIsWindows ? 22 : 22.sp, weight: 700),
        ),
      ),
    );
  }
}
