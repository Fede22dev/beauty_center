import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:go_router/go_router.dart';

import 'core/constants/app_constants.dart';
import 'core/router/app_routes.dart';
import 'core/theme/app_theme.dart';
import 'home/presentation/desktop/pages/home_page_desktop.dart';
import 'home/presentation/mobile/pages/home_page_mobile.dart';
import 'l10n/app_localizations.dart';

class BeautyCenterApp extends StatelessWidget {
  const BeautyCenterApp({super.key});

  GoRouter _buildRouter() => GoRouter(
    initialLocation: kDefaultRoute.path,
    redirect: (final context, final state) {
      final segments = state.uri.pathSegments;
      if (segments.isEmpty) return kDefaultRoute.path;
      if (!isValidTabSegment(segments.first)) return kDefaultRoute.path;
      return null;
    },
    routes: [
      GoRoute(
        path: '/:tab(appointments|clients|treatments|statistics|settings)',
        pageBuilder: (final context, final state) {
          final initial = state.pathParameters['tab'] ?? kDefaultRoute.segment;
          return MaterialPage(
            key: const ValueKey('home'),
            child: kTargetOsIsDesktop
                ? HomePageDesktop(initialSegment: initial)
                : HomePageMobile(initialSegment: initial),
          );
        },
      ),
    ],
  );

  @override
  Widget build(final BuildContext context) => ScreenUtilInit(
    designSize: const Size(390, 844), // Medium phone baseline
    minTextAdapt: true,
    splitScreenMode: true,
    builder: (_, _) {
      SystemChrome.setPreferredOrientations([
        DeviceOrientation.portraitUp,
        DeviceOrientation.portraitDown,
      ]);

      return MaterialApp.router(
        title: 'Beauty Center',
        debugShowCheckedModeBanner: false,
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        theme: AppTheme.light,
        darkTheme: AppTheme.dark,
        routerConfig: _buildRouter(),
      );
    },
  );
}
