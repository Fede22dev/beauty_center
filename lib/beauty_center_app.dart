import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';

import 'core/constants/app_constants.dart';
import 'core/theme/app_theme.dart';
import 'home/presentation/home_loading_screen.dart';
import 'l10n/app_localizations.dart';

class BeautyCenterApp extends ConsumerWidget {
  const BeautyCenterApp({super.key});

  @override
  Widget build(final BuildContext context, final WidgetRef ref) =>
      ScreenUtilInit(
        designSize: const Size(384, 832), // Android S25 plus
        minTextAdapt: true,
        splitScreenMode: true,
        builder: (_, _) {
          if (!kIsWindows) {
            SystemChrome.setPreferredOrientations([
              DeviceOrientation.portraitUp,
              DeviceOrientation.portraitDown,
            ]);
          }

          return MaterialApp(
            title: 'Beauty Center',
            debugShowCheckedModeBanner: false,
            localizationsDelegates: AppLocalizations.localizationsDelegates,
            supportedLocales: AppLocalizations.supportedLocales,
            theme: AppTheme.light,
            darkTheme: AppTheme.dark,
            home: const HomeLoadingScreen(),
            builder: (final context, final child) => MediaQuery(
              data: MediaQuery.of(
                context,
              ).copyWith(alwaysUse24HourFormat: true),
              child: child!,
            ),
          );
        },
      );
}
