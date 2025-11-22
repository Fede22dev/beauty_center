import 'package:beauty_center/core/localizations/extensions/l10n_extensions.dart';
import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:material_symbols_icons/symbols.dart';

import '../../../../core/constants/app_constants.dart';
import '../../../../core/logging/app_logger.dart';

class SettingsErrorView extends StatelessWidget {
  const SettingsErrorView({
    required this.error,
    required this.onRetry,
    super.key,
  });

  final String error;
  final VoidCallback onRetry;

  static final log = AppLogger.getLogger(name: 'SettingsErrorView');

  @override
  Widget build(final BuildContext context) {
    log.severe('ErrorView displayed with error:', error, StackTrace.current);

    return Center(
      child: Padding(
        padding: EdgeInsets.all(kIsWindows ? 24 : 24.w),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Symbols.error_outline,
              size: kIsWindows ? 64 : 64.sp,
              color: Colors.red,
            ),
            SizedBox(height: kIsWindows ? 16 : 16.h),
            Text(
              context.l10n.error,
              style: TextStyle(fontSize: kIsWindows ? 24 : 24.sp),
            ),
            SizedBox(height: kIsWindows ? 8 : 8.h),
            Text(
              error,
              style: TextStyle(fontSize: kIsWindows ? 16 : 16.sp),
              textAlign: TextAlign.center,
            ),
            SizedBox(height: kIsWindows ? 24 : 24.h),
            FilledButton.icon(
              onPressed: onRetry,
              icon: const Icon(Symbols.refresh),
              label: Text(context.l10n.retry),
            ),
          ],
        ),
      ),
    );
  }
}
