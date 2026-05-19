import 'package:beauty_center/core/localizations/extensions/l10n_extensions.dart';
import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:material_symbols_icons/symbols.dart';

import '../../core/constants/app_constants.dart';
import '../../core/logging/app_logger.dart';

class AppErrorView extends StatelessWidget {
  const AppErrorView({
    required this.onRetry,
    this.error,
    this.message,
    this.isCompact = false,
    super.key,
  });

  /// L'errore tecnico (Exception, String, etc.) per il logging
  final Object? error;

  /// Messaggio amichevole opzionale da mostrare all'utente
  final String? message;

  /// Callback per il tasto riprova
  final VoidCallback onRetry;

  /// Se true, riduce le dimensioni (ideale per scroll infinito o piccoli box)
  final bool isCompact;

  static final _log = AppLogger.getLogger(name: 'AppErrorView');

  @override
  Widget build(final BuildContext context) {
    if (error != null) {
      _log.severe('Error displayed:', error, StackTrace.current);
    }

    final colorScheme = Theme.of(context).colorScheme;

    // Calcolo dimensioni responsive basato su kIsWindows e isCompact
    final iconSize = isCompact
        ? (kIsWindows ? 32.0 : 32.sp)
        : (kIsWindows ? 80.0 : 80.sp);

    final titleFontSize = isCompact
        ? (kIsWindows ? 16.0 : 16.sp)
        : (kIsWindows ? 22.0 : 22.sp);

    return Center(
      child: Padding(
        padding: EdgeInsets.all(isCompact ? 16 : 24.w),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Symbols.error_outline_rounded,
              size: iconSize,
              color: colorScheme.error,
            ),
            SizedBox(height: isCompact ? 8 : 16.h),
            Text(
              message ?? context.l10n.error,
              style: TextStyle(
                fontSize: titleFontSize,
                fontWeight: FontWeight.bold,
                color: colorScheme.onSurface,
              ),
              textAlign: TextAlign.center,
            ),
            if (error != null && !isCompact) ...[
              SizedBox(height: isCompact ? 8 : 8.h),
              Text(
                error.toString(),
                style: TextStyle(
                  fontSize: kIsWindows ? 14 : 14.sp,
                  color: colorScheme.outline,
                ),
                textAlign: TextAlign.center,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
            ],
            SizedBox(height: isCompact ? 12 : 24.h),
            if (isCompact)
              IconButton.filledTonal(
                onPressed: onRetry,
                icon: const Icon(Symbols.refresh_rounded),
              )
            else
              FilledButton.icon(
                onPressed: onRetry,
                icon: const Icon(Symbols.refresh_rounded),
                label: Text(context.l10n.retry),
              ),
          ],
        ),
      ),
    );
  }
}
