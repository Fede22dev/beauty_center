import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';

import 'core/constants/app_constants.dart';
import 'core/theme/app_theme.dart';
import 'home/presentation/desktop/pages/home_page_desktop.dart';
import 'home/presentation/mobile/pages/home_page_mobile.dart';
import 'l10n/app_localizations.dart';

class BeautyCenterApp extends StatelessWidget {
  const BeautyCenterApp({super.key});

  @override
  Widget build(final BuildContext context) => ScreenUtilInit(
    designSize: const Size(390, 844), // Medium phone baseline
    minTextAdapt: true,
    splitScreenMode: true,
    builder: (_, _) {
      if (!kIsDesktop) {
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
        home: kIsDesktop ? const HomePageDesktop() : const HomePageMobile(),
        builder: (final context, final child) => MediaQuery(
          data: MediaQuery.of(context).copyWith(alwaysUse24HourFormat: true),
          child: child!,
        ),
      );
    },
  );
}
