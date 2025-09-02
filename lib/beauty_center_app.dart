import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:go_router/go_router.dart';

import 'core/app_routes.dart';
import 'core/constants/app_constants.dart';
import 'core/theme/app_theme.dart';
import 'generated/l10n.dart';
import 'home/presentation/desktop/pages/home_page_desktop.dart';
import 'home/presentation/mobile/pages/home_page_mobile.dart';

class BeautyCenterApp extends StatelessWidget {
  const BeautyCenterApp({super.key});

  GoRouter _buildRouter() {
    return GoRouter(
      initialLocation: kDefaultRoute.path,
      redirect: (context, state) {
        final segments = state.uri.pathSegments;
        if (segments.isEmpty) return kDefaultRoute.path;
        if (!isValidTabSegment(segments.first)) return kDefaultRoute.path;
        return null;
      },
      routes: [
        GoRoute(
          path: '/:tab(appointments|clients|treatments|statistics|settings)',
          pageBuilder: (context, state) {
            final initial =
                state.pathParameters['tab'] ?? kDefaultRoute.segment;
            return MaterialPage(
              key: ValueKey('home'),
              child: kTargetOsIsDesktop
                  ? HomePageDesktop(initialSegment: initial)
                  : HomePageMobile(initialSegment: initial),
            );
          },
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    final router = _buildRouter();

    return ScreenUtilInit(
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
          localizationsDelegates: const [
            S.delegate,
            GlobalMaterialLocalizations.delegate,
            GlobalWidgetsLocalizations.delegate,
            GlobalCupertinoLocalizations.delegate,
          ],
          supportedLocales: S.delegate.supportedLocales,
          theme: AppTheme.light,
          darkTheme: AppTheme.dark,
          themeMode: ThemeMode.system,
          routerConfig: router,
        );
      },
    );
  }
}
