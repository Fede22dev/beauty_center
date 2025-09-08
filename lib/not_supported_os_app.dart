import 'package:beauty_center/l10n/app_localizations.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';

import 'core/providers/app_providers.dart';
import 'core/theme/app_theme.dart';

class NotSupportedOsApp extends ConsumerWidget {
  const NotSupportedOsApp({super.key});

  @override
  Widget build(final BuildContext context, final WidgetRef ref) =>
      ScreenUtilInit(
        designSize: const Size(390, 844), // Medium phone baseline
        minTextAdapt: true,
        splitScreenMode: true,
        builder: (_, _) {
          final locale = ref.watch(appLocaleProvider);
          return MaterialApp(
            title: 'Beauty Center',
            debugShowCheckedModeBanner: false,
            locale: locale,
            localizationsDelegates: AppLocalizations.localizationsDelegates,
            supportedLocales: AppLocalizations.supportedLocales,
            theme: AppTheme.light,
            darkTheme: AppTheme.dark,
            home: Builder(
              builder: (final context) {
                final colorScheme = Theme.of(context).colorScheme;

                return Scaffold(
                  backgroundColor: colorScheme.surface,
                  body: Center(
                    child: Text(
                      AppLocalizations.of(context)!.notSupportedOsMessage,
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontSize: 18.sp,
                        fontWeight: FontWeight.w600,
                        color: colorScheme.onSurface,
                      ),
                    ),
                  ),
                );
              },
            ),
          );
        },
      );
}
