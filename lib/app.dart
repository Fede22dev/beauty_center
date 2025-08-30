import 'package:flex_color_scheme/flex_color_scheme.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:go_router/go_router.dart';

import 'core/app_routes.dart';
import 'generated/l10n.dart';
import 'home/home.dart';

class BeautyCenterApp extends StatelessWidget {
  BeautyCenterApp({super.key});

  final _router = GoRouter(
    initialLocation: kDefaultRoute.path,
    redirect: (context, state) {
      final segments = state.uri.pathSegments;
      if (segments.isEmpty) return kDefaultRoute.path;
      if (!isValidTabSegment(segments.first)) return kDefaultRoute.path;
      return null;
    },
    routes: [
      GoRoute(
        path: '/:tab',
        pageBuilder: (context, state) {
          return MaterialPage(
            child: Home(initialSegment: kDefaultRoute.segment),
          );
        },
      ),
    ],
  );

  @override
  Widget build(BuildContext context) {
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
          theme: FlexThemeData.light(scheme: FlexScheme.purpleM3),
          darkTheme: FlexThemeData.dark(scheme: FlexScheme.purpleM3),
          themeMode: ThemeMode.system,
          routerConfig: _router,
        );
      },
    );
  }
}
