import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:intl/intl.dart';
import 'package:material_symbols_icons/symbols.dart';
import 'package:timely_x/timely_x.dart';

import '../../../../../core/constants/app_constants.dart';
import '../../../../../core/database/app_database.dart';
import '../../../../../core/widgets/app_error_view.dart';
import '../../../../clients/providers/clients_providers.dart';
import '../../../../settings/providers/settings_providers.dart';
import '../../../providers/appointments_providers.dart';
import '../../../providers/operator_blocked_slots_providers.dart';
import '../../theme/agenda_calendar_theme.dart';
import '../dialogs/appointment_dialog.dart';
import '../dialogs/blocked_slot_dialog.dart';

class AppointmentsAgenda extends ConsumerStatefulWidget {
  const AppointmentsAgenda(this.calendarController, {super.key});

  final CalendarController calendarController;

  @override
  ConsumerState<AppointmentsAgenda> createState() => _AppointmentsAgendaState();
}

class _AppointmentsAgendaState extends ConsumerState<AppointmentsAgenda> {
  var _initialScrollDone = false;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;

    final appointmentsAsync = ref.watch(appointmentsStreamProvider);
    final blockedAsync = ref.watch(operatorBlockedSlotsStreamProvider);
    final operatorsAsync = ref.watch(operatorsStreamProvider);
    final cabinsAsync = ref.watch(activeCabinsStreamProvider);
    final clientsAsync = ref.watch(clientsStreamProvider);
    final workHoursAsync = ref.watch(workHoursStreamProvider);

    if (appointmentsAsync.isLoading ||
        blockedAsync.isLoading ||
        operatorsAsync.isLoading ||
        cabinsAsync.isLoading ||
        clientsAsync.isLoading ||
        workHoursAsync.isLoading) {
      return const Center(child: CircularProgressIndicator());
    } else if (appointmentsAsync.hasError ||
        blockedAsync.hasError ||
        operatorsAsync.hasError ||
        cabinsAsync.hasError ||
        clientsAsync.hasError ||
        workHoursAsync.hasError) {
      return AppErrorView(
        message: 'Impossibile caricare i dati del calendario',
        onRetry: () {
          ref
            ..invalidate(appointmentsStreamProvider)
            ..invalidate(operatorBlockedSlotsStreamProvider)
            ..invalidate(operatorsStreamProvider)
            ..invalidate(activeCabinsStreamProvider)
            ..invalidate(clientsStreamProvider)
            ..invalidate(workHoursStreamProvider);
        },
      );
    }

    if (!appointmentsAsync.hasValue ||
        !blockedAsync.hasValue ||
        !operatorsAsync.hasValue ||
        !cabinsAsync.hasValue ||
        !clientsAsync.hasValue ||
        !workHoursAsync.hasValue) {
      return const Center(child: CircularProgressIndicator());
    }

    final appointments = appointmentsAsync.value!;
    final blockedSlots = blockedAsync.value!;
    final operators = operatorsAsync.value!;
    final clientsMap = {for (final c in clientsAsync.value!) c.id: c};
    final cabinsMap = {for (final c in cabinsAsync.value!) c.id: c};
    final workHours = workHoursAsync.value!;

    final resources = _mapOperatorsToResources(operators);
    final appointmentsList = _mapAppointmentsToEvents(
      appointments,
      clientsMap,
      cabinsMap,
      operators,
    );
    final blocksList = _mapBlockedSlotsToEvents(blockedSlots, cs);

    final allAppointments = <DefaultAppointment>[
      ...appointmentsList,
      ...blocksList,
    ];

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      widget.calendarController.updateResources(resources);
      widget.calendarController.updateAppointments(allAppointments);

      if (!_initialScrollDone) {
        _initialScrollDone = true;

        // Aspettiamo una frazione di secondo affinché la griglia interna
        // e lo ScrollController della libreria vengano montati correttamente.
        Future.delayed(const Duration(milliseconds: 150), () {
          if (mounted) {
            widget.calendarController.scrollToTime(DateTime.now());
          }
        });
      }
    });

    return LayoutBuilder(
      builder: (context, constraints) {
        final timeColWidth = kIsWindows ? 65.0 : 55.0.w;
        final availableWidth = constraints.maxWidth - timeColWidth;
        final minColWidth = kIsWindows ? 150.0 : 130.0.w;

        var preferredColWidth = minColWidth;
        if (resources.isNotEmpty) {
          final calcWidth = availableWidth / resources.length;
          if (calcWidth > minColWidth) {
            preferredColWidth = calcWidth;
          }
        }

        final config = _buildCalendarConfig(
          workHours,
          timeColWidth,
          minColWidth,
          preferredColWidth,
        );

        return CalendarView(
          controller: widget.calendarController,
          config: config,
          theme: buildAgendaTheme(cs),

          timeColumnBuilder: (context, time, height, isHourMark) =>
              _buildTimeColumn(context, time, height, isHourMark, cs),

          resourceHeaderBuilder:
              ({
                required BuildContext context,
                required CalendarResource resource,
                required double width,
                required bool isHovered,
                required int appointmentsCount,
              }) => _OperatorHeader(resource: resource, width: width),

          appointmentBuilder:
              (context, appointment, resource, rect, isSelected) {
                final data = appointment.customData?['original'];
                if (data is AppointmentData) {
                  return _AppointmentTile(
                    appointment: data,
                    appointmentModel: appointment,
                    rect: rect,
                    client: clientsMap[data.clientId],
                    cabin: cabinsMap[data.cabinId],
                    onTap: () =>
                        _openAppointmentDialog(existingAppointment: data),
                  );
                } else if (data is OperatorBlockedSlot) {
                  return _BlockedSlotTile(
                    blockedSlot: data,
                    appointmentModel: appointment,
                    rect: rect,
                    onTap: () => _openBlockedSlotDialog(existingSlot: data),
                  );
                }
                return const SizedBox();
              },

          onCellTap: (data) {
            _handleSlotTap(
              int.parse(data.resource.id),
              data.dateTime,
              operators,
            );
          },

          currentTimeIndicatorBuilder: (context, width) =>
              _buildCurrentTimeIndicator(cs, width),
        );
      },
    );
  }

  List<DefaultResource> _mapOperatorsToResources(List<Operator> ops) => ops
      .map(
        (o) => DefaultResource(
          id: o.id.toString(),
          name: o.name,
          color: _operatorColor(o.id),
        ),
      )
      .toList();

  List<DefaultAppointment> _mapAppointmentsToEvents(
    List<AppointmentData> appointments,
    Map<String, Client> clientsMap,
    Map<int, Cabin> cabinsMap,
    List<Operator> operators,
  ) => appointments.map((a) {
    final client = clientsMap[a.clientId];
    final clientName = client != null
        ? '${client.firstName} ${client.lastName}'
        : 'Cliente Sconosciuto';
    final cabin = cabinsMap[a.cabinId];
    final cabinColor = cabin?.color ?? Colors.grey.value;
    return DefaultAppointment(
      id: a.id,
      resourceId: a.operatorId.toString(),
      startTime: a.startDateTime,
      endTime: a.endDateTime,
      title: clientName,
      //subtitle: a.service,
      color: Color(cabinColor),
      customData: {'original': a},
    );
  }).toList();

  List<DefaultAppointment> _mapBlockedSlotsToEvents(
    List<OperatorBlockedSlot> blockedSlots,
    ColorScheme cs,
  ) => blockedSlots
      .map(
        (b) => DefaultAppointment(
          id: 'block_${b.id}',
          resourceId: b.operatorId.toString(),
          startTime: b.startDateTime,
          endTime: b.endDateTime,
          title: 'BLOCCO',
          subtitle: b.reason ?? 'Non disponibile',
          status: 'blocked',
          color: cs.error,
          customData: {'original': b},
        ),
      )
      .toList();

  CalendarConfig _buildCalendarConfig(
    WorkHours workHours,
    double timeColWidth,
    double minColWidth,
    double preferredColWidth,
  ) => CalendarConfig(
    viewType: CalendarViewType.day,
    dayStartHour: workHours.startHr,
    dayEndHour: workHours.endHr,
    timeSlotHeight: kIsWindows ? 50 : 50.h,
    timeColumnWidth: timeColWidth,
    resourceHeaderHeight: kIsWindows ? 60 : 60.h,
    enableDragAndDrop: false,
    enableResize: false,
    showAllDaySection: false,
    showResourceAppointmentCount: false,
    snapToMinutes: 15,
    minColumnWidth: minColWidth,
    preferredColumnWidth: preferredColWidth,
    allowOverlapping: true,
    enableSnapping: true,
    numberOfDays: 1,
    firstDayOfWeek: 1,
    timeSlotDuration: const Duration(minutes: 30),
    showWeekends: true,
  );

  Widget _buildTimeColumn(
    BuildContext context,
    DateTime time,
    double height,
    bool isHourMark,
    ColorScheme cs,
  ) {
    final isHalfHour = time.minute == 30;

    // Se è l'inizio di un'ora (es. 09:00, 15:00)
    if (isHourMark) {
      return Container(
        alignment: Alignment.topCenter,
        child: Text(
          DateFormat('HH:mm').format(time),
          style: TextStyle(
            fontSize: kIsWindows ? 16 : 16.sp,
            fontWeight: FontWeight.w600,
            color: cs.onSurfaceVariant,
            letterSpacing: 0.5,
          ),
        ),
      );
    }
    // Se è una frazione di ora (es. :15, :30, :45)
    else {
      // Se l'altezza dello slot è troppo piccola (< 14px),
      // nascondiamo il testo per non accavallarlo
      if (height < 14) return const SizedBox.shrink();

      // Per la mezz'ora mostriamo "15:30",
      // per i quarti d'ora solo ":15" e ":45"
      final labelText = isHalfHour
          ? DateFormat('HH:mm').format(time)
          : ':${time.minute.toString().padLeft(2, '0')}';

      return Container(
        alignment: Alignment.topCenter,
        padding: EdgeInsets.only(
          top: kIsWindows ? 2 : 2.h,
          right: kIsWindows ? 4 : 4.w,
        ),
        child: Text(
          labelText,
          style: TextStyle(
            fontSize: kIsWindows ? 12 : 12.sp,
            fontWeight: isHalfHour ? FontWeight.w500 : FontWeight.w400,
            color: cs.onSurfaceVariant.withValues(
              alpha: isHalfHour ? 0.8 : 0.6,
            ),
          ),
        ),
      );
    }
  }

  Widget _buildCurrentTimeIndicator(ColorScheme cs, double width) => Container(
    height: kIsWindows ? 3 : 3.h,
    width: width,
    decoration: BoxDecoration(
      color: cs.primary,
      boxShadow: [
        BoxShadow(
          color: cs.primary.withValues(alpha: 0.4),
          blurRadius: kIsWindows ? 2 : 2.r,
          offset: const Offset(0, 1),
        ),
      ],
    ),
  );

  void _handleSlotTap(
    int operatorId,
    DateTime dateTime,
    List<Operator> operators,
  ) {
    final clipboard = ref.read(clipboardAppointmentProvider);
    if (clipboard != null) {
      _showPasteOrNewDialog(dateTime, operatorId);
    } else {
      _openAppointmentDialog(
        initialOperatorId: operatorId,
        initialStart: dateTime,
      );
    }
  }

  void _showPasteOrNewDialog(DateTime dateTime, int operatorId) {
    showModalBottomSheet<void>(
      context: context,
      builder: (ctx) {
        final clipboardItem = ref.read(clipboardAppointmentProvider);
        final isCut = clipboardItem?.operation == ClipboardOperation.cut;
        final verb = isCut ? 'Sposta' : 'Incolla';

        return SafeArea(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              ListTile(
                leading: Icon(
                  isCut
                      ? Symbols.move_selection_up_rounded
                      : Symbols.content_paste_rounded,
                ),
                title: Text('$verb appuntamento'),
                onTap: () async {
                  Navigator.pop(ctx);
                  final actions = ref.read(appointmentActionsProvider);
                  await actions.pasteAppointment(
                    targetDateTime: dateTime,
                    newOperatorId: operatorId,
                  );
                  if (mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: Text(
                          'Appuntamento ${isCut ? 'spostato' : 'incollato'}',
                        ),
                      ),
                    );
                  }
                },
              ),
              ListTile(
                leading: const Icon(Symbols.add_circle_rounded),
                title: const Text('Crea nuovo appuntamento'),
                onTap: () {
                  Navigator.pop(ctx);
                  _openAppointmentDialog(
                    initialOperatorId: operatorId,
                    initialStart: dateTime,
                  );
                },
              ),
            ],
          ),
        );
      },
    );
  }

  Color _operatorColor(int operatorId) {
    final hue = (operatorId * 47) % 360;
    final lightness = operatorId.isEven ? 0.2 : 0.5;
    return HSLColor.fromAHSL(1, hue.toDouble(), 0.65, lightness).toColor();
  }

  void _openAppointmentDialog({
    AppointmentData? existingAppointment,
    int? initialOperatorId,
    DateTime? initialStart,
  }) {
    showDialog<void>(
      context: context,
      builder: (_) => AppointmentDialog(
        appointment: existingAppointment,
        initialOperatorId:
            initialOperatorId ?? existingAppointment?.operatorId ?? 1,
        initialStartTime:
            initialStart ??
            existingAppointment?.startDateTime ??
            DateTime.now(),
        initialEndTime:
            (initialStart ??
                    existingAppointment?.startDateTime ??
                    DateTime.now())
                .add(const Duration(hours: 1)),
      ),
    );
  }

  void _openBlockedSlotDialog({OperatorBlockedSlot? existingSlot}) {
    showDialog<void>(
      context: context,
      builder: (_) => BlockedSlotDialog(existingSlot: existingSlot),
    );
  }
}

class _OperatorHeader extends StatelessWidget {
  const _OperatorHeader({required this.resource, required this.width});

  final CalendarResource resource;
  final double width;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final color = resource.color ?? cs.primary;

    return Container(
      width: width - (kIsWindows ? 8 : 8.w),
      // 8 size scrollbar calendar theme
      alignment: Alignment.center,
      margin: EdgeInsets.symmetric(
        vertical: kIsWindows ? 6 : 6.h,
        horizontal: kIsWindows ? 4 : 4.w,
      ),
      padding: EdgeInsets.symmetric(
        vertical: kIsWindows ? 4 : 4.h,
        horizontal: kIsWindows ? 8 : 8.w,
      ),
      decoration: BoxDecoration(
        color: cs.surfaceContainerHigh,
        borderRadius: BorderRadius.circular(kIsWindows ? 14 : 14.r),
        border: Border.all(color: cs.outlineVariant.withValues(alpha: 0.5)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.05),
            blurRadius: kIsWindows ? 4 : 4.r,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            padding: EdgeInsets.all(kIsWindows ? 2 : 2.w),
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              border: Border.all(
                color: color.withValues(alpha: 0.3),
                width: kIsWindows ? 1.5 : 1.5.w,
              ),
            ),
            child: CircleAvatar(
              radius: kIsWindows ? 15 : 14.r,
              backgroundColor: color,
              child: Text(
                _getInitials(resource.name),
                style: TextStyle(
                  color: color.computeLuminance() > 0.5
                      ? Colors.black
                      : Colors.white,
                  fontSize: kIsWindows ? 12 : 12.sp,
                  fontWeight: FontWeight.w900,
                ),
              ),
            ),
          ),
          SizedBox(width: kIsWindows ? 10 : 10.w),
          Flexible(
            child: Text(
              resource.name,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                fontWeight: FontWeight.w700,
                fontSize: kIsWindows ? 24 : 18.sp,
                color: cs.onSurface,
              ),
            ),
          ),
        ],
      ),
    );
  }

  String _getInitials(String name) {
    final parts = name.trim().split(' ');
    if (parts.length > 1) return '${parts[0][0]}${parts[1][0]}'.toUpperCase();
    return parts[0].substring(0, (parts[0].length >= 2 ? 2 : 1)).toUpperCase();
  }
}

class _AppointmentTile extends StatelessWidget {
  const _AppointmentTile({
    required this.appointment,
    required this.appointmentModel,
    required this.rect,
    required this.onTap,
    this.client,
    this.cabin,
  });

  final AppointmentData appointment;
  final CalendarAppointment appointmentModel;
  final Rect rect;
  final VoidCallback onTap;
  final Client? client;
  final Cabin? cabin;

  @override
  Widget build(BuildContext context) {
    final height = rect.height;
    final isVerySmall = height < (kIsWindows ? 25 : 25.h);
    final isSmall = height < (kIsWindows ? 45 : 45.h);
    final isMedium = height < (kIsWindows ? 65 : 65.h);

    return Tooltip(
      message: _buildTooltipText(),
      child: GestureDetector(
        onTap: onTap,
        child: DecoratedBox(
          decoration: BoxDecoration(
            color: appointmentModel.color,
            borderRadius: BorderRadius.circular(kIsWindows ? 8 : 8.r),
            boxShadow: [
              BoxShadow(
                color: appointmentModel.color.withValues(alpha: 0.3),
                blurRadius: kIsWindows ? 3 : 3.r,
                offset: const Offset(0, 2),
              ),
            ],
          ),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(kIsWindows ? 8 : 8.r),
            child: Stack(
              children: [
                Padding(
                  padding: EdgeInsets.fromLTRB(
                    kIsWindows ? 8 : 8.w,
                    kIsWindows ? 4 : 4.h,
                    kIsWindows ? 6 : 6.w,
                    kIsWindows ? 4 : 4.h,
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      if (!isVerySmall)
                        Row(
                          children: [
                            Expanded(
                              child: Text(
                                appointmentModel.title,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: TextStyle(
                                  color:
                                      appointmentModel.color
                                              .computeLuminance() >
                                          0.5
                                      ? Colors.black
                                      : Colors.white,
                                  fontWeight: FontWeight.w800,
                                  fontSize: kIsWindows ? 12 : 12.sp,
                                ),
                              ),
                            ),
                          ],
                        ),
                      if (!isSmall)
                        Padding(
                          padding: EdgeInsets.only(top: kIsWindows ? 2 : 2.h),
                          child: Text(
                            '', // Feature: Display services from AppointmentServicesTable (pending)
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              color:
                                  appointmentModel.color.computeLuminance() >
                                      0.5
                                  ? Colors.black
                                  : Colors.white,
                              fontWeight: FontWeight.w600,
                              fontSize: kIsWindows ? 12 : 12.sp,
                            ),
                          ),
                        ),
                      const Spacer(),
                      if (!isMedium)
                        Row(
                          children: [
                            Icon(
                              Symbols.door_front_rounded,
                              size: kIsWindows ? 18 : 14.sp,
                              color:
                                  appointmentModel.color.computeLuminance() >
                                      0.5
                                  ? Colors.black
                                  : Colors.white,
                              fill: 1,
                            ),
                            SizedBox(width: kIsWindows ? 3 : 3.w),
                            Text(
                              'Cab. ${cabin?.id ?? appointment.cabinId}',
                              style: TextStyle(
                                color:
                                    appointmentModel.color.computeLuminance() >
                                        0.5
                                    ? Colors.black
                                    : Colors.white,
                                fontWeight: FontWeight.w600,
                                fontSize: kIsWindows ? 12 : 11.sp,
                              ),
                            ),
                            const Spacer(),
                            Text(
                              '${_formatTime(appointment.startDateTime)} - ${_formatTime(appointment.endDateTime)}',
                              style: TextStyle(
                                color:
                                    appointmentModel.color.computeLuminance() >
                                        0.5
                                    ? Colors.black
                                    : Colors.white,
                                fontWeight: FontWeight.w600,
                                fontSize: kIsWindows ? 12 : 11.sp,
                              ),
                            ),
                          ],
                        ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  String _formatTime(DateTime dt) =>
      '${dt.hour}:${dt.minute.toString().padLeft(2, '0')}';

  String _buildTooltipText() => [
    '👤 Cliente: ${client != null ? '${client!.firstName} ${client!.lastName}' : 'N/D'}',
    //'💆 Servizio: ${appointment.service}',
    '🚪 Cabina: ${cabin?.id ?? appointment.cabinId}',
    '🕒 Orario: ${_formatTime(appointment.startDateTime)} - ${_formatTime(appointment.endDateTime)}',
    if (client?.phoneNumber != null) '📞 Tel: ${client!.phoneNumber}',
    if (appointment.notes?.isNotEmpty == true) '📝 Note: ${appointment.notes}',
  ].join('\n');
}

class _BlockedSlotTile extends StatelessWidget {
  const _BlockedSlotTile({
    required this.blockedSlot,
    required this.appointmentModel,
    required this.rect,
    required this.onTap,
  });

  final OperatorBlockedSlot blockedSlot;
  final CalendarAppointment appointmentModel;
  final Rect rect;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => Tooltip(
    message: '⛔ BLOCCATO\nMotivo: ${blockedSlot.reason ?? 'N/D'}',
    child: GestureDetector(
      onTap: onTap,
      child: DecoratedBox(
        decoration: BoxDecoration(
          color: appointmentModel.color.withValues(alpha: 0.35),
          borderRadius: BorderRadius.circular(kIsWindows ? 8 : 8.r),
          border: Border.all(
            color: appointmentModel.color.withValues(alpha: 0.5),
          ),
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(kIsWindows ? 8 : 8.r),
          child: Stack(
            children: [
              Positioned.fill(
                child: CustomPaint(
                  painter: _StripePainter(
                    color: appointmentModel.color.withValues(alpha: 0.35),
                  ),
                ),
              ),
              Center(
                child: Icon(
                  Symbols.block_rounded,
                  size: rect.height > 30 ? 38 : 24.sp,
                  color: Colors.red,
                  fill: 1,
                ),
              ),
            ],
          ),
        ),
      ),
    ),
  );
}

class _StripePainter extends CustomPainter {
  _StripePainter({required this.color});

  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color
      ..strokeWidth = kIsWindows ? 2 : 2.w;

    const gap = 8.0;
    for (var i = -size.height; i < size.width; i += gap) {
      canvas.drawLine(
        Offset(i, 0),
        Offset(i + size.height, size.height),
        paint,
      );
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
