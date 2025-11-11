//file: appointments_page.dart
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

  late final ScrollController _scrollController;
  late final double _scrollbarThickness;
  var _isScrollbarNeeded = false;

  @override
  void initState() {
    super.initState();
    _scrollController = ScrollController();
    _scrollbarThickness = kIsWindows ? 8.0 : 0.0;
  }

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  @override
  Widget build(final BuildContext context) {
    super.build(context);

    // Scrollbar visibility management (Windows only)
    if (_scrollbarThickness > 0) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        final isNeeded =
            _scrollController.hasClients &&
            _scrollController.position.maxScrollExtent > 0;
        if (isNeeded != _isScrollbarNeeded && mounted) {
          setState(() => _isScrollbarNeeded = isNeeded);
        }
      });
    }

    log.fine('build');

    // Future.delayed(const Duration(seconds: 5), () {
    //   _scrollController.animateTo(
    //     300,
    //     duration: const Duration(milliseconds: 500),
    //     curve: Curves.easeIn,
    //   );
    // });

    return Padding(
      padding: EdgeInsets.symmetric(vertical: kIsWindows ? 10 : 0),
      child: Scrollbar(
        controller: _scrollController,
        thickness: _scrollbarThickness,
        thumbVisibility: kIsWindows,
        interactive: kIsWindows,
        child: SingleChildScrollView(
          controller: _scrollController,
          child: AnimatedPadding(
            duration: kDefaultAppAnimationsDuration,
            curve: Curves.easeOutCubic,
            padding: EdgeInsets.fromLTRB(
              kIsWindows ? 16 : 8.w,
              0,
              (kIsWindows ? 16 : 8.w) +
                  (_isScrollbarNeeded ? _scrollbarThickness : 0),
              0,
            ),
            child: Column(
              children: [
                SizedBox(height: kIsWindows ? 0 : 8.h),
                const AppointmentsAgenda(),
                SizedBox(
                  height: kIsWindows ? 0 : kBottomNavigationBarHeight + 28.h,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
