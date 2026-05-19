import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:material_symbols_icons/symbols.dart';
import 'package:syncfusion_flutter_datepicker/datepicker.dart';

import '../../../../../core/constants/app_constants.dart';
import '../../../../../core/localizations/utils_regions/italy_holidays.dart';

Future<DateTime?> showAppointmentsDatePickerDialog({
  required BuildContext context,
  required DateTime selectedDay,
}) async {
  final cs = Theme.of(context).colorScheme;
  DateTime? picked;

  await showDialog<void>(
    context: context,
    builder: (ctx) => AlertDialog(
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(kIsWindows ? 18 : 18.r),
      ),
      backgroundColor: cs.surfaceContainerHigh,
      title: Row(
        children: [
          Icon(
            Symbols.calendar_month_rounded,
            color: cs.primary,
            size: kIsWindows ? 22 : 22.sp,
            fill: 1,
          ),
          SizedBox(width: kIsWindows ? 8 : 8.w),
          const Text('Seleziona una data'),
        ],
      ),
      content: SizedBox(
        width: kIsWindows ? 400 : 400.w,
        height: kIsWindows ? 600 : 600.h,
        child: SfDateRangePicker(
          backgroundColor: cs.surfaceContainerHigh,
          navigationDirection: DateRangePickerNavigationDirection.vertical,
          navigationMode: DateRangePickerNavigationMode.scroll,
          minDate: DateTime(kMinCalendarYear),
          maxDate: DateTime(kMaxCalendarYear, 12, 31),
          initialDisplayDate: selectedDay,
          initialSelectedDate: selectedDay,
          showNavigationArrow: true,
          enableMultiView: true,
          headerStyle: DateRangePickerHeaderStyle(
            backgroundColor: cs.surfaceContainerHigh,
            textAlign: TextAlign.center,
            textStyle: TextStyle(fontSize: kIsWindows ? 20 : 20.sp),
          ),
          monthViewSettings: DateRangePickerMonthViewSettings(
            viewHeaderStyle: DateRangePickerViewHeaderStyle(
              backgroundColor: cs.surfaceContainerHigh,
              textStyle: TextStyle(color: cs.onSurface),
            ),
            firstDayOfWeek: 1,
            weekendDays: const [7, 1],
            specialDates: allHolidaysItaly(),
          ),
          monthCellStyle: DateRangePickerMonthCellStyle(
            textStyle: TextStyle(fontSize: kIsWindows ? 16 : 16.sp),
            weekendTextStyle: TextStyle(
              color: cs.error,
              fontSize: kIsWindows ? 16 : 16.sp,
            ),
            specialDatesTextStyle: TextStyle(
              color: cs.error,
              fontSize: kIsWindows ? 16 : 16.sp,
            ),
            todayTextStyle: TextStyle(fontSize: kIsWindows ? 16 : 16.sp),
          ),
          showTodayButton: true,
          onSelectionChanged: (args) {
            if (args.value is DateTime) {
              picked = args.value as DateTime;
              Navigator.of(ctx).pop();
            }
          },
          selectionTextStyle: TextStyle(fontSize: kIsWindows ? 16 : 16.sp),
        ),
      ),
    ),
  );

  return picked;
}
