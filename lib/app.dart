import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:go_router/go_router.dart';

import 'core/app_routes.dart';
import 'core/theme/app_theme.dart';
import 'generated/l10n.dart';
import 'home/home.dart';

class BeautyCenterApp extends StatelessWidget {
  BeautyCenterApp({super.key});

  final _router = GoRouter(
    initialLocation: '${AppRoutes.home.path}${AppRoutes.appointments.path}',
    routes: [
      GoRoute(
        path: '${AppRoutes.home.path}/:tab',
        pageBuilder: (context, state) {
          final tab = state.pathParameters['tab'] ?? 'appointments';
          return MaterialPage(child: Home(initialTab: tab));
        },
      ),
    ],
  );

  @override
  Widget build(BuildContext context) {
    return MaterialApp.router(
      localizationsDelegates: [
        S.delegate,
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
      supportedLocales: S.delegate.supportedLocales,
      title: 'Beauty Center',
      theme: AppTheme.light,
      darkTheme: AppTheme.dark,
      themeMode: ThemeMode.system,
      debugShowCheckedModeBanner: false,
      routerConfig: _router,
    );
  }
}
