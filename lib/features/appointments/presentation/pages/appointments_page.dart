import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:timely_x/timely_x.dart';

import '../../../../core/constants/app_constants.dart';
import '../../../../core/logging/app_logger.dart';
import '../widgets/sections/appointments_agenda.dart';
import '../widgets/sections/appointments_top_bar.dart';

class AppointmentsPage extends ConsumerStatefulWidget {
  const AppointmentsPage({super.key});

  @override
  ConsumerState<AppointmentsPage> createState() => _AppointmentsPageState();
}

class _AppointmentsPageState extends ConsumerState<AppointmentsPage>
    with AutomaticKeepAliveClientMixin {
  @override
  bool get wantKeepAlive => true;

  static final _log = AppLogger.getLogger(name: 'AppointmentsPage');

  late final CalendarController _calendarController;

  @override
  void initState() {
    super.initState();
    _calendarController = CalendarController(
      initialDate: DateTime.now(),
      config: const CalendarConfig(viewType: CalendarViewType.day),
    );
  }

  @override
  void dispose() {
    _calendarController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    super.build(context);
    _log.finest('build');

    return Column(
      children: [
        // Top bar
        Padding(
          padding: EdgeInsets.fromLTRB(
            kIsWindows ? 16 : 8.w,
            kIsWindows ? 10 : 8.h,
            kIsWindows ? 16 : 8.w,
            kIsWindows ? 8 : 6.h,
          ),
          child: AppointmentsTopBar(_calendarController),
        ),

        // Agenda (calendario)
        Expanded(
          child: Padding(
            padding: EdgeInsets.fromLTRB(
              kIsWindows ? 16 : 0,
              0,
              kIsWindows ? 16 : 0,
              kIsWindows ? 8 : 80.h,
            ),
            child: AppointmentsAgenda(_calendarController),
          ),
        ),
      ],
    );
  }
}
