import 'package:beauty_center/core/constants/app_constants.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';

import '../../../../core/logging/app_logger.dart';
import '../../../../core/providers/offline_banner_provider.dart';
import '../../../../core/widgets/error_view.dart';
import '../../../../core/widgets/offline_banner.dart';
import '../providers/settings_provider.dart';
import '../widgets/sections/settings_cabins.dart';
import '../widgets/sections/settings_operators.dart';
import '../widgets/sections/settings_work_hours.dart';

class SettingsPage extends ConsumerStatefulWidget {
  const SettingsPage({super.key});

  @override
  ConsumerState<SettingsPage> createState() => _SettingsPageState();
}

class _SettingsPageState extends ConsumerState<SettingsPage>
    with AutomaticKeepAliveClientMixin {
  @override
  bool get wantKeepAlive => true;

  static final log = AppLogger.getLogger(name: 'SettingsPage');

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
    final bannerState = ref.watch(offlineBannerProvider);

    final cabinsAsync = ref.watch(cabinsStreamProvider);
    final operatorsAsync = ref.watch(operatorsStreamProvider);
    final workHoursAsync = ref.watch(workHoursStreamProvider);

    // Error handling
    if (cabinsAsync.hasError ||
        operatorsAsync.hasError ||
        workHoursAsync.hasError) {
      return ErrorView(
        error:
            (cabinsAsync.error ?? operatorsAsync.error ?? workHoursAsync.error)
                .toString(),
        onRetry: () {
          ref
            ..invalidate(cabinsStreamProvider)
            ..invalidate(operatorsStreamProvider)
            ..invalidate(workHoursStreamProvider);
        },
      );
    }

    // Loading state
    if (!cabinsAsync.hasValue ||
        !operatorsAsync.hasValue ||
        !workHoursAsync.hasValue) {
      return const Center(child: CircularProgressIndicator());
    }

    final cabins = cabinsAsync.value!;
    final operators = operatorsAsync.value!;
    final workHours = workHoursAsync.value!;

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

    return OfflineBanner(
      child: Padding(
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
                  AnimatedSize(
                    duration: kDefaultAppAnimationsDuration,
                    curve: Curves.easeInOut,
                    child: SizedBox(
                      height: bannerState.isVisible
                          ? kDefaultAppBannerOfflineHeight
                          : 0,
                    ),
                  ),
                  CabinsSection(cabins: cabins),
                  SizedBox(height: kIsWindows ? 8 : 8.h),
                  OperatorsSection(operators: operators),
                  SizedBox(height: kIsWindows ? 8 : 8.h),
                  WorkHoursSection(workHours: workHours),
                  SizedBox(
                    height: kIsWindows ? 0 : kBottomNavigationBarHeight + 28.h,
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
