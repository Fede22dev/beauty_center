//file: appointments_agenda.dart
import 'dart:async';
import 'dart:math' as math;

import 'package:beauty_center/features/settings/presentation/providers/settings_provider.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:intl/intl.dart';
import 'package:material_symbols_icons/symbols.dart';
import 'package:syncfusion_flutter_datepicker/datepicker.dart';

import '../../../../../core/constants/app_constants.dart';
import '../../../../../core/localizations/utils_regions/italy_holidays.dart';

// =============================================================================
// MODELS & DATA
// =============================================================================

/// Represents a single appointment with client info, timing, and service details
class Appointment {
  Appointment({
    required this.id,
    required this.operatorId,
    required this.clientName,
    required this.service,
    required this.startTime,
    required this.endTime,
    this.color,
  });

  final String id;
  final String operatorId;
  final String clientName;
  final String service;
  final DateTime startTime;
  final DateTime endTime;
  final Color? color;

  Appointment copyWith({
    final String? id,
    final String? operatorId,
    final String? clientName,
    final String? service,
    final DateTime? startTime,
    final DateTime? endTime,
    final Color? color,
  }) => Appointment(
    id: id ?? this.id,
    operatorId: operatorId ?? this.operatorId,
    clientName: clientName ?? this.clientName,
    service: service ?? this.service,
    startTime: startTime ?? this.startTime,
    endTime: endTime ?? this.endTime,
    color: color ?? this.color,
  );
}

/// Layout information for positioning overlapping appointments
class AppointmentLayout {
  AppointmentLayout({
    required this.appointment,
    required this.columnIndex,
    required this.totalColumns,
    required this.leftOffset,
    required this.width,
  });

  final Appointment appointment;
  final int columnIndex;
  final int totalColumns;
  final double leftOffset;
  final double width;
}

/// Represents an operator/staff member with their schedule
class Operator {
  Operator({required this.id, required this.name, required this.color});

  final String id;
  final String name;
  final Color color;
}

/// Time slot granularity levels with corresponding heights
enum SlotGranularity {
  minutes30(30, 60),
  minutes15(15, 80),
  minutes10(10, 100),
  minutes5(5, 120);

  const SlotGranularity(this.minutes, this.slotHeight);

  final int minutes;
  final double slotHeight;

  SlotGranularity zoomIn() => switch (this) {
    minutes30 => minutes15,
    minutes15 => minutes10,
    minutes10 => minutes5,
    minutes5 => minutes5,
  };

  SlotGranularity zoomOut() => switch (this) {
    minutes30 => minutes30,
    minutes15 => minutes30,
    minutes10 => minutes15,
    minutes5 => minutes10,
  };
}

// =============================================================================
// MAIN WIDGET
// =============================================================================

class AppointmentsAgenda extends ConsumerStatefulWidget {
  const AppointmentsAgenda({super.key});

  @override
  ConsumerState<AppointmentsAgenda> createState() => _AppointmentsAgendaState();
}

class _AppointmentsAgendaState extends ConsumerState<AppointmentsAgenda>
    with SingleTickerProviderStateMixin {
  late DateTime _selectedDay;
  late SlotGranularity _granularity;
  late ScrollController _verticalScrollController;
  late ScrollController _horizontalScrollController;
  late AnimationController _pageTransitionController;
  Timer? _currentTimeTimer;
  Timer? _inactivityTimer; // CHANGED: Added inactivity timer
  var _currentTime = DateTime.now();

  // Clipboard for copy/cut/paste operations
  Appointment? _clipboardAppointment;

  // Zoom animation scale
  double _currentZoomScale = 1;

  // Hovered slot during drag operations
  String? _hoveredSlotKey;

  // CUSTOMIZATION POINT: Working hours configuration
  static const _startHour = 6;
  static const _endHour = 22;

  // CUSTOMIZATION POINT: Timeline width
  static const double _timelineWidth = 40;

  // CUSTOMIZATION POINT: Minimum operator column width
  // Android: 120-150px, Windows: 180-200px
  static double get _minOperatorColumnWidth => kIsWindows ? 180.0 : 120.0;

  // CUSTOMIZATION POINT: Maximum visible operators before horizontal scroll (Android only)
  static const _maxVisibleOperatorsAndroid = 3;

  // CUSTOMIZATION POINT: Appointment padding
  static const double _appointmentVerticalPadding = 2;
  static const double _appointmentHorizontalPadding = 4;

  // CUSTOMIZATION POINT: Drag start delay (milliseconds)
  static const _dragStartDelay = 2500; // CHANGED: Now properly used

  // CUSTOMIZATION POINT: Inactivity timeout before auto-scroll (minutes)
  static const _inactivityTimeoutMinutes = 1; // CHANGED: Added configuration

  // Mock data - TODO: Replace with real data from provider/repository
  final _operators = <Operator>[
    Operator(id: '1', name: 'Maria', color: Colors.pink),
    Operator(id: '2', name: 'FFFF', color: Colors.cyan),
    Operator(id: '3', name: 'CCVV', color: Colors.yellow),
    Operator(id: '4', name: 'DA', color: Colors.green),
    Operator(id: '5', name: 'CCVGGGGGEEEV', color: Colors.blue),
  ];

  final _appointments = <Appointment>[
    Appointment(
      id: '1',
      operatorId: '1',
      clientName: 'Cliente 1',
      service: 'Taglio',
      startTime: DateTime.now().copyWith(hour: 7, minute: 0),
      endTime: DateTime.now().copyWith(hour: 7, minute: 30),
    ),
    Appointment(
      id: '2',
      operatorId: '2',
      clientName: 'Cliente 2',
      service: 'Colore',
      startTime: DateTime.now().copyWith(hour: 7, minute: 30),
      endTime: DateTime.now().copyWith(hour: 8, minute: 0),
    ),
    Appointment(
      id: '3',
      operatorId: '2',
      clientName: 'Cliente 3',
      service: 'Piega',
      startTime: DateTime.now().copyWith(hour: 8, minute: 0),
      endTime: DateTime.now().copyWith(hour: 9, minute: 0),
    ),
    Appointment(
      id: '4',
      operatorId: '3',
      clientName: 'Cliente 4',
      service: 'Manicure',
      startTime: DateTime.now().copyWith(hour: 8, minute: 0),
      endTime: DateTime.now().copyWith(hour: 8, minute: 30),
    ),
    Appointment(
      id: '5',
      operatorId: '3',
      clientName: 'Cliente 5',
      service: 'Pedicure',
      startTime: DateTime.now().copyWith(hour: 8, minute: 30),
      endTime: DateTime.now().copyWith(hour: 9, minute: 0),
    ),
    Appointment(
      id: '6',
      operatorId: '1',
      clientName: 'Cliente 6',
      service: 'Massaggio',
      startTime: DateTime.now().copyWith(hour: 10, minute: 0),
      endTime: DateTime.now().copyWith(hour: 11, minute: 0),
    ),
    Appointment(
      id: '7',
      operatorId: '1',
      clientName: 'Cliente 7',
      service: 'Trattamento',
      startTime: DateTime.now().copyWith(hour: 10, minute: 30),
      endTime: DateTime.now().copyWith(hour: 11, minute: 30),
    ),
  ];

  @override
  void initState() {
    super.initState();
    _selectedDay = _normalizeDate(DateTime.now());
    _granularity = SlotGranularity.minutes30;
    _verticalScrollController = ScrollController();
    _horizontalScrollController = ScrollController();

    _pageTransitionController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 300),
    );

    _startCurrentTimeTimer();
    _startInactivityTimer(); // CHANGED: Start inactivity monitoring

    // CHANGED: Listen to scroll events to reset inactivity timer
    _verticalScrollController.addListener(_resetInactivityTimer);

    WidgetsBinding.instance.addPostFrameCallback((_) {
      _scrollToCurrentTime();
    });
  }

  @override
  void dispose() {
    _currentTimeTimer?.cancel();
    _inactivityTimer?.cancel(); // CHANGED: Cancel inactivity timer
    _verticalScrollController
      ..removeListener(_resetInactivityTimer)
      ..dispose();
    _horizontalScrollController.dispose();
    _pageTransitionController.dispose();
    super.dispose();
  }

  /// Normalizes a date to midnight (removes time component)
  DateTime _normalizeDate(final DateTime date) =>
      DateTime(date.year, date.month, date.day);

  /// Updates current time every minute for time indicator
  void _startCurrentTimeTimer() {
    _currentTimeTimer = Timer.periodic(const Duration(minutes: 1), (
      final timer,
    ) {
      if (mounted) {
        setState(() {
          _currentTime = DateTime.now();
        });
      }
    });
  }

  // CHANGED: Start inactivity timer to auto-scroll after period of no interaction
  void _startInactivityTimer() {
    _inactivityTimer?.cancel();
    _inactivityTimer = Timer.periodic(
      Duration(minutes: _inactivityTimeoutMinutes),
      (_) {
        if (mounted && _isSameDay(DateTime.now(), _selectedDay)) {
          _scrollToCurrentTime();
        }
      },
    );
  }

  // CHANGED: Reset inactivity timer on user interaction
  void _resetInactivityTimer() {
    _startInactivityTimer();
  }

  /// Scrolls to current time indicator with animation, centered vertically
  void _scrollToCurrentTime() {
    if (!_verticalScrollController.hasClients) return;

    final now = DateTime.now();
    if (!_isSameDay(now, _selectedDay)) return;

    // CHANGED: Calculate screen height to center the indicator
    final screenHeight = MediaQuery.of(context).size.height;
    final offset = _calculateTimeOffset(now);
    final maxScroll = _verticalScrollController.position.maxScrollExtent;

    // CHANGED: Center the current time indicator vertically
    final targetScroll = math.max(
      0,
      math.min(offset - (screenHeight / 2), maxScroll),
    );
    print('Target scroll: $targetScroll');

    _verticalScrollController.animateTo(
      targetScroll.toDouble(),
      duration: const Duration(milliseconds: 300),
      curve: Curves.easeOut,
    );
  }

  /// Checks if two dates are the same day
  bool _isSameDay(final DateTime a, final DateTime b) =>
      a.year == b.year && a.month == b.month && a.day == b.day;

  /// Calculates vertical offset for a given time
  double _calculateTimeOffset(final DateTime time) {
    final minutes = (time.hour - _startHour) * 60 + time.minute;
    return minutes / _granularity.minutes * _granularity.slotHeight;
  }

  /// Calculates operator column width based on platform and screen size
  /// CHANGED: On Windows, divides space equally among operators (no horizontal scroll)
  /// CHANGED: On Android, uses minimum width with horizontal scroll if needed
  double _calculateOperatorColumnWidth(final BuildContext context) {
    final screenWidth = MediaQuery.of(context).size.width;
    final availableWidth = screenWidth - _timelineWidth - 32;

    if (kIsWindows) {
      // CHANGED: Windows - divide space equally, no scroll
      return availableWidth / _operators.length;
    } else {
      // CHANGED: Android - use minimum width, enable scroll if needed
      if (_operators.length <= _maxVisibleOperatorsAndroid) {
        return availableWidth / _operators.length;
      } else {
        return math.max(
          _minOperatorColumnWidth,
          availableWidth / _maxVisibleOperatorsAndroid,
        );
      }
    }
  }

  @override
  Widget build(final BuildContext context) {
    final operatorsAsync = ref.watch(operatorsStreamProvider);
    final workHoursAsync = ref.watch(workHoursStreamProvider);

    return operatorsAsync.when(
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (final e, final st) => Center(child: Text('Error: $e')),
      data: (final operators) {
        final colorScheme = Theme.of(context).colorScheme;

        return workHoursAsync.when(
          loading: () => const Center(child: CircularProgressIndicator()),
          error: (final e, final st) => Center(child: Text('Error: $e')),
          data: (final workHours) => Column(
            children: [
              _buildTopBar(colorScheme),
              SizedBox(height: kIsWindows ? 4 : 6.h),
              _buildCalendar(colorScheme),
            ],
          ),
        );
      },
    );
  }

  // ==========================================================================
  // TOP BAR - Date navigation and selection
  // ==========================================================================

  Widget _buildTopBar(final ColorScheme colorScheme) {
    final buttonHeight = kIsWindows ? 40.0 : 40.h;

    return Center(
      child: Container(
        width: kIsWindows ? 700 : 1.sw,
        decoration: BoxDecoration(
          color: colorScheme.surfaceContainerHighest,
          borderRadius: BorderRadius.all(
            Radius.circular(kIsWindows ? 12 : 12.r),
          ),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.08),
              blurRadius: kIsWindows ? 12 : 12.r,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        padding: EdgeInsets.symmetric(
          horizontal: kIsWindows ? 6 : 4.w,
          vertical: kIsWindows ? 6 : 4.h,
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Previous day button
            SizedBox(
              width: kIsWindows ? 100 : 50.w,
              height: buttonHeight,
              child: IconButton.filled(
                icon: Icon(
                  Symbols.arrow_back_ios_new_rounded,
                  size: kIsWindows ? 24 : 24.sp,
                  weight: 600,
                  fill: 1,
                ),
                style: FilledButton.styleFrom(
                  padding: EdgeInsets.zero,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(kIsWindows ? 10 : 10.r),
                  ),
                ),
                onPressed: () => _changeDay(-1),
              ),
            ),
            SizedBox(width: kIsWindows ? 8 : 6.w),
            // Date picker button
            Expanded(
              child: SizedBox(
                height: buttonHeight,
                child: FilledButton.icon(
                  icon: Icon(
                    Symbols.calendar_month_rounded,
                    size: kIsWindows ? 24 : 24.sp,
                    fill: 1,
                  ),
                  label: LayoutBuilder(
                    builder: (final context, final constraints) {
                      final fullText =
                          '${DateFormat('EEE', 'it_IT').format(_selectedDay).substring(0, 2).toUpperCase()} '
                          '${DateFormat('dd/MM/yy', 'it_IT').format(_selectedDay)}';
                      final shortText = DateFormat(
                        'dd/MM/yy',
                        'it_IT',
                      ).format(_selectedDay);
                      final useFull =
                          constraints.maxWidth > (kIsWindows ? 120 : 120.w);

                      return Center(
                        child: Text(
                          useFull ? fullText : shortText,
                          maxLines: 1,
                          overflow: TextOverflow.clip,
                          textAlign: TextAlign.center,
                        ),
                      );
                    },
                  ),
                  style: FilledButton.styleFrom(
                    padding: EdgeInsets.symmetric(
                      horizontal: kIsWindows ? 10 : 10.w,
                    ),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(
                        kIsWindows ? 10 : 10.r,
                      ),
                    ),
                    textStyle: TextStyle(
                      fontSize: kIsWindows ? 18 : 18.sp,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                  onPressed: () => _showDatePicker(colorScheme),
                ),
              ),
            ),
            SizedBox(width: kIsWindows ? 8 : 6.w),
            // Next day button
            SizedBox(
              width: kIsWindows ? 100 : 50.w,
              height: buttonHeight,
              child: IconButton.filled(
                icon: Icon(
                  Symbols.arrow_forward_ios_rounded,
                  size: kIsWindows ? 24 : 24.sp,
                  weight: 600,
                  fill: 1,
                ),
                style: FilledButton.styleFrom(
                  padding: EdgeInsets.zero,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(kIsWindows ? 10 : 10.r),
                  ),
                ),
                onPressed: () => _changeDay(1),
              ),
            ),
            SizedBox(width: kIsWindows ? 8 : 6.w),
            // Today button
            SizedBox(
              height: buttonHeight,
              child: FilledButton(
                onPressed: () {
                  setState(() {
                    _selectedDay = _normalizeDate(DateTime.now());
                  });
                  _scrollToCurrentTime();
                },
                style: FilledButton.styleFrom(
                  padding: EdgeInsets.symmetric(
                    horizontal: kIsWindows ? 10 : 10.w,
                  ),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(kIsWindows ? 10 : 10.r),
                  ),
                  backgroundColor:
                      _normalizeDate(DateTime.now()) == _selectedDay
                      ? colorScheme.primary.withValues(alpha: 0.2)
                      : colorScheme.primary,
                  foregroundColor: colorScheme.onPrimary,
                  textStyle: TextStyle(
                    fontSize: kIsWindows ? 18 : 18.sp,
                    fontWeight: FontWeight.w500,
                  ),
                ),
                child: const Text('OGGI'),
              ),
            ),
          ],
        ),
      ),
    );
  }

  /// Changes the selected day with transition animation
  void _changeDay(final int delta) {
    _pageTransitionController.forward(from: 0).then((_) {
      setState(() {
        _selectedDay = _normalizeDate(_selectedDay.add(Duration(days: delta)));
      });
      _pageTransitionController.reverse();
    });
  }

  /// Shows date picker dialog for selecting a specific date
  Future<void> _showDatePicker(final ColorScheme colorScheme) async {
    await showDialog<DateTime>(
      context: context,
      builder: (final context) => AlertDialog(
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(kIsWindows ? 18 : 18.r),
        ),
        backgroundColor: colorScheme.surfaceContainerHigh,
        title: Row(
          children: [
            Icon(
              Symbols.calendar_month_rounded,
              color: colorScheme.primary,
              size: kIsWindows ? 24 : 24.sp,
              weight: 500,
              fill: 1,
            ),
            SizedBox(width: kIsWindows ? 8 : 8.w),
            const Text('Seleziona una data'), // TODO: localize
          ],
        ),
        content: SizedBox(
          width: kIsWindows ? 400 : 400.w,
          height: kIsWindows ? 600 : 600.h,
          child: SfDateRangePicker(
            backgroundColor: colorScheme.surfaceContainerHigh,
            extendableRangeSelectionDirection:
                ExtendableRangeSelectionDirection.none,
            navigationDirection: DateRangePickerNavigationDirection.vertical,
            navigationMode: DateRangePickerNavigationMode.scroll,
            minDate: DateTime(kMinYearCalendar),
            maxDate: DateTime(kMaxYearCalendar, 12, 31),
            initialDisplayDate: _selectedDay,
            initialSelectedDate: _selectedDay,
            showNavigationArrow: true,
            enableMultiView: true,
            headerStyle: DateRangePickerHeaderStyle(
              backgroundColor: colorScheme.surfaceContainerHigh,
              textAlign: TextAlign.center,
              textStyle: TextStyle(fontSize: kIsWindows ? 20 : 20.sp),
            ),
            monthViewSettings: DateRangePickerMonthViewSettings(
              viewHeaderStyle: DateRangePickerViewHeaderStyle(
                backgroundColor: colorScheme.surfaceContainerHigh,
                textStyle: TextStyle(color: colorScheme.onSurface),
              ),
              firstDayOfWeek: 1,
              showTrailingAndLeadingDates: true,
              weekendDays: const [7, 1],
              specialDates: allHolidaysItaly().where((final date) {
                final today = DateTime.now();
                return !(date.year == today.year &&
                    date.month == today.month &&
                    date.day == today.day);
              }).toList(), // TODO: localize
            ),
            monthCellStyle: DateRangePickerMonthCellStyle(
              textStyle: TextStyle(fontSize: kIsWindows ? 16 : 16.sp),
              trailingDatesTextStyle: TextStyle(
                fontSize: kIsWindows ? 16 : 16.sp,
              ),
              leadingDatesTextStyle: TextStyle(
                fontSize: kIsWindows ? 16 : 16.sp,
              ),
              todayTextStyle: TextStyle(fontSize: kIsWindows ? 16 : 16.sp),
              weekendDatesDecoration: BoxDecoration(
                color: colorScheme.surfaceContainerHighest,
                borderRadius: BorderRadius.circular(kIsWindows ? 8 : 8.r),
              ),
              weekendTextStyle: TextStyle(
                color: colorScheme.tertiary,
                fontSize: kIsWindows ? 16 : 16.sp,
              ),
              specialDatesDecoration: BoxDecoration(
                color: colorScheme.surfaceContainerHighest,
                borderRadius: BorderRadius.circular(kIsWindows ? 8 : 8.r),
              ),
              specialDatesTextStyle: TextStyle(
                color: colorScheme.tertiary,
                fontSize: kIsWindows ? 16 : 16.sp,
              ),
            ),
            selectionTextStyle: TextStyle(fontSize: kIsWindows ? 16 : 16.sp),
            showTodayButton: true,
            onSelectionChanged: (final args) {
              if (args.value is DateTime) {
                Navigator.pop(context);
                setState(() {
                  _selectedDay = _normalizeDate(args.value as DateTime);
                });
              }
            },
          ),
        ),
      ),
    );
  }

  // ==========================================================================
  // CALENDAR VIEW - Main agenda display
  // ==========================================================================

  Widget _buildCalendar(final ColorScheme colorScheme) {
    final screenHeight = MediaQuery.of(context).size.height;
    final topBarHeight = kIsWindows ? 48 : 52.h;
    final availableHeight =
        screenHeight -
        topBarHeight -
        (kIsWindows ? 80 : 100.h) +
        1500.h; // TODO: Calculate proper height

    return Container(
      height: availableHeight,
      decoration: BoxDecoration(
        color: colorScheme.surfaceContainerLow,
        borderRadius: BorderRadius.circular(kIsWindows ? 16 : 16.r),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.1),
            blurRadius: kIsWindows ? 16 : 16.r,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(kIsWindows ? 16 : 16.r),
        child: _buildDayView(colorScheme),
      ),
    );
  }

  /// Builds the day view with timeline and operator columns
  /// CHANGED: Removed horizontal swipe gesture for day navigation
  Widget _buildDayView(final ColorScheme colorScheme) {
    final columnWidth = _calculateOperatorColumnWidth(context);

    return GestureDetector(
      // Pinch-to-zoom for changing time slot granularity
      onScaleStart: (_) {
        _currentZoomScale = 1.0;
        _resetInactivityTimer(); // CHANGED: Reset timer on interaction
      },
      onScaleUpdate: (final details) {
        final delta = details.scale - _currentZoomScale;
        if (delta.abs() > 0.25) {
          setState(() {
            _granularity = delta > 0
                ? _granularity.zoomIn()
                : _granularity.zoomOut();
            _currentZoomScale = details.scale;
          });
          _resetInactivityTimer(); // CHANGED: Reset timer on interaction
        }
      },
      // CHANGED: Removed horizontal drag for day change (swipe removed)
      child: Column(
        children: [
          _buildStickyHeader(colorScheme, columnWidth),
          Expanded(child: _buildScrollableContent(colorScheme, columnWidth)),
        ],
      ),
    );
  }

  /// Builds sticky header with operator names
  Widget _buildStickyHeader(
    final ColorScheme colorScheme,
    final double columnWidth,
  ) => Container(
    height: kIsWindows ? 50 : 50.h,
    decoration: BoxDecoration(
      color: colorScheme.surfaceContainerHighest,
      border: Border(bottom: BorderSide(color: colorScheme.outlineVariant)),
    ),
    child: Row(
      children: [
        const SizedBox(width: _timelineWidth),
        // CHANGED: Windows uses fixed width (no scroll), Android uses scroll if needed
        if (kIsWindows)
          // Windows: Fixed width columns
          Expanded(
            child: Row(
              children: _operators
                  .map(
                    (final operator) => Expanded(
                      child: Container(
                        decoration: BoxDecoration(
                          border: Border(
                            left: BorderSide(color: colorScheme.outlineVariant),
                          ),
                        ),
                        child: Center(
                          child: Text(
                            operator.name,
                            style: TextStyle(
                              fontSize: kIsWindows ? 16 : 16.sp,
                              fontWeight: FontWeight.w600,
                              color: colorScheme.onSurface,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ),
                    ),
                  )
                  .toList(),
            ),
          )
        else
          // Android: Scrollable columns
          Expanded(
            child: NotificationListener<ScrollNotification>(
              onNotification: (final notification) => true,
              child: SingleChildScrollView(
                controller: _horizontalScrollController,
                scrollDirection: Axis.horizontal,
                physics: const ClampingScrollPhysics(),
                child: Row(
                  children: _operators
                      .map(
                        (final operator) => Container(
                          width: columnWidth,
                          decoration: BoxDecoration(
                            border: Border(
                              left: BorderSide(
                                color: colorScheme.outlineVariant,
                              ),
                            ),
                          ),
                          child: Center(
                            child: Text(
                              operator.name,
                              style: TextStyle(
                                fontSize: kIsWindows ? 16 : 16.sp,
                                fontWeight: FontWeight.w600,
                                color: colorScheme.onSurface,
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                        ),
                      )
                      .toList(),
                ),
              ),
            ),
          ),
      ],
    ),
  );

  /// Builds scrollable content with timeline and operator columns
  Widget _buildScrollableContent(
    final ColorScheme colorScheme,
    final double columnWidth,
  ) => Row(
    children: [
      _buildTimeline(colorScheme),
      // CHANGED: Windows uses fixed width, Android scrolls if needed
      if (kIsWindows)
        Expanded(child: _buildOperatorColumns(colorScheme, columnWidth))
      else
        Expanded(
          child: NotificationListener<ScrollNotification>(
            onNotification: (final notification) {
              if (notification is ScrollUpdateNotification) {
                if (_horizontalScrollController.hasClients) {
                  if ((_horizontalScrollController.position.pixels -
                              notification.metrics.pixels)
                          .abs() >
                      1) {
                    _horizontalScrollController.jumpTo(
                      notification.metrics.pixels,
                    );
                  }
                }
              }
              return false;
            },
            child: SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              physics: const ClampingScrollPhysics(),
              child: SizedBox(
                width: columnWidth * _operators.length,
                child: _buildOperatorColumns(colorScheme, columnWidth),
              ),
            ),
          ),
        ),
    ],
  );

  /// Builds the time indicator column on the left
  Widget _buildTimeline(final ColorScheme colorScheme) {
    const totalMinutes = (_endHour - _startHour) * 60;
    final totalSlots =
        (totalMinutes ~/ _granularity.minutes) + (60 ~/ _granularity.minutes);

    return RepaintBoundary(
      child: Container(
        width: _timelineWidth,
        decoration: BoxDecoration(
          color: colorScheme.surfaceContainerHighest,
          border: Border(right: BorderSide(color: colorScheme.outlineVariant)),
        ),
        child: ListView.builder(
          controller: _verticalScrollController,
          itemCount: totalSlots,
          itemBuilder: (final context, final index) {
            final minutes = index * _granularity.minutes;
            final hour = _startHour + minutes ~/ 60;
            final minute = minutes % 60;
            final time = DateTime(
              _selectedDay.year,
              _selectedDay.month,
              _selectedDay.day,
              hour,
              minute,
            );

            final showLabel = _shouldShowTimeLabel(minute);

            return AnimatedContainer(
              duration: const Duration(milliseconds: 200),
              curve: Curves.easeInOut,
              height: _granularity.slotHeight,
              decoration: BoxDecoration(
                border: Border(
                  top: BorderSide(
                    color: showLabel
                        ? colorScheme.outlineVariant
                        : colorScheme.outlineVariant.withValues(alpha: 0.2),
                    width: showLabel ? 1 : 0.5,
                  ),
                ),
              ),
              child: showLabel
                  ? Padding(
                      padding: const EdgeInsets.only(top: 2, right: 4),
                      child: Text(
                        DateFormat('HH:mm').format(time),
                        textAlign: TextAlign.right,
                        style: TextStyle(
                          fontSize: kIsWindows ? 11 : 10.sp,
                          color: colorScheme.onSurfaceVariant,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    )
                  : null,
            );
          },
        ),
      ),
    );
  }

  /// Determines if a time label should be shown based on granularity
  bool _shouldShowTimeLabel(final int minute) => switch (_granularity) {
    SlotGranularity.minutes30 => minute == 0 || minute == 30,
    SlotGranularity.minutes15 => minute == 0 || minute == 30,
    SlotGranularity.minutes10 => minute == 0 || minute == 30,
    SlotGranularity.minutes5 => minute % 15 == 0,
  };

  /// Builds all operator columns with appointments and time slots
  Widget _buildOperatorColumns(
    final ColorScheme colorScheme,
    final double columnWidth,
  ) {
    const totalMinutes = (_endHour - _startHour) * 60;
    final totalSlots =
        (totalMinutes ~/ _granularity.minutes) + (60 ~/ _granularity.minutes);

    return Stack(
      children: [
        // Background grid
        RepaintBoundary(
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 200),
            curve: Curves.easeInOut,
            child: ListView.builder(
              controller: _verticalScrollController,
              physics: const NeverScrollableScrollPhysics(),
              itemCount: totalSlots,
              itemBuilder: (final context, final index) => Container(
                height: _granularity.slotHeight,
                decoration: BoxDecoration(
                  border: Border(
                    top: BorderSide(
                      color: colorScheme.outlineVariant.withValues(alpha: 0.2),
                      width: 0.5,
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
        // Operator columns with appointments
        // CHANGED: Windows uses Expanded, Android uses fixed widths
        if (kIsWindows)
          Row(
            children: _operators
                .map(
                  (final operator) => Expanded(
                    child: _buildOperatorColumn(
                      operator,
                      colorScheme,
                      columnWidth,
                    ),
                  ),
                )
                .toList(),
          )
        else
          Row(
            children: _operators
                .map(
                  (final operator) => SizedBox(
                    width: columnWidth,
                    child: _buildOperatorColumn(
                      operator,
                      colorScheme,
                      columnWidth,
                    ),
                  ),
                )
                .toList(),
          ),
        // Current time indicator
        if (_isSameDay(_currentTime, _selectedDay))
          _buildCurrentTimeIndicator(colorScheme),
      ],
    );
  }

  /// Builds a single operator column with time slots and appointments
  Widget _buildOperatorColumn(
    final Operator operator,
    final ColorScheme colorScheme,
    final double columnWidth,
  ) {
    final operatorAppointments = _appointments
        .where(
          (final apt) =>
              apt.operatorId == operator.id &&
              _isSameDay(apt.startTime, _selectedDay),
        )
        .toList();

    // CHANGED: On Windows, recalculate actual column width from context
    final actualColumnWidth = kIsWindows
        ? (MediaQuery.of(context).size.width - _timelineWidth - 32) /
              _operators.length
        : columnWidth;

    final appointmentLayouts = _calculateOverlapLayouts(
      operatorAppointments,
      actualColumnWidth,
    );

    return RepaintBoundary(
      child: DecoratedBox(
        decoration: BoxDecoration(
          border: Border(left: BorderSide(color: colorScheme.outlineVariant)),
        ),
        child: Stack(
          children: [
            _buildTimeSlots(operator, colorScheme),
            ...appointmentLayouts.map(
              (final layout) => _buildAppointmentCard(
                layout.appointment,
                operator,
                colorScheme,
                layout: layout,
              ),
            ),
          ],
        ),
      ),
    );
  }

  /// Calculates layout for overlapping appointments
  /// CHANGED: Improved overlap detection considering pasted appointments
  List<AppointmentLayout> _calculateOverlapLayouts(
    final List<Appointment> appointments,
    final double availableWidth,
  ) {
    if (appointments.isEmpty) return [];

    appointments.sort((final a, final b) => a.startTime.compareTo(b.startTime));

    final layouts = <AppointmentLayout>[];

    for (final apt in appointments) {
      final overlapping = appointments.where((final other) {
        if (other.id == apt.id) return false;
        return _appointmentsOverlap(apt, other);
      }).toList();

      if (overlapping.isEmpty) {
        layouts.add(
          AppointmentLayout(
            appointment: apt,
            columnIndex: 0,
            totalColumns: 1,
            leftOffset: _appointmentHorizontalPadding,
            width: availableWidth - (_appointmentHorizontalPadding * 2),
          ),
        );
      } else {
        overlapping
          ..add(apt)
          ..sort((final a, final b) => a.startTime.compareTo(b.startTime));

        final totalOverlapping = overlapping.length;
        final columnIndex = overlapping.indexOf(apt);

        final columnWidth =
            (availableWidth - (_appointmentHorizontalPadding * 2)) /
            totalOverlapping;
        final leftOffset =
            _appointmentHorizontalPadding + (columnWidth * columnIndex);

        layouts.add(
          AppointmentLayout(
            appointment: apt,
            columnIndex: columnIndex,
            totalColumns: totalOverlapping,
            leftOffset: leftOffset,
            width:
                columnWidth -
                (_appointmentHorizontalPadding / totalOverlapping),
          ),
        );
      }
    }

    return layouts;
  }

  /// Checks if two appointments overlap in time
  bool _appointmentsOverlap(final Appointment a, final Appointment b) =>
      a.startTime.isBefore(b.endTime) && a.endTime.isAfter(b.startTime);

  /// Builds interactive time slots for creating new appointments
  /// CHANGED: Windows adds right-click paste support on empty slots
  Widget _buildTimeSlots(
    final Operator operator,
    final ColorScheme colorScheme,
  ) {
    const totalMinutes = (_endHour - _startHour) * 60;
    final slotCount =
        (totalMinutes ~/ _granularity.minutes) + (60 ~/ _granularity.minutes);

    return ListView.builder(
      // CHANGED: Rimuovi controller qui - usa solo physics
      controller: _verticalScrollController,
      physics: const NeverScrollableScrollPhysics(),
      itemCount: slotCount,
      itemBuilder: (final context, final index) {
        final minutes = index * _granularity.minutes;
        final hour = _startHour + minutes ~/ 60;
        final minute = minutes % 60;
        final slotTime = DateTime(
          _selectedDay.year,
          _selectedDay.month,
          _selectedDay.day,
          hour,
          minute,
        );

        final slotKey = '${operator.id}_${slotTime.millisecondsSinceEpoch}';
        final isHovered = _hoveredSlotKey == slotKey;

        return DragTarget<Appointment>(
          onWillAcceptWithDetails: (final details) {
            setState(() => _hoveredSlotKey = slotKey);
            return true;
          },
          onLeave: (_) {
            setState(() => _hoveredSlotKey = null);
          },
          onAcceptWithDetails: (final details) {
            setState(() => _hoveredSlotKey = null);
            _handleAppointmentDrop(details.data, operator, slotTime);
          },
          builder: (final context, final candidateData, final rejectedData) =>
              GestureDetector(
                onTap: () {
                  _showCreateAppointmentDialog(operator, slotTime);
                  _resetInactivityTimer(); // CHANGED: Reset timer on interaction
                },
                onLongPress: () {
                  _resetInactivityTimer(); // CHANGED: Reset timer on interaction
                  if (_clipboardAppointment != null) {
                    _pasteAppointment(operator, slotTime);
                  }
                },
                // CHANGED: Windows right-click to paste on empty slots
                onSecondaryTap: kIsWindows
                    ? () {
                        _resetInactivityTimer();
                        if (_clipboardAppointment != null) {
                          _showPasteConfirmation(operator, slotTime);
                        }
                      }
                    : null,
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 150),
                  curve: Curves.easeOut,
                  height: _granularity.slotHeight,
                  decoration: BoxDecoration(
                    color: isHovered
                        ? colorScheme.primaryContainer.withValues(alpha: 0.4)
                        : Colors.transparent,
                    border: isHovered
                        ? Border.all(color: colorScheme.primary, width: 2)
                        : null,
                  ),
                  child: isHovered
                      ? Center(
                          child: Icon(
                            Symbols.add_circle_rounded,
                            color: colorScheme.primary,
                            size: kIsWindows ? 24 : 20.sp,
                          ),
                        )
                      : null,
                ),
              ),
        );
      },
    );
  }

  /// Builds an appointment card with drag and interaction capabilities
  /// CHANGED: Added proper drag delay and haptic feedback for Android
  Widget _buildAppointmentCard(
    final Appointment apt,
    final Operator operator,
    final ColorScheme colorScheme, {
    final AppointmentLayout? layout,
  }) {
    final startOffset = _calculateTimeOffset(apt.startTime);
    final duration = apt.endTime.difference(apt.startTime);
    final height =
        (duration.inMinutes / _granularity.minutes) * _granularity.slotHeight -
        (_appointmentVerticalPadding * 2);

    final leftOffset = layout?.leftOffset ?? _appointmentHorizontalPadding;
    final width = layout?.width ?? 180.0;

    Timer? longPressTimer;
    var shouldStartDrag = false;

    // CHANGED: Proper drag implementation with delay
    return Positioned(
      top: startOffset + _appointmentVerticalPadding,
      left: leftOffset,
      width: width,
      height: height,
      child: GestureDetector(
        onTap: () {
          _showAppointmentDetailsDialog(apt, operator);
          _resetInactivityTimer(); // CHANGED: Reset timer on interaction
        },
        // CHANGED: Windows right-click for context menu
        onLongPressStart: !kIsWindows
            ? (final details) {
                _resetInactivityTimer();
                shouldStartDrag = false;

                // Wait for drag delay, if user holds longer, start drag
                longPressTimer = Timer(
                  const Duration(milliseconds: _dragStartDelay),
                  () {
                    shouldStartDrag = true;
                    HapticFeedback.mediumImpact();
                    _startDragging(apt, operator, width, height, details);
                  },
                );
              }
            : null,
        onLongPressEnd: !kIsWindows
            ? (final details) {
                longPressTimer?.cancel();
                // If timer didn't complete, show context menu instead
                if (!shouldStartDrag) {
                  _showAppointmentContextMenu(apt, operator);
                }
              }
            : null,
        onLongPressCancel: !kIsWindows
            ? () {
                longPressTimer?.cancel();
              }
            : null,
        child: kIsWindows
            ? Draggable<Appointment>(
                data: apt,
                feedback: Material(
                  elevation: 8,
                  borderRadius: BorderRadius.circular(8),
                  child: Container(
                    width: width,
                    height: height,
                    decoration: BoxDecoration(
                      color: apt.color ?? operator.color,
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Center(
                      child: Icon(
                        Symbols.drag_indicator_rounded,
                        color: colorScheme.onPrimary,
                        size: kIsWindows ? 32 : 28.sp,
                      ),
                    ),
                  ),
                ),
                childWhenDragging: Opacity(
                  opacity: 0.3,
                  child: _buildAppointmentCardContent(
                    apt,
                    operator,
                    colorScheme,
                    height,
                  ),
                ),
                onDragStarted: _resetInactivityTimer,
                child: _buildAppointmentCardContent(
                  apt,
                  operator,
                  colorScheme,
                  height,
                ),
              )
            : _buildAppointmentCardContent(apt, operator, colorScheme, height),
      ),
    );
  }

  // CHANGED: New method to start dragging with proper feedback
  void _startDragging(
    final Appointment apt,
    final Operator operator,
    final double width,
    final double height,
    final LongPressStartDetails details,
  ) {
    final colorScheme = Theme.of(context).colorScheme;
    final overlay =
        Overlay.of(context).context.findRenderObject() as RenderBox?;

    if (overlay == null) return;

    showDialog(
      context: context,
      barrierDismissible: false,
      barrierColor: Colors.transparent,
      builder: (final context) => Stack(
        children: [
          Positioned(
            left: details.globalPosition.dx - width / 2,
            top: details.globalPosition.dy - height / 2,
            child: Draggable<Appointment>(
              data: apt,
              feedback: Material(
                elevation: 8,
                borderRadius: BorderRadius.circular(8),
                child: Container(
                  width: width,
                  height: height,
                  decoration: BoxDecoration(
                    color: apt.color ?? operator.color,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Center(
                    child: Icon(
                      Symbols.drag_indicator_rounded,
                      color: colorScheme.onPrimary,
                      size: 28.sp,
                    ),
                  ),
                ),
              ),
              childWhenDragging: const SizedBox.shrink(),
              onDragEnd: (_) {
                Navigator.of(context).pop();
                setState(() {});
              },
              child: Material(
                elevation: 8,
                borderRadius: BorderRadius.circular(8),
                child: Container(
                  width: width,
                  height: height,
                  decoration: BoxDecoration(
                    color: apt.color ?? operator.color,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Center(
                    child: Icon(
                      Symbols.drag_indicator_rounded,
                      color: colorScheme.onPrimary,
                      size: 28.sp,
                    ),
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );

    setState(() {});
  }

  /// Builds the visual content of an appointment card
  Widget _buildAppointmentCardContent(
    final Appointment apt,
    final Operator operator,
    final ColorScheme colorScheme,
    final double height,
  ) => Container(
    decoration: BoxDecoration(
      color: apt.color ?? operator.color,
      borderRadius: BorderRadius.circular(8),
      boxShadow: [
        BoxShadow(
          color: Colors.black.withValues(alpha: 0.15),
          blurRadius: 4,
          offset: const Offset(0, 2),
        ),
      ],
    ),
    padding: EdgeInsets.all(kIsWindows ? 8 : 6.w),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          apt.clientName,
          style: TextStyle(
            color: colorScheme.onPrimary,
            fontWeight: FontWeight.w600,
            fontSize: kIsWindows ? 13 : 12.sp,
          ),
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        ),
        if (height > 40) ...[
          SizedBox(height: kIsWindows ? 2 : 1.h),
          Text(
            apt.service,
            style: TextStyle(
              color: colorScheme.onPrimary.withValues(alpha: 0.9),
              fontSize: kIsWindows ? 11 : 10.sp,
            ),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
        ],
        if (height > 60) ...[
          SizedBox(height: kIsWindows ? 2 : 1.h),
          Text(
            '${DateFormat('HH:mm').format(apt.startTime)} - ${DateFormat('HH:mm').format(apt.endTime)}',
            style: TextStyle(
              color: colorScheme.onPrimary.withValues(alpha: 0.8),
              fontSize: kIsWindows ? 10 : 9.sp,
            ),
          ),
        ],
      ],
    ),
  );

  /// Builds the current time indicator line
  Widget _buildCurrentTimeIndicator(final ColorScheme colorScheme) =>
      Positioned(
        top: _calculateTimeOffset(_currentTime),
        left: 0,
        right: 0,
        child: RepaintBoundary(
          child: Row(
            children: [
              Container(
                width: 10,
                height: 10,
                decoration: BoxDecoration(
                  color: colorScheme.error,
                  shape: BoxShape.circle,
                  boxShadow: [
                    BoxShadow(
                      color: colorScheme.error.withValues(alpha: 0.4),
                      blurRadius: 4,
                      spreadRadius: 1,
                    ),
                  ],
                ),
              ),
              Expanded(
                child: Container(
                  height: 2,
                  decoration: BoxDecoration(
                    color: colorScheme.error,
                    boxShadow: [
                      BoxShadow(
                        color: colorScheme.error.withValues(alpha: 0.3),
                        blurRadius: 2,
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      );

  // ==========================================================================
  // DIALOGS & INTERACTIONS
  // ==========================================================================

  /// Shows dialog to create a new appointment
  /// TODO: Connect to repository to save appointments
  void _showCreateAppointmentDialog(
    final Operator operator,
    final DateTime slotTime,
  ) {
    final clientNameController = TextEditingController();
    final serviceController = TextEditingController();
    var durationMinutes = 30;
    var selectedStartTime = slotTime;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (final context) => StatefulBuilder(
        builder: (final context, final setModalState) => Container(
          decoration: BoxDecoration(
            color: Theme.of(context).colorScheme.surfaceContainerHigh,
            borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
          ),
          padding: EdgeInsets.only(
            bottom: MediaQuery.of(context).viewInsets.bottom + 16,
            left: 24,
            right: 24,
            top: 24,
          ),
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Icon(
                      Symbols.add_circle_rounded,
                      color: Theme.of(context).colorScheme.primary,
                      size: kIsWindows ? 28 : 24.sp,
                    ),
                    SizedBox(width: kIsWindows ? 12 : 8.w),
                    Text(
                      'Nuovo Appuntamento', // TODO: localize
                      style: Theme.of(context).textTheme.headlineSmall,
                    ),
                  ],
                ),
                const SizedBox(height: 20),
                // Operator info
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: operator.color.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(
                      color: operator.color.withValues(alpha: 0.3),
                    ),
                  ),
                  child: Row(
                    children: [
                      Icon(Symbols.person_rounded, color: operator.color),
                      const SizedBox(width: 8),
                      Text(
                        'Operatore: ${operator.name}', // TODO: localize
                        style: TextStyle(
                          fontWeight: FontWeight.w600,
                          color: operator.color,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 16),
                // Start time picker
                InkWell(
                  onTap: () async {
                    final time = await showTimePicker(
                      context: context,
                      initialTime: TimeOfDay.fromDateTime(selectedStartTime),
                    );
                    if (time != null) {
                      setModalState(() {
                        selectedStartTime = DateTime(
                          selectedStartTime.year,
                          selectedStartTime.month,
                          selectedStartTime.day,
                          time.hour,
                          time.minute,
                        );
                      });
                    }
                  },
                  child: InputDecorator(
                    decoration: const InputDecoration(
                      labelText: 'Orario Inizio', // TODO: localize
                      border: OutlineInputBorder(),
                      prefixIcon: Icon(Symbols.schedule_rounded),
                    ),
                    child: Text(DateFormat('HH:mm').format(selectedStartTime)),
                  ),
                ),
                const SizedBox(height: 12),
                // Duration dropdown
                DropdownButtonFormField<int>(
                  initialValue: durationMinutes,
                  decoration: const InputDecoration(
                    labelText: 'Durata', // TODO: localize
                    border: OutlineInputBorder(),
                    prefixIcon: Icon(Symbols.timer_rounded),
                  ),
                  items: [15, 30, 45, 60, 90, 120]
                      .map(
                        (final minutes) => DropdownMenuItem(
                          value: minutes,
                          child: Text('$minutes minuti'), // TODO: localize
                        ),
                      )
                      .toList(),
                  onChanged: (final value) {
                    if (value != null) {
                      setModalState(() => durationMinutes = value);
                    }
                  },
                ),
                const SizedBox(height: 12),
                // Client name input
                TextField(
                  controller: clientNameController,
                  decoration: const InputDecoration(
                    labelText: 'Nome Cliente', // TODO: localize
                    border: OutlineInputBorder(),
                    prefixIcon: Icon(Symbols.person_rounded),
                  ),
                  textCapitalization: TextCapitalization.words,
                ),
                const SizedBox(height: 12),
                // Service input
                TextField(
                  controller: serviceController,
                  decoration: const InputDecoration(
                    labelText: 'Servizio', // TODO: localize
                    border: OutlineInputBorder(),
                    prefixIcon: Icon(Symbols.cut_rounded),
                  ),
                  textCapitalization: TextCapitalization.sentences,
                ),
                const SizedBox(height: 20),
                // Actions
                Row(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    TextButton(
                      onPressed: () => Navigator.pop(context),
                      child: const Text('Annulla'), // TODO: localize
                    ),
                    const SizedBox(width: 8),
                    FilledButton.icon(
                      icon: const Icon(Symbols.check_rounded),
                      label: const Text('Salva'), // TODO: localize
                      onPressed: () {
                        if (clientNameController.text.trim().isEmpty) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(
                              content: Text(
                                'Inserisci il nome del cliente',
                              ), // TODO: localize
                            ),
                          );
                          return;
                        }

                        final newAppointment = Appointment(
                          id: DateTime.now().millisecondsSinceEpoch.toString(),
                          operatorId: operator.id,
                          clientName: clientNameController.text.trim(),
                          service: serviceController.text.trim(),
                          startTime: selectedStartTime,
                          endTime: selectedStartTime.add(
                            Duration(minutes: durationMinutes),
                          ),
                        );

                        setState(() {
                          _appointments.add(newAppointment);
                        });

                        // TODO: Save to database
                        // await ref.read(appointmentsRepositoryProvider)
                        //     .createAppointment(newAppointment);

                        Navigator.pop(context);

                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(
                            content: const Text(
                              'Appuntamento creato',
                            ), // TODO: localize
                            action: SnackBarAction(
                              label: 'Annulla', // TODO: localize
                              onPressed: () {
                                setState(() {
                                  _appointments.removeWhere(
                                    (final a) => a.id == newAppointment.id,
                                  );
                                });
                                // TODO: Delete from database
                              },
                            ),
                          ),
                        );
                      },
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  /// Shows dialog to view/edit appointment details
  /// TODO: Connect to repository to update appointments
  /// CHANGED: Fixed Expanded widget error by replacing Spacer with SizedBox
  void _showAppointmentDetailsDialog(
    final Appointment apt,
    final Operator operator,
  ) {
    final clientNameController = TextEditingController(text: apt.clientName);
    final serviceController = TextEditingController(text: apt.service);
    var selectedStartTime = apt.startTime;
    var durationMinutes = apt.endTime.difference(apt.startTime).inMinutes;

    showDialog(
      context: context,
      builder: (final context) => StatefulBuilder(
        builder: (final context, final setDialogState) => AlertDialog(
          title: Row(
            children: [
              Icon(
                Symbols.edit_calendar_rounded,
                color: Theme.of(context).colorScheme.primary,
              ),
              const SizedBox(width: 8),
              const Expanded(
                child: Text('Modifica Appuntamento'),
              ), // TODO: localize
            ],
          ),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Operator info
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: operator.color.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Row(
                    children: [
                      Icon(Symbols.person_rounded, color: operator.color),
                      const SizedBox(width: 8),
                      Text('Operatore: ${operator.name}'),
                      // TODO: localize
                    ],
                  ),
                ),
                const SizedBox(height: 16),
                // Start time picker
                InkWell(
                  onTap: () async {
                    final time = await showTimePicker(
                      context: context,
                      initialTime: TimeOfDay.fromDateTime(selectedStartTime),
                    );
                    if (time != null) {
                      setDialogState(() {
                        selectedStartTime = DateTime(
                          selectedStartTime.year,
                          selectedStartTime.month,
                          selectedStartTime.day,
                          time.hour,
                          time.minute,
                        );
                      });
                    }
                  },
                  child: InputDecorator(
                    decoration: const InputDecoration(
                      labelText: 'Orario Inizio', // TODO: localize
                      border: OutlineInputBorder(),
                      prefixIcon: Icon(Symbols.schedule_rounded),
                    ),
                    child: Text(DateFormat('HH:mm').format(selectedStartTime)),
                  ),
                ),
                const SizedBox(height: 12),
                // Duration dropdown
                DropdownButtonFormField<int>(
                  initialValue: durationMinutes,
                  decoration: const InputDecoration(
                    labelText: 'Durata', // TODO: localize
                    border: OutlineInputBorder(),
                    prefixIcon: Icon(Symbols.timer_rounded),
                  ),
                  items: [15, 30, 45, 60, 90, 120]
                      .map(
                        (final minutes) => DropdownMenuItem(
                          value: minutes,
                          child: Text('$minutes minuti'), // TODO: localize
                        ),
                      )
                      .toList(),
                  onChanged: (final value) {
                    if (value != null) {
                      setDialogState(() => durationMinutes = value);
                    }
                  },
                ),
                const SizedBox(height: 12),
                // Client name input
                TextField(
                  controller: clientNameController,
                  decoration: const InputDecoration(
                    labelText: 'Nome Cliente', // TODO: localize
                    border: OutlineInputBorder(),
                    prefixIcon: Icon(Symbols.person_rounded),
                  ),
                ),
                const SizedBox(height: 12),
                // Service input
                TextField(
                  controller: serviceController,
                  decoration: const InputDecoration(
                    labelText: 'Servizio', // TODO: localize
                    border: OutlineInputBorder(),
                    prefixIcon: Icon(Symbols.cut_rounded),
                  ),
                ),
              ],
            ),
          ),
          actions: [
            // Delete button
            TextButton.icon(
              icon: const Icon(Symbols.delete_rounded),
              label: const Text('Elimina'), // TODO: localize
              onPressed: () {
                Navigator.pop(context);
                _deleteAppointment(apt);
              },
              style: TextButton.styleFrom(
                foregroundColor: Theme.of(context).colorScheme.error,
              ),
            ),
            // CHANGED: Replaced Spacer with SizedBox to fix Expanded error
            const SizedBox(width: 8),
            // Cancel button
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Annulla'), // TODO: localize
            ),
            // Save button
            FilledButton.icon(
              icon: const Icon(Symbols.check_rounded),
              label: const Text('Salva'), // TODO: localize
              onPressed: () {
                if (clientNameController.text.trim().isEmpty) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text(
                        'Inserisci il nome del cliente',
                      ), // TODO: localize
                    ),
                  );
                  return;
                }

                setState(() {
                  final index = _appointments.indexWhere(
                    (final a) => a.id == apt.id,
                  );
                  if (index != -1) {
                    _appointments[index] = apt.copyWith(
                      clientName: clientNameController.text.trim(),
                      service: serviceController.text.trim(),
                      startTime: selectedStartTime,
                      endTime: selectedStartTime.add(
                        Duration(minutes: durationMinutes),
                      ),
                    );
                  }
                });

                // TODO: Update in database
                // await ref.read(appointmentsRepositoryProvider)
                //     .updateAppointment(_appointments[index]);

                Navigator.pop(context);

                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text('Appuntamento aggiornato'),
                  ), // TODO: localize
                );
              },
            ),
          ],
        ),
      ),
    );
  }

  /// Shows context menu with appointment actions (copy, cut, paste, delete)
  void _showAppointmentContextMenu(
    final Appointment apt,
    final Operator operator,
  ) {
    showModalBottomSheet(
      context: context,
      builder: (final context) => Container(
        padding: const EdgeInsets.symmetric(vertical: 8),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(Symbols.edit_rounded),
              title: const Text('Modifica'), // TODO: localize
              onTap: () {
                Navigator.pop(context);
                _showAppointmentDetailsDialog(apt, operator);
              },
            ),
            ListTile(
              leading: const Icon(Symbols.content_copy_rounded),
              title: const Text('Copia'), // TODO: localize
              onTap: () {
                Navigator.pop(context);
                _copyAppointment(apt);
              },
            ),
            ListTile(
              leading: const Icon(Symbols.content_cut_rounded),
              title: const Text('Taglia'), // TODO: localize
              onTap: () {
                Navigator.pop(context);
                _cutAppointment(apt);
              },
            ),
            if (_clipboardAppointment != null)
              ListTile(
                leading: const Icon(Symbols.content_paste_rounded),
                title: const Text('Incolla qui'), // TODO: localize
                onTap: () {
                  Navigator.pop(context);
                  _pasteAppointment(operator, apt.startTime);
                },
              ),
            const Divider(),
            ListTile(
              leading: Icon(
                Symbols.delete_rounded,
                color: Theme.of(context).colorScheme.error,
              ),
              title: Text(
                'Elimina', // TODO: localize
                style: TextStyle(color: Theme.of(context).colorScheme.error),
              ),
              onTap: () {
                Navigator.pop(context);
                _deleteAppointment(apt);
              },
            ),
          ],
        ),
      ),
    );
  }

  // CHANGED: New method for Windows right-click paste confirmation
  /// Shows confirmation dialog for pasting appointment on Windows
  void _showPasteConfirmation(
    final Operator operator,
    final DateTime slotTime,
  ) {
    showModalBottomSheet(
      context: context,
      builder: (final context) => Container(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Symbols.content_paste_rounded,
              size: 48,
              color: Theme.of(context).colorScheme.primary,
            ),
            const SizedBox(height: 16),
            Text(
              'Incolla appuntamento?', // TODO: localize
              style: Theme.of(context).textTheme.titleLarge,
            ),
            const SizedBox(height: 8),
            Text(
              'Operatore: ${operator.name}', // TODO: localize
              style: Theme.of(context).textTheme.bodyMedium,
            ),
            Text(
              'Orario: ${DateFormat('HH:mm').format(slotTime)}',
              style: Theme.of(context).textTheme.bodyMedium,
            ),
            const SizedBox(height: 24),
            Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                TextButton(
                  onPressed: () => Navigator.pop(context),
                  child: const Text('Annulla'), // TODO: localize
                ),
                const SizedBox(width: 8),
                FilledButton.icon(
                  icon: const Icon(Symbols.check_rounded),
                  label: const Text('Incolla'), // TODO: localize
                  onPressed: () {
                    Navigator.pop(context);
                    _pasteAppointment(operator, slotTime);
                  },
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  /// Handles dropping an appointment to a new time slot
  /// TODO: Update in database
  void _handleAppointmentDrop(
    final Appointment apt,
    final Operator targetOperator,
    final DateTime targetTime,
  ) {
    setState(() {
      final index = _appointments.indexWhere((final a) => a.id == apt.id);
      if (index != -1) {
        final duration = apt.endTime.difference(apt.startTime);
        _appointments[index] = apt.copyWith(
          operatorId: targetOperator.id,
          startTime: targetTime,
          endTime: targetTime.add(duration),
        );
      }
    });

    // TODO: Update in database
    // await ref.read(appointmentsRepositoryProvider)
    //     .updateAppointment(_appointments[index]);

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          'Appuntamento spostato per ${targetOperator.name}',
        ), // TODO: localize
        duration: const Duration(seconds: 2),
      ),
    );
  }

  /// Copies appointment to clipboard
  void _copyAppointment(final Appointment apt) {
    setState(() {
      _clipboardAppointment = apt;
    });

    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text(
          'Appuntamento copiato - Long press su uno slot per incollare',
        ), // TODO: localize
        duration: Duration(seconds: 3),
      ),
    );
  }

  /// Cuts appointment to clipboard and removes from current position
  /// TODO: Delete from database
  void _cutAppointment(final Appointment apt) {
    setState(() {
      _clipboardAppointment = apt;
      _appointments.removeWhere((final a) => a.id == apt.id);
    });

    // TODO: Delete from database
    // await ref.read(appointmentsRepositoryProvider).deleteAppointment(apt.id);

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: const Text(
          'Appuntamento tagliato - Long press su uno slot per incollare',
        ), // TODO: localize
        duration: const Duration(seconds: 3),
        action: SnackBarAction(
          label: 'Annulla', // TODO: localize
          onPressed: () {
            setState(() {
              if (_clipboardAppointment != null) {
                _appointments.add(_clipboardAppointment!);
                _clipboardAppointment = null;
              }
            });
            // TODO: Restore in database
          },
        ),
      ),
    );
  }

  /// Pastes appointment from clipboard to new location
  /// CHANGED: Clears clipboard after pasting and checks for overlaps
  /// TODO: Save to database
  void _pasteAppointment(
    final Operator targetOperator,
    final DateTime targetTime,
  ) {
    if (_clipboardAppointment == null) return;

    final duration = _clipboardAppointment!.endTime.difference(
      _clipboardAppointment!.startTime,
    );

    final newAppointment = _clipboardAppointment!.copyWith(
      id: DateTime.now().millisecondsSinceEpoch.toString(),
      operatorId: targetOperator.id,
      startTime: targetTime,
      endTime: targetTime.add(duration),
    );

    setState(() {
      _appointments.add(newAppointment);
      _clipboardAppointment = null; // CHANGED: Clear clipboard after paste
    });

    // TODO: Save to database
    // await ref.read(appointmentsRepositoryProvider)
    //     .createAppointment(newAppointment);

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          'Appuntamento incollato per ${targetOperator.name}',
        ), // TODO: localize
        duration: const Duration(seconds: 2),
      ),
    );
  }

  /// Deletes an appointment with undo option
  /// TODO: Delete from database
  void _deleteAppointment(final Appointment apt) {
    final deletedAppointment = apt;
    final deletedIndex = _appointments.indexOf(apt);

    setState(() {
      _appointments.removeWhere((final a) => a.id == apt.id);
    });

    // TODO: Delete from database
    // await ref.read(appointmentsRepositoryProvider).deleteAppointment(apt.id);

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: const Text('Appuntamento eliminato'), // TODO: localize
        action: SnackBarAction(
          label: 'Annulla', // TODO: localize
          onPressed: () {
            setState(() {
              if (deletedIndex >= 0 && deletedIndex <= _appointments.length) {
                _appointments.insert(deletedIndex, deletedAppointment);
              } else {
                _appointments.add(deletedAppointment);
              }
            });

            // TODO: Restore in database
            // await ref.read(appointmentsRepositoryProvider)
            //     .createAppointment(deletedAppointment);
          },
        ),
      ),
    );
  }
}

// =============================================================================
// EXTENSIONS
// =============================================================================

/// Extension for comparing DateTime objects
extension DateTimeComparison on DateTime {
  bool isAtOrAfter(final DateTime other) =>
      isAfter(other) || isAtSameMomentAs(other);
}
