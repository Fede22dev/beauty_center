//file: _appointments_agenda.dart
import 'dart:async';
import 'dart:math' as math;

import 'package:beauty_center/features/settings/presentation/providers/settings_provider.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:intl/intl.dart';
import 'package:material_symbols_icons/symbols.dart';
import 'package:syncfusion_flutter_datepicker/datepicker.dart';

import '../../../../../core/constants/app_constants.dart';
import '../../../../../core/constants/italy_holidays.dart';

// =============================================================================
// MODELS & DATA
// =============================================================================

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

// CHANGED: Aggiunta proprietà per gestire meglio l'overlap
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

class Operator {
  Operator({required this.id, required this.name, required this.color});

  final String id;
  final String name;
  final Color color;
}

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
// ==========================================================================

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
  var _currentTime = DateTime.now();

  // Clipboard per copy/cut/paste
  Appointment? _clipboardAppointment;

  // CHANGED: Variabile per gestire animazione zoom
  double _currentZoomScale = 1;

  // CHANGED: Variabile per gestire hover su slot durante drag
  String? _hoveredSlotKey;

  // CUSTOMIZATION POINT: Configurazione orari lavoro
  static const _startHour = 6;
  static const _endHour = 22;

  // CUSTOMIZATION POINT: Larghezza timeline (ridotta per più spazio calendario)
  static const double _timelineWidth = 40;

  // CUSTOMIZATION POINT: Larghezza minima colonna operatore
  // Su Android: 120-150px, Su Windows: 180-200px
  static double get _minOperatorColumnWidth => kIsWindows ? 180.0 : 120.0;

  // CUSTOMIZATION POINT: Numero massimo colonne prima di attivare scroll orizzontale
  static const _maxVisibleOperators = 3;

  // CUSTOMIZATION POINT: Padding tra appuntamenti
  static const double _appointmentVerticalPadding = 2;
  static const double _appointmentHorizontalPadding = 4;

  // CUSTOMIZATION POINT: Delay per attivare drag (in millisecondi)
  // Aumentato per evitare drag accidentali durante scroll
  static const _dragStartDelay = 100;

  // Mock data - TODO: Sostituire con dati reali da provider/repository
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

  void initState() {
    super.initState();
    _selectedDay = _normalizeDate(DateTime.now());
    _granularity = SlotGranularity.minutes30;
    _verticalScrollController = ScrollController();
    _horizontalScrollController = ScrollController();

    // CHANGED: Aggiunto AnimationController per transizioni giorno
    _pageTransitionController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 300),
    );

    _startCurrentTimeTimer();

    WidgetsBinding.instance.addPostFrameCallback((_) {
      _scrollToCurrentTime();
    });
  }

  @override
  void dispose() {
    _currentTimeTimer?.cancel();
    _verticalScrollController.dispose();
    _horizontalScrollController.dispose();
    _pageTransitionController.dispose();
    super.dispose();
  }

  DateTime _normalizeDate(final DateTime date) =>
      DateTime(date.year, date.month, date.day);

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

  void _scrollToCurrentTime() {
    if (!_verticalScrollController.hasClients) return;

    final now = DateTime.now();
    if (!_isSameDay(now, _selectedDay)) return;

    final offset = _calculateTimeOffset(now);
    final maxScroll = _verticalScrollController.position.maxScrollExtent;
    final targetScroll = math.min(offset - 100, maxScroll);

    if (targetScroll > 0) {
      _verticalScrollController.animateTo(
        targetScroll,
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeOut,
      );
    }
  }

  bool _isSameDay(final DateTime a, final DateTime b) =>
      a.year == b.year && a.month == b.month && a.day == b.day;

  double _calculateTimeOffset(final DateTime time) {
    final minutes = (time.hour - _startHour) * 60 + time.minute;
    return minutes / _granularity.minutes * _granularity.slotHeight;
  }

  double _calculateOperatorColumnWidth(final BuildContext context) {
    final screenWidth = MediaQuery.of(context).size.width;
    final availableWidth = screenWidth - _timelineWidth - 32; // 32 = padding

    if (_operators.length <= _maxVisibleOperators) {
      return availableWidth / _operators.length;
    } else {
      return math.max(
        _minOperatorColumnWidth,
        availableWidth / _maxVisibleOperators,
      );
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
  // TOP BAR
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

  void _changeDay(final int delta) {
    _pageTransitionController.forward(from: 0).then((_) {
      setState(() {
        _selectedDay = _normalizeDate(_selectedDay.add(Duration(days: delta)));
      });
      _pageTransitionController.reverse();
    });
  }

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
              // TODO: localize
              showTrailingAndLeadingDates: true,
              weekendDays: const [7, 1],
              specialDates: allHolidaysItaly().where((final date) {
                final today = DateTime.now();
                return !(date.year == today.year &&
                    date.month == today.month &&
                    date.day == today.day);
              }).toList(), // TODO localize
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
  // CALENDAR VIEW
  // ==========================================================================

  Widget _buildCalendar(final ColorScheme colorScheme) {
    final screenHeight = MediaQuery.of(context).size.height;
    final topBarHeight = kIsWindows ? 48 : 52.h;
    final availableHeight =
        screenHeight -
        topBarHeight -
        (kIsWindows ? 80 : 100.h) +
        1500.h; // TODO capire come ottenere l'altezza giusta

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

  // CHANGED: Vista giornaliera con gestione swipe orizzontale e header sticky
  Widget _buildDayView(final ColorScheme colorScheme) {
    final columnWidth = _calculateOperatorColumnWidth(context);

    return GestureDetector(
      // CHANGED: Gestione pinch-to-zoom ottimizzata
      onScaleStart: (_) => _currentZoomScale = 1.0,
      onScaleUpdate: (final details) {
        final delta = details.scale - _currentZoomScale;
        if (delta.abs() > 0.25) {
          setState(() {
            _granularity = delta > 0
                ? _granularity.zoomIn()
                : _granularity.zoomOut();
            _currentZoomScale = details.scale;
          });
        }
      },
      // CHANGED: Gestione swipe orizzontale per cambio giorno
      onHorizontalDragEnd: (final details) {
        if (details.primaryVelocity == null) return;
        if (details.primaryVelocity! > 500) {
          _changeDay(-1); // Swipe destra -> giorno precedente
        } else if (details.primaryVelocity! < -500) {
          _changeDay(1); // Swipe sinistra -> giorno successivo
        }
      },
      child: Column(
        children: [
          // CHANGED: Header sticky sempre visibile
          _buildStickyHeader(colorScheme, columnWidth),
          // CHANGED: Contenuto scrollabile
          Expanded(child: _buildScrollableContent(colorScheme, columnWidth)),
        ],
      ),
    );
  }

  // CHANGED: Header sticky con nomi operatori
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
        // Timeline header spacer
        const SizedBox(width: _timelineWidth),
        // CHANGED: Operatori header con scroll sincronizzato
        Expanded(
          child: NotificationListener<ScrollNotification>(
            onNotification: (final notification) => true,
            // Blocca notifiche
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
                    )
                    .toList(),
              ),
            ),
          ),
        ),
      ],
    ),
  );

  // CHANGED: Contenuto scrollabile con timeline e colonne operatori
  Widget _buildScrollableContent(
    final ColorScheme colorScheme,
    final double columnWidth,
  ) => Row(
    children: [
      // Timeline fissa
      _buildTimeline(colorScheme),
      // Colonne operatori scrollabili
      Expanded(
        child: NotificationListener<ScrollNotification>(
          onNotification: (final notification) {
            // Sincronizza scroll orizzontale header con contenuto
            if (notification is ScrollUpdateNotification) {
              if (_horizontalScrollController.hasClients) {
                // Evita loop infinito controllando posizione
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

  bool _shouldShowTimeLabel(final int minute) => switch (_granularity) {
    SlotGranularity.minutes30 => minute == 0 || minute == 30,
    SlotGranularity.minutes15 => minute == 0 || minute == 30,
    SlotGranularity.minutes10 => minute == 0 || minute == 30,
    SlotGranularity.minutes5 => minute % 15 == 0,
  };

  Widget _buildOperatorColumns(
    final ColorScheme colorScheme,
    final double columnWidth,
  ) {
    const totalMinutes = (_endHour - _startHour) * 60;
    final totalSlots =
        (totalMinutes ~/ _granularity.minutes) + (60 ~/ _granularity.minutes);

    return Stack(
      children: [
        // Grid background
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
        // Colonne operatori con appuntamenti
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
        // Indicatore tempo corrente
        if (_isSameDay(_currentTime, _selectedDay))
          _buildCurrentTimeIndicator(colorScheme),
      ],
    );
  }

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

    // CHANGED: Calcola layout overlap con larghezze corrette
    final appointmentLayouts = _calculateOverlapLayouts(
      operatorAppointments,
      columnWidth,
    );

    return RepaintBoundary(
      child: DecoratedBox(
        decoration: BoxDecoration(
          border: Border(left: BorderSide(color: colorScheme.outlineVariant)),
        ),
        child: Stack(
          children: [
            // Slots per tap-to-create
            _buildTimeSlots(operator, colorScheme),
            // Appuntamenti con gestione overlap
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

  // CHANGED: Calcolo overlap migliorato che considera solo appuntamenti sovrapposti
  List<AppointmentLayout> _calculateOverlapLayouts(
    final List<Appointment> appointments,
    final double availableWidth,
  ) {
    if (appointments.isEmpty) return [];

    appointments.sort((final a, final b) => a.startTime.compareTo(b.startTime));

    final layouts = <AppointmentLayout>[];

    for (final apt in appointments) {
      // Trova tutti gli appuntamenti che si sovrappongono con questo
      final overlapping = appointments.where((final other) {
        if (other.id == apt.id) return false;
        return _appointmentsOverlap(apt, other);
      }).toList();

      if (overlapping.isEmpty) {
        // Nessun overlap: usa tutta la larghezza disponibile
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
        // C'è overlap: calcola posizione e larghezza
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

  bool _appointmentsOverlap(final Appointment a, final Appointment b) =>
      a.startTime.isBefore(b.endTime) && a.endTime.isAfter(b.startTime);

  Widget _buildTimeSlots(
    final Operator operator,
    final ColorScheme colorScheme,
  ) {
    const totalMinutes = (_endHour - _startHour) * 60;
    final slotCount =
        (totalMinutes ~/ _granularity.minutes) + (60 ~/ _granularity.minutes);

    return ListView.builder(
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
                onTap: () => _showCreateAppointmentDialog(operator, slotTime),
                onLongPress: () {
                  if (_clipboardAppointment != null) {
                    _pasteAppointment(operator, slotTime);
                  }
                },
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

    // CHANGED: Usa layout calcolato per posizione e larghezza
    final leftOffset = layout?.leftOffset ?? _appointmentHorizontalPadding;
    final width = layout?.width ?? 180.0;

    return Positioned(
      top: startOffset + _appointmentVerticalPadding,
      left: leftOffset,
      width: width,
      height: height,
      child: LongPressDraggable<Appointment>(
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
        onDragStarted: () {
          if (mounted) {
            // Feedback aptico opzionale
          }
        },
        child: GestureDetector(
          onTap: () => _showAppointmentDetailsDialog(apt, operator),
          onSecondaryTap: kIsWindows
              ? () => _showAppointmentContextMenu(apt, operator)
              : null,
          onLongPress: kIsWindows
              ? null
              : () => _showAppointmentContextMenu(apt, operator),
          child: _buildAppointmentCardContent(
            apt,
            operator,
            colorScheme,
            height,
          ),
        ),
      ),
    );
  }

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

  // TODO: Connetti al tuo repository per salvare appuntamenti
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
                      'Nuovo Appuntamento',
                      style: Theme.of(context).textTheme.headlineSmall,
                    ),
                  ],
                ),
                const SizedBox(height: 20),

                // Operatore
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
                        'Operatore: ${operator.name}',
                        style: TextStyle(
                          fontWeight: FontWeight.w600,
                          color: operator.color,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 16),

                // Orario inizio
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
                      labelText: 'Orario Inizio',
                      border: OutlineInputBorder(),
                      prefixIcon: Icon(Symbols.schedule_rounded),
                    ),
                    child: Text(DateFormat('HH:mm').format(selectedStartTime)),
                  ),
                ),
                const SizedBox(height: 12),

                // Durata
                DropdownButtonFormField<int>(
                  initialValue: durationMinutes,
                  decoration: const InputDecoration(
                    labelText: 'Durata',
                    border: OutlineInputBorder(),
                    prefixIcon: Icon(Symbols.timer_rounded),
                  ),
                  items: [15, 30, 45, 60, 90, 120]
                      .map(
                        (final minutes) => DropdownMenuItem(
                          value: minutes,
                          child: Text('$minutes minuti'),
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

                // Nome cliente
                TextField(
                  controller: clientNameController,
                  decoration: const InputDecoration(
                    labelText: 'Nome Cliente',
                    border: OutlineInputBorder(),
                    prefixIcon: Icon(Symbols.person_rounded),
                  ),
                  textCapitalization: TextCapitalization.words,
                ),
                const SizedBox(height: 12),

                // Servizio
                TextField(
                  controller: serviceController,
                  decoration: const InputDecoration(
                    labelText: 'Servizio',
                    border: OutlineInputBorder(),
                    prefixIcon: Icon(Symbols.cut_rounded),
                  ),
                  textCapitalization: TextCapitalization.sentences,
                ),
                const SizedBox(height: 20),

                // Azioni
                Row(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    TextButton(
                      onPressed: () => Navigator.pop(context),
                      child: const Text('Annulla'),
                    ),
                    const SizedBox(width: 8),
                    FilledButton.icon(
                      icon: const Icon(Symbols.check_rounded),
                      label: const Text('Salva'),
                      onPressed: () {
                        if (clientNameController.text.trim().isEmpty) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(
                              content: Text('Inserisci il nome del cliente'),
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

                        // TODO: Salva nel database
                        // await ref.read(appointmentsRepositoryProvider)
                        //     .createAppointment(newAppointment);

                        Navigator.pop(context);

                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(
                            content: const Text('Appuntamento creato'),
                            action: SnackBarAction(
                              label: 'Annulla',
                              onPressed: () {
                                setState(() {
                                  _appointments.removeWhere(
                                    (final a) => a.id == newAppointment.id,
                                  );
                                });
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

  // TODO: Connetti al tuo repository per modificare appuntamenti
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
              const Expanded(child: Text('Modifica Appuntamento')),
            ],
          ),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Operatore
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
                    ],
                  ),
                ),
                const SizedBox(height: 16),
                // Orario inizio
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
                      labelText: 'Orario Inizio',
                      border: OutlineInputBorder(),
                      prefixIcon: Icon(Symbols.schedule_rounded),
                    ),
                    child: Text(DateFormat('HH:mm').format(selectedStartTime)),
                  ),
                ),
                const SizedBox(height: 12),
                // Durata
                DropdownButtonFormField<int>(
                  initialValue: durationMinutes,
                  decoration: const InputDecoration(
                    labelText: 'Durata',
                    border: OutlineInputBorder(),
                    prefixIcon: Icon(Symbols.timer_rounded),
                  ),
                  items: [15, 30, 45, 60, 90, 120]
                      .map(
                        (final minutes) => DropdownMenuItem(
                          value: minutes,
                          child: Text('$minutes minuti'),
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
                // Nome cliente
                TextField(
                  controller: clientNameController,
                  decoration: const InputDecoration(
                    labelText: 'Nome Cliente',
                    border: OutlineInputBorder(),
                    prefixIcon: Icon(Symbols.person_rounded),
                  ),
                ),
                const SizedBox(height: 12),
                // Servizio
                TextField(
                  controller: serviceController,
                  decoration: const InputDecoration(
                    labelText: 'Servizio',
                    border: OutlineInputBorder(),
                    prefixIcon: Icon(Symbols.cut_rounded),
                  ),
                ),
              ],
            ),
          ),
          actions: [
            TextButton.icon(
              icon: const Icon(Symbols.delete_rounded),
              label: const Text('Elimina'),
              onPressed: () {
                Navigator.pop(context);
                _deleteAppointment(apt);
              },
              style: TextButton.styleFrom(
                foregroundColor: Theme.of(context).colorScheme.error,
              ),
            ),
            const Spacer(),
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Annulla'),
            ),
            FilledButton.icon(
              icon: const Icon(Symbols.check_rounded),
              label: const Text('Salva'),
              onPressed: () {
                if (clientNameController.text.trim().isEmpty) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text('Inserisci il nome del cliente'),
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

                // TODO: Aggiorna nel database
                // await ref.read(appointmentsRepositoryProvider)
                //     .updateAppointment(_appointments[index]);

                Navigator.pop(context);

                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Appuntamento aggiornato')),
                );
              },
            ),
          ],
        ),
      ),
    );
  }

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
              title: const Text('Modifica'),
              onTap: () {
                Navigator.pop(context);
                _showAppointmentDetailsDialog(apt, operator);
              },
            ),
            ListTile(
              leading: const Icon(Symbols.content_copy_rounded),
              title: const Text('Copia'),
              onTap: () {
                Navigator.pop(context);
                _copyAppointment(apt);
              },
            ),
            ListTile(
              leading: const Icon(Symbols.content_cut_rounded),
              title: const Text('Taglia'),
              onTap: () {
                Navigator.pop(context);
                _cutAppointment(apt);
              },
            ),
            if (_clipboardAppointment != null)
              ListTile(
                leading: const Icon(Symbols.content_paste_rounded),
                title: const Text('Incolla qui'),
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
                'Elimina',
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

    // TODO: Aggiorna nel database
    // await ref.read(appointmentsRepositoryProvider)
    //     .updateAppointment(_appointments[index]);

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('Appuntamento spostato per ${targetOperator.name}'),
        duration: const Duration(seconds: 2),
      ),
    );
  }

  void _copyAppointment(final Appointment apt) {
    setState(() {
      _clipboardAppointment = apt;
    });

    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text(
          'Appuntamento copiato - Long press su uno slot per incollare',
        ),
        duration: Duration(seconds: 3),
      ),
    );
  }

  void _cutAppointment(final Appointment apt) {
    setState(() {
      _clipboardAppointment = apt;
      _appointments.removeWhere((final a) => a.id == apt.id);
    });

    // TODO: Elimina dal database
    // await ref.read(appointmentsRepositoryProvider).deleteAppointment(apt.id);

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: const Text(
          'Appuntamento tagliato - Long press su uno slot per incollare',
        ),
        duration: const Duration(seconds: 3),
        action: SnackBarAction(
          label: 'Annulla',
          onPressed: () {
            setState(() {
              if (_clipboardAppointment != null) {
                _appointments.add(_clipboardAppointment!);
                _clipboardAppointment = null;
              }
            });
          },
        ),
      ),
    );
  }

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
    });

    // TODO: Salva nel database
    // await ref.read(appointmentsRepositoryProvider)
    //     .createAppointment(newAppointment);

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('Appuntamento incollato per ${targetOperator.name}'),
        duration: const Duration(seconds: 2),
      ),
    );
  }

  void _deleteAppointment(final Appointment apt) {
    // Salva per undo
    final deletedAppointment = apt;
    final deletedIndex = _appointments.indexOf(apt);

    setState(() {
      _appointments.removeWhere((final a) => a.id == apt.id);
    });

    // TODO: Elimina dal database
    // await ref.read(appointmentsRepositoryProvider).deleteAppointment(apt.id);

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: const Text('Appuntamento eliminato'),
        action: SnackBarAction(
          label: 'Annulla',
          onPressed: () {
            setState(() {
              if (deletedIndex >= 0 && deletedIndex <= _appointments.length) {
                _appointments.insert(deletedIndex, deletedAppointment);
              } else {
                _appointments.add(deletedAppointment);
              }
            });

            // TODO: Ripristina nel database
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

extension DateTimeComparison on DateTime {
  bool isAtOrAfter(final DateTime other) =>
      isAfter(other) || isAtSameMomentAs(other);
}
