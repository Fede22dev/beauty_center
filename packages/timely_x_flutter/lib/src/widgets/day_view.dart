// lib/src/widgets/day_view.dart

import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';
import 'package:intl/intl.dart';
import 'package:timely_x/src/gestures/grid_gesture_detector.dart';
import 'package:timely_x/timely_x.dart';

import '../utils/date_time_utils.dart';
import '../utils/overlap_calculator.dart';
import 'appointment_widget.dart';
import 'grid_painter.dart';
import 'resource_header.dart';
import 'scroll_navigation_wrapper.dart';
import 'slot_highlight_painter.dart';

/// Calendar day view - shows all resources for a single day
class CalendarDayView extends StatefulWidget {
  const CalendarDayView({
    super.key,
    required this.controller,
    required this.config,
    required this.theme,
    this.resourceHeaderBuilder,
    this.timeColumnBuilder,
    this.appointmentBuilder,
    this.emptyCellBuilder,
    this.currentTimeIndicatorBuilder,
    this.onAppointmentTap,
    this.onAppointmentLongPress,
    this.onAppointmentSecondaryTap,
    this.onCellTap,
    this.onCellLongPress,
    this.onAppointmentDragEnd,
    this.onResourceHeaderTap,
  });

  final CalendarController controller;
  final CalendarConfig config;
  final CalendarTheme theme;

  // Builders
  final ResourceHeaderBuilder? resourceHeaderBuilder;
  final TimeColumnBuilder? timeColumnBuilder;
  final AppointmentBuilder? appointmentBuilder;
  final EmptyCellBuilder? emptyCellBuilder;
  final CurrentTimeIndicatorBuilder? currentTimeIndicatorBuilder;

  // Callbacks
  final OnAppointmentTap? onAppointmentTap;
  final OnAppointmentLongPress? onAppointmentLongPress;
  final OnAppointmentSecondaryTap? onAppointmentSecondaryTap;
  final OnCellTap? onCellTap;
  final OnCellLongPress? onCellLongPress;
  final OnAppointmentDragEnd? onAppointmentDragEnd;
  final OnResourceHeaderTap? onResourceHeaderTap;

  @override
  State<CalendarDayView> createState() => _CalendarDayViewState();
}

class _CalendarDayViewState extends State<CalendarDayView> {
  late ScrollController _gridVerticalController;
  late ScrollController _gridHorizontalController;
  late ScrollController _timeColumnVerticalController;
  late ScrollController _resourceHeaderHorizontalController;
  late ScrollController _dateHeaderHorizontalController;

  double _columnWidth = 0;
  bool _needsHorizontalScroll = false;
  bool _isUpdatingScroll = false;

  int? _verticalSyncCallbackId;

  ScrollController? _horizontalScrollSource;

  Timer? _minuteTimer;

  @override
  void initState() {
    super.initState();

    _gridVerticalController = ScrollController();
    _gridHorizontalController = ScrollController();
    _timeColumnVerticalController = ScrollController();
    _resourceHeaderHorizontalController = ScrollController();
    _dateHeaderHorizontalController = ScrollController();

    _gridVerticalController.addListener(_onGridVerticalScroll);
    _gridHorizontalController.addListener(_onGridHorizontalScroll);
    _resourceHeaderHorizontalController.addListener(
      _onResourceHeaderHorizontalScroll,
    );
    _dateHeaderHorizontalController.addListener(_onDateHeaderHorizontalScroll);

    widget.controller.addListener(_onControllerUpdate);
    widget.controller.onScrollToTimeCallback = _scrollToTime;

    _startCurrentTimeTimer();
  }

  void _startCurrentTimeTimer() {
    _minuteTimer = Timer.periodic(const Duration(minutes: 1), (_) {
      if (DateTimeUtils.isToday(widget.controller.currentDate) && mounted) {
        setState(() {});
      }
    });
  }

  @override
  void dispose() {
    if (_verticalSyncCallbackId != null) {
      SchedulerBinding.instance.cancelFrameCallbackWithId(
        _verticalSyncCallbackId!,
      );
    }

    _gridVerticalController.removeListener(_onGridVerticalScroll);
    _gridHorizontalController.removeListener(_onGridHorizontalScroll);
    _resourceHeaderHorizontalController.removeListener(
      _onResourceHeaderHorizontalScroll,
    );
    _dateHeaderHorizontalController.removeListener(
      _onDateHeaderHorizontalScroll,
    );

    _gridVerticalController.dispose();
    _gridHorizontalController.dispose();
    _timeColumnVerticalController.dispose();
    _resourceHeaderHorizontalController.dispose();
    _dateHeaderHorizontalController.dispose();

    widget.controller.removeListener(_onControllerUpdate);

    if (widget.controller.onScrollToTimeCallback == _scrollToTime) {
      widget.controller.onScrollToTimeCallback = null;
    }

    _minuteTimer?.cancel();
    super.dispose();
  }

  void _onGridVerticalScroll() {
    if (_isUpdatingScroll) return;
    _syncVerticalScrollImmediate();
  }

  void _syncVerticalScrollImmediate() {
    if (_isUpdatingScroll) return;

    _isUpdatingScroll = true;

    if (!_gridVerticalController.hasClients ||
        !_timeColumnVerticalController.hasClients) {
      _isUpdatingScroll = false;
      return;
    }

    final offset = _gridVerticalController.position.pixels;
    _timeColumnVerticalController.jumpTo(offset);

    _isUpdatingScroll = false;
  }

  void _onGridHorizontalScroll() {
    if (_isUpdatingScroll) return;
    _horizontalScrollSource = _gridHorizontalController;
    _syncHorizontalScrollImmediate();
  }

  void _onResourceHeaderHorizontalScroll() {
    if (_isUpdatingScroll) return;
    _horizontalScrollSource = _resourceHeaderHorizontalController;
    _syncHorizontalScrollImmediate();
  }

  void _onDateHeaderHorizontalScroll() {
    if (_isUpdatingScroll) return;
    _horizontalScrollSource = _dateHeaderHorizontalController;
    _syncHorizontalScrollImmediate();
  }

  void _syncHorizontalScrollImmediate() {
    if (_isUpdatingScroll) return;

    _isUpdatingScroll = true;
    final source = _horizontalScrollSource;

    if (source == null || !source.hasClients) {
      _isUpdatingScroll = false;
      return;
    }

    final targetOffset = source.position.pixels;
    final targets = <ScrollController>[
      if (_gridHorizontalController.hasClients &&
          _gridHorizontalController != source)
        _gridHorizontalController,
      if (_resourceHeaderHorizontalController.hasClients &&
          _resourceHeaderHorizontalController != source)
        _resourceHeaderHorizontalController,
      if (_dateHeaderHorizontalController.hasClients &&
          _dateHeaderHorizontalController != source)
        _dateHeaderHorizontalController,
    ];

    for (final target in targets) {
      if (target.hasClients) {
        final currentOffset = target.position.pixels;
        if ((currentOffset - targetOffset).abs() > 0.1) {
          target.jumpTo(targetOffset);
        }
      }
    }

    _isUpdatingScroll = false;
  }

  void _onControllerUpdate() {
    setState(() {});
  }

  void _calculateColumnWidth(double viewportWidth) {
    final dimensions = widget.config.calculateColumnDimensions(
      viewportWidth: viewportWidth,
      numberOfResources: widget.controller.filteredResources.length,
      effectiveNumberOfDays: widget.controller.effectiveNumberOfDays,
    );

    _columnWidth = dimensions.columnWidth;
    _needsHorizontalScroll = dimensions.requiresHorizontalScroll;
  }

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        _calculateColumnWidth(constraints.maxWidth);

        return Column(
          children: [
            _buildHeader(),
            Expanded(child: _buildBody()),
          ],
        );
      },
    );
  }

  Widget _buildHeader() {
    final resources = widget.controller.filteredResources;
    final currentDate = widget.controller.currentDate;

    return SizedBox(
      height: widget.config.resourceHeaderHeight,
      child: Row(
        children: [
          Container(
            width: widget.config.timeColumnWidth,
            decoration: BoxDecoration(
              color: widget.theme.headerBackgroundColor,
              border: Border(
                right: BorderSide(color: widget.theme.gridLineColor, width: 1),
                bottom: BorderSide(color: widget.theme.hourLineColor, width: 2),
              ),
              boxShadow: widget.theme.headerShadow,
            ),
            child: Center(
              child: Text(
                DateFormat(
                  'EEE\nMMM d',
                  'it',
                ).format(widget.controller.currentDate).toUpperCase(),
                textAlign: TextAlign.center,
                style: widget.theme.weekdayTextStyle,
              ),
            ),
          ),
          Expanded(
            child: ScrollNavigationWrapper(
              child: SingleChildScrollView(
                controller: _resourceHeaderHorizontalController,
                scrollDirection: Axis.horizontal,
                physics: _needsHorizontalScroll
                    ? const AlwaysScrollableScrollPhysics()
                    : const NeverScrollableScrollPhysics(),
                child: Row(
                  children: resources.map((resource) {
                    return ResourceHeader(
                      resource: resource,
                      width: _columnWidth,
                      theme: widget.theme,
                      builder: widget.resourceHeaderBuilder,
                      onTap: widget.onResourceHeaderTap,
                      date: currentDate,
                      controller: widget.controller,
                      config: widget.config,
                    );
                  }).toList(),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildBody() {
    return Row(
      children: [
        Container(
          width: widget.config.timeColumnWidth,
          decoration: BoxDecoration(
            color: widget.theme.timeColumnBackgroundColor,
            border: Border(
              right: BorderSide(color: widget.theme.gridLineColor, width: 1),
            ),
            boxShadow: widget.theme.headerShadow,
          ),
          child: SingleChildScrollView(
            controller: _timeColumnVerticalController,
            physics: const NeverScrollableScrollPhysics(),
            child: Stack(
              clipBehavior: Clip.none,
              children: [
                _buildTimeLabels(),
                // Disegniamo la pillola sopra agli orari della colonna
                if (_shouldShowCurrentTimeIndicator()) _buildTimeColumnPill(),
              ],
            ),
          ),
        ),
        Expanded(child: _buildGridWithScrollbar()),
      ],
    );
  }

  Widget _buildGridWithScrollbar() {
    return RawScrollbar(
      controller: _gridVerticalController,
      thumbVisibility: widget.theme.scrollbarTheme.scrollbarAlwaysVisible,
      trackVisibility: widget.theme.scrollbarTheme.scrollbarAlwaysVisible,
      thickness: widget.theme.scrollbarTheme.scrollbarThickness,
      radius: widget.theme.scrollbarTheme.scrollbarRadius,
      thumbColor: widget.theme.scrollbarTheme.scrollbarThumbColor,
      trackColor: widget.theme.scrollbarTheme.scrollbarTrackColor,
      trackBorderColor: widget.theme.scrollbarTheme.scrollbarTrackBorderColor,
      child: _buildGrid(),
    );
  }

  Widget _buildTimeLabels() {
    final slots = <Widget>[];
    final hours = widget.config.dayEndHour - widget.config.dayStartHour;
    final slotsPerHour = 60 ~/ widget.config.timeSlotDuration.inMinutes;
    final slotMinutes = widget.config.timeSlotDuration.inMinutes;
    final currentDate = widget.controller.currentDate;

    for (int i = 0; i < hours * slotsPerHour; i++) {
      final hour = widget.config.dayStartHour + (i ~/ slotsPerHour);
      final minute = (i % slotsPerHour) * slotMinutes;

      // FIX 1: Usa la data REALE, non il 2000-01-01 per dare al builder un contesto vero
      final time = DateTime(
        currentDate.year,
        currentDate.month,
        currentDate.day,
        hour,
        minute,
      );
      final slotHeight = widget.config.hourHeight / slotsPerHour;

      // Default implementation se non c'è il builder
      final isHourMark = minute == 0;
      final isHalfHour = minute == 30;

      // FIX 2: Implementato l'utilizzo del timeColumnBuilder
      if (widget.timeColumnBuilder != null) {
        slots.add(
          SizedBox(
            height: slotHeight,
            width: double.infinity,
            child: widget.timeColumnBuilder!(
              context,
              time,
              slotHeight,
              isHourMark,
            ),
          ),
        );
        continue; // Passa alla prossima cella se usa il builder custom
      }

      if (isHourMark) {
        slots.add(
          Container(
            height: slotHeight,
            alignment: Alignment.topCenter,
            padding: widget.theme.timeLabelPadding,
            child: Text(
              DateFormat(widget.theme.timeFormat).format(time),
              style: widget.theme.timeTextStyle,
            ),
          ),
        );
      } else if (slotsPerHour > 1) {
        final showLabel = slotHeight >= 14;
        final labelText = isHalfHour
            ? DateFormat('h:mm').format(time)
            : ':${minute.toString().padLeft(2, '0')}';

        slots.add(
          Container(
            height: slotHeight,
            alignment: Alignment.topCenter,
            padding: const EdgeInsets.only(top: 2, right: 4),
            child: showLabel
                ? Text(
                    labelText,
                    style: widget.theme.subHourTimeTextStyle,
                    overflow: TextOverflow.clip,
                  )
                : const SizedBox.shrink(),
          ),
        );
      } else {
        slots.add(SizedBox(height: slotHeight));
      }
    }

    return Column(children: slots);
  }

  Widget _buildGrid() {
    final resources = widget.controller.filteredResources;
    final currentDate = widget.controller.currentDate;
    final totalWidth = _columnWidth * resources.length;
    final totalHeight = widget.config.totalGridHeight;

    final flatResources = resources;
    final flatDates = List.filled(resources.length, currentDate);

    return SingleChildScrollView(
      controller: _gridVerticalController,
      physics: const AlwaysScrollableScrollPhysics(),
      child: ScrollNavigationWrapper(
        child: SingleChildScrollView(
          controller: _gridHorizontalController,
          scrollDirection: Axis.horizontal,
          physics: _needsHorizontalScroll
              ? const AlwaysScrollableScrollPhysics()
              : const NeverScrollableScrollPhysics(),
          child: SizedBox(
            width: totalWidth,
            height: totalHeight,
            child: GridGestureDetector(
              config: widget.config,
              controller: widget.controller,
              columnWidth: _columnWidth,
              resources: flatResources,
              dates: flatDates,
              verticalScrollOffset: _gridVerticalController.hasClients
                  ? _gridVerticalController.position.pixels
                  : 0.0,
              horizontalScrollOffset: _gridHorizontalController.hasClients
                  ? _gridHorizontalController.position.pixels
                  : 0.0,
              onCellTap: widget.onCellTap,
              onCellLongPress: widget.onCellLongPress,
              onAppointmentDragEnd: widget.onAppointmentDragEnd,
              child: Stack(
                clipBehavior: Clip.none,
                children: [
                  RepaintBoundary(
                    child: Stack(
                      clipBehavior: Clip.none,
                      children: [
                        CustomPaint(
                          size: Size(totalWidth, totalHeight),
                          painter: GridPainter(
                            config: widget.config,
                            theme: widget.theme,
                            numberOfColumns: resources.length,
                            columnWidth: _columnWidth,
                          ),
                        ),
                        ..._buildEmptyCells(resources),
                      ],
                    ),
                  ),

                  ..._buildUnavailabilityLayers(resources),
                  ..._buildAppointments(resources),

                  if (_shouldShowCurrentTimeIndicator())
                    _buildCurrentTimeIndicator(totalWidth),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  List<Widget> _buildEmptyCells(List<CalendarResource> resources) {
    if (widget.emptyCellBuilder == null) return [];

    final widgets = <Widget>[];
    final currentDate = widget.controller.currentDate;
    final hours = widget.config.dayEndHour - widget.config.dayStartHour;
    final slotsPerHour = 60 ~/ widget.config.timeSlotDuration.inMinutes;
    final slotMinutes = widget.config.timeSlotDuration.inMinutes;

    for (int i = 0; i < resources.length; i++) {
      final resource = resources[i];
      for (int j = 0; j < hours * slotsPerHour; j++) {
        final hour = widget.config.dayStartHour + (j ~/ slotsPerHour);
        final minute = (j % slotsPerHour) * slotMinutes;
        final cellTime = DateTime(
          currentDate.year,
          currentDate.month,
          currentDate.day,
          hour,
          minute,
        );

        final slotHeight = widget.config.hourHeight / slotsPerHour;
        final topOffset = (j * slotHeight);
        final leftOffset = i * _columnWidth;

        // Generiamo il widget custom passando i 4 parametri corretti (incluso il Rect)
        final customCellWidget = widget.emptyCellBuilder!(
          context,
          resource,
          cellTime,
          Rect.fromLTWH(leftOffset, topOffset, _columnWidth, slotHeight),
        );

        // Aggiungiamo alla vista SOLO se il builder non ritorna null
        if (customCellWidget != null) {
          widgets.add(
            Positioned(
              left: leftOffset,
              top: topOffset,
              width: _columnWidth,
              height: slotHeight,
              child: customCellWidget,
            ),
          );
        }
      }
    }
    return widgets;
  }

  List<Widget> _buildUnavailabilityLayers(List<CalendarResource> resources) {
    final widgets = <Widget>[];
    final currentDate = widget.controller.currentDate;

    for (int i = 0; i < resources.length; i++) {
      final resource = resources[i];
      final availabilityMode = resource.getAvailabilityMode();

      if (availabilityMode == AvailabilityMode.businessHours) {
        BusinessHours? businessHours;
        if (resource is CalendarResourceWithBusinessHours) {
          businessHours = resource.businessHours;
        }

        if (businessHours == null) continue;

        final unavailabilities =
            BusinessHoursCalculator.getUnavailabilityPeriods(
              businessHours: businessHours,
              date: currentDate,
              config: widget.config,
              themeStyle: widget.theme.unavailabilityStyle,
            );

        if (unavailabilities.isEmpty) continue;

        widgets.add(
          Positioned(
            left: i * _columnWidth,
            top: 0,
            width: _columnWidth,
            height: widget.config.totalGridHeight,
            child: CustomPaint(
              painter: UnavailabilityPainter(
                unavailabilityPeriods: unavailabilities,
                hourHeight: widget.config.hourHeight,
                dayStartHour: widget.config.dayStartHour,
                cellWidth: _columnWidth,
                cellLeft: 0,
              ),
            ),
          ),
        );
      } else if (availabilityMode == AvailabilityMode.slots) {
        SlotAvailability? slotAvailability;
        if (resource is CalendarResourceWithSlots) {
          slotAvailability = resource.slotAvailability;
        }

        if (slotAvailability == null) continue;

        final slots = slotAvailability.getSlotsForDate(currentDate);
        if (slots.isEmpty) continue;

        widgets.add(
          Positioned(
            left: i * _columnWidth,
            top: 0,
            width: _columnWidth,
            height: widget.config.totalGridHeight,
            child: CustomPaint(
              painter: SlotHighlightPainter(
                slots: slots,
                config: slotAvailability.highlightConfig,
                hourHeight: widget.config.hourHeight,
                dayStartHour: widget.config.dayStartHour,
                cellWidth: _columnWidth,
                cellLeft: 0,
              ),
            ),
          ),
        );
      }
    }

    return widgets;
  }

  List<Widget> _buildAppointments(List<CalendarResource> resources) {
    final widgets = <Widget>[];
    final currentDate = widget.controller.currentDate;

    for (int i = 0; i < resources.length; i++) {
      final resource = resources[i];
      final appointments = widget.controller.getAppointmentsForResourceDate(
        resource.id,
        currentDate,
      );

      if (appointments.isEmpty) continue;

      final dayStart = DateTime(
        currentDate.year,
        currentDate.month,
        currentDate.day,
        widget.config.dayStartHour,
      );

      final positions = OverlapCalculator.calculatePositions(
        appointments: appointments,
        cellWidth: _columnWidth,
        cellLeft: i * _columnWidth,
        hourHeight: widget.config.hourHeight,
        dayStart: dayStart,
      );

      for (final position in positions) {
        widgets.add(
          AppointmentWidget(
            key: ValueKey(position.appointment.id),
            position: position,
            resource: resource,
            theme: widget.theme,
            isSelected:
                widget.controller.selectedAppointment?.id ==
                position.appointment.id,
            builder: widget.appointmentBuilder,
            onTap: widget.onAppointmentTap,
            onLongPress: widget.onAppointmentLongPress,
            onSecondaryTap: widget.onAppointmentSecondaryTap,
            enableDrag: widget.config.enableDragAndDrop,
          ),
        );
      }
    }

    return widgets;
  }

  bool _shouldShowCurrentTimeIndicator() {
    return DateTimeUtils.isToday(widget.controller.currentDate);
  }

  Widget _buildCurrentTimeIndicator(double width) {
    final now = DateTime.now();
    final dayStart = DateTime(
      now.year,
      now.month,
      now.day,
      widget.config.dayStartHour,
    );

    final offset = DateTimeUtils.calculateVerticalOffset(
      time: now,
      dayStart: dayStart,
      hourHeight: widget.config.hourHeight,
    );

    Widget indicatorContent;

    if (widget.currentTimeIndicatorBuilder != null) {
      indicatorContent = widget.currentTimeIndicatorBuilder!(context, width);
    } else {
      // Linea di default (se non passi un builder dal tuo file)
      indicatorContent = Container(
        width: width,
        height: 2,
        color: widget.theme.currentTimeIndicatorColor,
      );
    }

    return Positioned(left: 0, top: offset - 1, child: indicatorContent);
  }

  Widget _buildTimeColumnPill() {
    final now = DateTime.now();
    final dayStart = DateTime(
      now.year,
      now.month,
      now.day,
      widget.config.dayStartHour,
    );

    final offset = DateTimeUtils.calculateVerticalOffset(
      time: now,
      dayStart: dayStart,
      hourHeight: widget.config.hourHeight,
    );

    final timeString = DateFormat('HH:mm').format(now);
    const pillHeight = 20.0;

    return Positioned(
      left: 16,
      right: 1,
      top: offset - (pillHeight / 2),
      child: Container(
        height: pillHeight,
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: widget.theme.currentTimeIndicatorColor,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: Theme.of(context).colorScheme.surface,
            width: 2,
          ),
        ),
        child: Text(
          timeString,
          textHeightBehavior: const TextHeightBehavior(
            applyHeightToFirstAscent: false,
            applyHeightToLastDescent: false,
          ),
          style: TextStyle(
            color: Theme.of(context).colorScheme.surface,
            fontSize: 12,
            fontWeight: FontWeight.w700,
            height: 1,
          ),
        ),
      ),
    );
  }

  void _scrollToTime(DateTime time) {
    if (!_gridVerticalController.hasClients) return;

    final dayStart = DateTime(
      time.year,
      time.month,
      time.day,
      widget.config.dayStartHour,
    );

    // Calcoliamo la posizione Y esatta dell'ora (lo stesso calcolo che fa la linea rossa)
    final offset = DateTimeUtils.calculateVerticalOffset(
      time: time,
      dayStart: dayStart,
      hourHeight: widget.config.hourHeight,
    );

    final viewportHeight = _gridVerticalController.position.viewportDimension;
    final maxScroll = _gridVerticalController.position.maxScrollExtent;

    // Sottraiamo la metà dello schermo per far sì che la linea appaia ESATTAMENTE al centro
    double targetOffset = offset - (viewportHeight / 2);

    // Impediamo che il calcolo superi i limiti della griglia (inizio giornata o fine giornata)
    targetOffset = targetOffset.clamp(0.0, maxScroll);

    final currentOffset = _gridVerticalController.position.pixels;

    // Se la differenza tra dove siamo e dove vogliamo andare è minore di 2 pixel,
    // significa che siamo già centrati, quindi fermiamo l'esecuzione
    if ((currentOffset - targetOffset).abs() < 2.0) {
      return;
    }

    // Animazione fluida
    _gridVerticalController.animateTo(
      targetOffset,
      duration: const Duration(milliseconds: 100),
      curve: Curves.easeInOut,
    );
  }
}
