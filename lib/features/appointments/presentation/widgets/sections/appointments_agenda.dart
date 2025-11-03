import 'package:beauty_center/core/database/app_database.dart';
import 'package:beauty_center/features/settings/presentation/providers/settings_provider.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:infinite_calendar_view/infinite_calendar_view.dart';
import 'package:intl/intl.dart';
import 'package:material_symbols_icons/symbols.dart';
import 'package:syncfusion_flutter_datepicker/datepicker.dart';

import '../../../../../core/constants/app_constants.dart';
import '../../../../../core/widgets/custom_snackbar.dart';

// ============================================================================
// HOLIDAYS
// ============================================================================

DateTime easterCalculator(final int year) {
  final a = year % 19;
  final b = year ~/ 100;
  final c = year % 100;
  final d = b ~/ 4;
  final e = b % 4;
  final f = (b + 8) ~/ 25;
  final g = (b - f + 1) ~/ 3;
  final h = (19 * a + b - d - g + 15) % 30;
  final i = c ~/ 4;
  final k = c % 4;
  final l = (32 + 2 * e + 2 * i - h - k) % 7;
  final m = (a + 11 * h + 22 * l) ~/ 451;
  final month = (h + l - 7 * m + 114) ~/ 31;
  final day = ((h + l - 7 * m + 114) % 31) + 1;
  return DateTime(year, month, day);
}

List<DateTime> holidayItaly(final int year) {
  final easter = easterCalculator(year);
  final easterMonday = easter.add(const Duration(days: 1));

  return [
    DateTime(year), // Capodanno
    DateTime(year, 1, 6), // Epifania
    easter, // Pasqua
    easterMonday, // Pasquetta
    DateTime(year, 4, 25), // Festa della Liberazione
    DateTime(year, 5), // Festa dei Lavoratori
    DateTime(year, 6, 2), // Festa della Repubblica
    DateTime(year, 8, 15), // Assunzione di Maria
    DateTime(year, 11), // Ognissanti
    DateTime(year, 12, 8), // Immacolata Concezione
    DateTime(year, 12, 25), // Natale
    DateTime(year, 12, 26), // Santo Stefano
  ];
}

List<DateTime> allHolidaysItaly() {
  final days = <DateTime>[];

  for (var year = kMinYearCalendar; year <= kMaxYearCalendar; year++) {
    days.addAll(holidayItaly(year));
  }

  days.sort((final a, final b) => a.compareTo(b));
  return days.toSet().toList();
}

// ============================================================================
// MAIN WIDGET
// ============================================================================

class AppointmentsAgenda extends ConsumerStatefulWidget {
  const AppointmentsAgenda({super.key});

  @override
  ConsumerState<AppointmentsAgenda> createState() => _AppointmentsAgendaState();
}

class _AppointmentsAgendaState extends ConsumerState<AppointmentsAgenda> {
  late DateTime _selectedDay;
  late ScrollController _verticalScrollController;
  late double _heightPerMinute;
  late double _initialVerticalScrollOffset;

  final _oneDayViewKey = GlobalKey<EventsPlannerState>();

  final _controller = EventsController();

  @override
  void initState() {
    super.initState();
    _selectedDay = _normalizeDate(DateTime.now());
    _controller.focusedDay = _selectedDay;

    _verticalScrollController = ScrollController();

    _heightPerMinute = 1.5;
    _initialVerticalScrollOffset = _heightPerMinute * 7 * 60;
  }

  @override
  void dispose() {
    _verticalScrollController.dispose();
    _controller.dispose();
    super.dispose();
  }

  DateTime _normalizeDate(final DateTime date) =>
      DateTime(date.year, date.month, date.day);

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
              SizedBox(height: kIsWindows ? 0 : 6.h),
              _buildTopBar(colorScheme),
              SizedBox(height: kIsWindows ? 4 : 6.h),
              Expanded(
                child: _buildCalendar(colorScheme, operators, workHours),
              ),
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
              blurRadius: 12,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        padding: EdgeInsets.symmetric(
          horizontal: kIsWindows ? 6 : 4.w,
          vertical: kIsWindows ? 6 : 4.h,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
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
                        borderRadius: BorderRadius.circular(
                          kIsWindows ? 10 : 10.r,
                        ),
                      ),
                    ),
                    onPressed: () {
                      setState(() {
                        _selectedDay = _normalizeDate(
                          _selectedDay.subtract(const Duration(days: 1)),
                        );
                        _controller.updateFocusedDay(_selectedDay);
                        _oneDayViewKey.currentState?.jumpToDate(_selectedDay);
                      });
                    },
                  ),
                ),
                SizedBox(width: kIsWindows ? 8 : 8.w),
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
                      onPressed: () async {
                        await showDialog<DateTime>(
                          context: context,
                          builder: (final context) => AlertDialog(
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(
                                kIsWindows ? 18 : 18.r,
                              ),
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
                                const Text('Seleziona una data'),
                                // TODO: localize
                              ],
                            ),
                            content: SizedBox(
                              width: kIsWindows ? 400 : 400.w,
                              height: kIsWindows ? 600 : 600.h,
                              child: SfDateRangePicker(
                                backgroundColor:
                                    colorScheme.surfaceContainerHigh,
                                extendableRangeSelectionDirection:
                                    ExtendableRangeSelectionDirection.none,
                                navigationDirection:
                                    DateRangePickerNavigationDirection.vertical,
                                navigationMode:
                                    DateRangePickerNavigationMode.scroll,
                                minDate: DateTime(kMinYearCalendar),
                                maxDate: DateTime(kMaxYearCalendar, 12, 31),
                                initialDisplayDate: _selectedDay,
                                initialSelectedDate: _selectedDay,
                                showNavigationArrow: true,
                                enableMultiView: true,
                                headerStyle: DateRangePickerHeaderStyle(
                                  backgroundColor:
                                      colorScheme.surfaceContainerHigh,
                                  textAlign: TextAlign.center,
                                  textStyle: TextStyle(
                                    fontSize: kIsWindows ? 20 : 20.sp,
                                  ),
                                ),
                                monthViewSettings:
                                    DateRangePickerMonthViewSettings(
                                      viewHeaderStyle:
                                          DateRangePickerViewHeaderStyle(
                                            backgroundColor: colorScheme
                                                .surfaceContainerHigh,
                                            textStyle: TextStyle(
                                              color: colorScheme.onSurface,
                                            ),
                                          ),
                                      firstDayOfWeek: 1,
                                      // TODO localize
                                      showTrailingAndLeadingDates: true,
                                      weekendDays: const [7, 1],
                                      specialDates: allHolidaysItaly().where((
                                        final date,
                                      ) {
                                        final today = DateTime.now();
                                        return !(date.year == today.year &&
                                            date.month == today.month &&
                                            date.day == today.day);
                                      }).toList(), // TODO localize
                                    ),
                                monthCellStyle: DateRangePickerMonthCellStyle(
                                  textStyle: TextStyle(
                                    fontSize: kIsWindows ? 16 : 16.sp,
                                  ),
                                  trailingDatesTextStyle: TextStyle(
                                    fontSize: kIsWindows ? 16 : 16.sp,
                                  ),
                                  leadingDatesTextStyle: TextStyle(
                                    fontSize: kIsWindows ? 16 : 16.sp,
                                  ),
                                  todayTextStyle: TextStyle(
                                    fontSize: kIsWindows ? 16 : 16.sp,
                                  ),
                                  weekendDatesDecoration: BoxDecoration(
                                    color: colorScheme.surfaceContainerHighest,
                                    borderRadius: BorderRadius.circular(
                                      kIsWindows ? 8 : 8.r,
                                    ),
                                  ),
                                  weekendTextStyle: TextStyle(
                                    color: colorScheme.tertiary,
                                    fontSize: kIsWindows ? 16 : 16.sp,
                                  ),
                                  specialDatesDecoration: BoxDecoration(
                                    color: colorScheme.surfaceContainerHighest,
                                    borderRadius: BorderRadius.circular(
                                      kIsWindows ? 8 : 8.r,
                                    ),
                                  ),
                                  specialDatesTextStyle: TextStyle(
                                    color: colorScheme.tertiary,
                                    fontSize: kIsWindows ? 16 : 16.sp,
                                  ),
                                ),
                                selectionTextStyle: TextStyle(
                                  fontSize: kIsWindows ? 16 : 16.sp,
                                ),
                                showTodayButton: true,
                                onSelectionChanged: (final args) {
                                  if (args.value is DateTime) {
                                    Navigator.pop(context);
                                    setState(() {
                                      _selectedDay = _normalizeDate(
                                        args.value as DateTime,
                                      );
                                      _controller.updateFocusedDay(
                                        _selectedDay,
                                      );
                                      _oneDayViewKey.currentState?.jumpToDate(
                                        _selectedDay,
                                      );
                                    });
                                  }
                                },
                              ),
                            ),
                          ),
                        );
                      },
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
                        borderRadius: BorderRadius.circular(
                          kIsWindows ? 10 : 10.r,
                        ),
                      ),
                    ),
                    onPressed: () {
                      setState(() {
                        _selectedDay = _normalizeDate(
                          _selectedDay.add(const Duration(days: 1)),
                        );
                        _controller.updateFocusedDay(_selectedDay);
                        _oneDayViewKey.currentState?.jumpToDate(_selectedDay);
                      });
                    },
                  ),
                ),
                SizedBox(width: kIsWindows ? 8 : 6.w),
                SizedBox(
                  height: buttonHeight,
                  child: FilledButton.icon(
                    // icon: Icon(
                    //   Symbols.today_rounded,
                    //   size: kIsWindows ? 24 : 24.sp,
                    //   weight: 500,
                    //   fill: 1,
                    // ),
                    label: const Text('OGGI'), // TODO: localize
                    style: FilledButton.styleFrom(
                      padding: EdgeInsets.symmetric(
                        horizontal: kIsWindows ? 10 : 10.w,
                      ),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(
                          kIsWindows ? 10 : 10.r,
                        ),
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
                    onPressed: () {
                      setState(() {
                        _selectedDay = _normalizeDate(DateTime.now());
                        _controller.updateFocusedDay(_selectedDay);
                        _oneDayViewKey.currentState?.jumpToDate(_selectedDay);
                      });
                    },
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  // ==========================================================================
  // CALENDAR GRID
  // ==========================================================================
  Widget _buildCalendar(
    final ColorScheme colorScheme,
    final List<Operator> operators,
    final WorkHours workHours,
  ) => Row(
    children: [
      Expanded(
        child: EventsPlanner(
          initialDate: _selectedDay,
          key: _oneDayViewKey,
          controller: _controller,
          daysShowed: 1,
          heightPerMinute: _heightPerMinute,
          initialVerticalScrollOffset: _initialVerticalScrollOffset,
          currentHourIndicatorParam: CurrentHourIndicatorParam(
            currentHourIndicatorColor: colorScheme.primary,
          ),
          timesIndicatorsParam: const TimesIndicatorsParam(
            timesIndicatorsWidth: 40,
            timesIndicatorsHorizontalPadding: 2,
          ),
          daysHeaderParam: DaysHeaderParam(
            daysHeaderVisibility: false,
            daysHeaderColor: colorScheme.surfaceContainerHighest,
          ),
          fullDayParam: const FullDayParam(fullDayEventsBarVisibility: false),
          columnsParam: ColumnsParam(
            columns: operators.length,
            maxColumns: operators.length,
            columnsWidthRatio: List.filled(
              operators.length,
              1 / operators.length,
            ),
            columnsLabels: operators.map((final op) => op.name).toList(),
            columnsColors: List.filled(
              operators.length,
              colorScheme.primaryContainer,
            ),
          ),
          offTimesParam: OffTimesParam(
            offTimesColor: colorScheme.primary.withValues(alpha: 0.1),
            offTimesAllDaysRanges: [
              OffTimeRange(
                const TimeOfDay(hour: 0, minute: 0),
                TimeOfDay(hour: workHours.startHr, minute: workHours.startMin),
              ),
              OffTimeRange(
                TimeOfDay(hour: workHours.endHr, minute: workHours.endMin),
                const TimeOfDay(hour: 24, minute: 00),
              ),
            ],
          ),
          dayParam: DayParam(
            dayColor: colorScheme.surfaceContainer,
            todayColor: colorScheme.surfaceContainer,
            dayBottomPadding: kBottomNavigationBarHeight + 45.h,
            onSlotTap:
                (final columnIndex, final exactDateTime, final roundDateTime) {
                  showCustomSnackBar(context: context, message: '$columnIndex');
                  _controller.updateCalendarData((final calendarData) {
                    final event = Event(
                      title: 'Evento $columnIndex',
                      description: 'Descrizione evento $columnIndex',
                      columnIndex: columnIndex,
                      startTime: roundDateTime,
                      endTime: roundDateTime.add(const Duration(minutes: 60)),
                      data: exactDateTime,
                    );

                    calendarData.addEvents([event]);
                  });
                }, // TODO Dialog per prendere appuntamento
          ),
          onDayChange: (final newDay) => setState(() => _selectedDay = newDay),
        ),
      ),
    ],
  );
}
