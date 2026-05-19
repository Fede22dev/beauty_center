import 'package:beauty_center/core/constants/app_constants.dart';
import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:timely_x/timely_x.dart';

CalendarTheme buildAgendaTheme(ColorScheme cs) => CalendarTheme(
  // =========================================================================
  // Grid & Background Colors
  // =========================================================================
  gridBackgroundColor: cs.surface,
  headerBackgroundColor: cs.surface,
  timeColumnBackgroundColor: cs.surface,
  otherMonthGridBackgroundColor: cs.surfaceContainer,

  gridLineColor: cs.surfaceContainerHighest,
  hourLineColor: cs.outlineVariant,
  zebraStripeOdd: Colors.transparent,
  zebraStripeEven: cs.surfaceContainer,

  currentDayHighlight: cs.primaryContainer.withValues(alpha: 0.3),
  currentTimeIndicatorColor: cs.primary,
  selectedSlotColor: cs.primaryContainer,
  hoverColor: cs.surfaceContainerHighest.withValues(alpha: 0.5),

  weekendColor: cs.surfaceContainer,
  weekendTextColor: cs.error,
  todayHighlightColor: cs.primary,
  otherMonthDayColor: cs.onSurface.withValues(alpha: 0.38),

  // =========================================================================
  // Date Selection (Month View)
  // =========================================================================
  selectedDateBackgroundColor: cs.primary,
  selectedDateTextColor: cs.onPrimary,
  selectedDateBorderColor: cs.primary,
  rangeSelectionColor: cs.secondaryContainer.withValues(alpha: 0.5),
  rangeSelectionBorderColor: cs.secondaryContainer,

  // =========================================================================
  // Text Styles
  // =========================================================================
  timeTextStyle: TextStyle(
    fontSize: kIsWindows ? 13 : 13.sp,
    fontWeight: FontWeight.w500,
    color: cs.onSurfaceVariant,
  ),
  subHourTimeTextStyle: TextStyle(
    fontSize: kIsWindows ? 10 : 10.sp,
    fontWeight: FontWeight.w400,
    color: cs.onSurfaceVariant.withValues(alpha: 0.7),
  ),
  resourceNameStyle: TextStyle(
    fontSize: kIsWindows ? 14 : 10.sp,
    fontWeight: FontWeight.w600,
    color: cs.onSurface,
  ),
  dateTextStyle: TextStyle(
    fontSize: kIsWindows ? 16 : 16.sp,
    fontWeight: FontWeight.w600,
    color: cs.onSurface,
  ),
  weekdayTextStyle: TextStyle(
    fontSize: kIsWindows ? 12 : 12.sp,
    fontWeight: FontWeight.w500,
    color: cs.onSurfaceVariant,
  ),
  appointmentTextStyle: TextStyle(
    fontSize: kIsWindows ? 13 : 13.sp,
    fontWeight: FontWeight.w600,
    color: cs.onPrimary,
  ),
  appointmentSubtitleStyle: TextStyle(
    fontSize: kIsWindows ? 11 : 11.sp,
    fontWeight: FontWeight.w400,
    color: cs.onPrimary.withValues(alpha: 0.8),
  ),
  appointmentTimeStyle: TextStyle(
    fontSize: kIsWindows ? 10 : 10.sp,
    fontWeight: FontWeight.w500,
    color: cs.onPrimary.withValues(alpha: 0.9),
  ),
  monthViewDayTextStyle: TextStyle(
    fontSize: kIsWindows ? 14 : 14.sp,
    fontWeight: FontWeight.w500,
    color: cs.onSurface,
  ),
  monthViewAppointmentTextStyle: TextStyle(
    fontSize: kIsWindows ? 10 : 10.sp,
    fontWeight: FontWeight.w500,
    color: cs.onPrimary,
  ),
  monthViewMoreTextStyle: TextStyle(
    fontSize: kIsWindows ? 11 : 11.sp,
    fontWeight: FontWeight.w500,
    color: cs.primary,
  ),

  // =========================================================================
  // Agenda View
  // =========================================================================
  agendaItemBackgroundColor: cs.surfaceContainer,
  agendaItemHoverColor: cs.surfaceContainerHigh,
  agendaItemSelectedColor: cs.primaryContainer,
  agendaDateHeaderBackgroundColor: cs.surface,
  agendaResourceHeaderBackgroundColor: cs.surfaceContainerLowest,
  agendaDividerColor: cs.outlineVariant.withValues(alpha: 0.5),
  agendaEmptyBackgroundColor: cs.surface,

  agendaDateHeaderTextStyle: TextStyle(
    fontSize: kIsWindows ? 14 : 14.sp,
    fontWeight: FontWeight.w600,
    color: cs.primary,
  ),
  agendaResourceHeaderTextStyle: TextStyle(
    fontSize: kIsWindows ? 14 : 14.sp,
    fontWeight: FontWeight.w500,
    color: cs.onSurfaceVariant,
  ),
  agendaTimeTextStyle: TextStyle(
    fontSize: kIsWindows ? 12 : 12.sp,
    fontWeight: FontWeight.w500,
    color: cs.onSurfaceVariant,
  ),
  agendaTitleTextStyle: TextStyle(
    fontSize: kIsWindows ? 15 : 15.sp,
    fontWeight: FontWeight.w600,
    color: cs.onSurface,
  ),
  agendaSubtitleTextStyle: TextStyle(
    fontSize: kIsWindows ? 13 : 13.sp,
    color: cs.onSurfaceVariant,
  ),
  agendaDurationTextStyle: TextStyle(
    fontSize: kIsWindows ? 11 : 11.sp,
    color: cs.onSurfaceVariant.withValues(alpha: 0.8),
  ),
  agendaEmptyTextStyle: TextStyle(
    fontSize: kIsWindows ? 14 : 14.sp,
    fontStyle: FontStyle.italic,
    color: cs.onSurfaceVariant,
  ),

  // =========================================================================
  // Decorations & Shapes (Material 3 Style)
  // =========================================================================
  appointmentBorderRadius: kIsWindows ? 8 : 8.r,
  agendaItemBorderRadius: kIsWindows ? 12 : 12.r,
  monthViewAppointmentBorderRadius: kIsWindows ? 4 : 4.r,
  resourceAvatarRadius: kIsWindows ? 24 : 24.r,
  appointmentMargin: EdgeInsets.fromLTRB(0, 0, kIsWindows ? 35 : 35.w, 0),

  appointmentShadow: [
    BoxShadow(
      color: cs.shadow.withValues(alpha: 0.1),
      blurRadius: kIsWindows ? 4 : 4.r,
      offset: const Offset(0, 2),
    ),
  ],
  agendaItemShadow: [
    BoxShadow(
      color: cs.shadow.withValues(alpha: 0.05),
      blurRadius: kIsWindows ? 8 : 8.r,
      offset: const Offset(0, 2),
    ),
  ],

  // =========================================================================
  // Drag & Drop
  // =========================================================================
  dragPlaceholderBorderColor: cs.primary.withValues(alpha: 0.5),
  dragPlaceholderOpacity: 0.2,
  dragFeedbackOpacity: 0.9,

  // =========================================================================
  // Scrollbar & Badges
  // =========================================================================
  scrollbarTheme: CalendarScrollbarTheme(
    scrollbarThumbColor: cs.outlineVariant,
    scrollbarTrackColor: cs.surfaceContainerLowest,
    scrollbarThickness: 6,
    scrollbarRadius: Radius.circular(kIsWindows ? 8 : 8.r),
  ),
  appointmentCountBadgeTheme: CalendarAppointmentCountBadgeTheme(
    appointmentCountBackgroundColor: cs.error,
    appointmentCountTextStyle: TextStyle(
      color: cs.onError,
      fontSize: kIsWindows ? 10 : 10.sp,
      fontWeight: FontWeight.bold,
    ),
    appointmentCountBorderRadius: kIsWindows ? 8 : 8.r,
  ),
);
