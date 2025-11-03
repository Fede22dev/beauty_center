import 'package:beauty_center/features/appointments/presentation/widgets/sections/appointments_agenda.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';

import '../../../../core/constants/app_constants.dart';
import '../../../../core/logging/app_logger.dart';

class AppointmentsPage extends ConsumerStatefulWidget {
  const AppointmentsPage({super.key});

  @override
  ConsumerState<AppointmentsPage> createState() => _AppointmentsPageState();
}

class _AppointmentsPageState extends ConsumerState<AppointmentsPage>
    with AutomaticKeepAliveClientMixin {
  @override
  bool get wantKeepAlive => true;

  static final log = AppLogger.getLogger(name: 'AppointmentsPage');

  @override
  Widget build(final BuildContext context) {
    super.build(context);
    log.fine('build');

    return Padding(
      padding: EdgeInsets.symmetric(
        horizontal: kIsWindows ? 16 : 8.h,
        vertical: kIsWindows ? 10 : 0,
      ),
      child: const AppointmentsAgenda(),
    );
  }
}
