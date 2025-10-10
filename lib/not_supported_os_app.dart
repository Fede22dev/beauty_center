import 'package:beauty_center/core/constants/app_constants.dart';
import 'package:beauty_center/core/localizations/extensions/l10n_extensions.dart';
import 'package:beauty_center/l10n/app_localizations.dart';
import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';

import 'core/theme/app_theme.dart';

class NotSupportedOsApp extends StatelessWidget {
  const NotSupportedOsApp({super.key});

  @override
  Widget build(final BuildContext context) => ScreenUtilInit(
    designSize: const Size(384, 832), // Android S25 plus
    minTextAdapt: true,
    splitScreenMode: true,
    builder: (_, _) => MaterialApp(
      title: 'Beauty Center',
      debugShowCheckedModeBanner: false,
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      theme: AppTheme.light,
      darkTheme: AppTheme.dark,
      home: const _NotSupportedOsPage(),
    ),
  );
}

class _NotSupportedOsPage extends StatelessWidget {
  const _NotSupportedOsPage();

  @override
  Widget build(final BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return Scaffold(
      backgroundColor: colorScheme.surface,
      body: Center(
        child: Text(
          context.l10n.notSupportedOsMessage,
          textAlign: TextAlign.center,
          style: TextStyle(
            fontSize: kIsWindows ? 20 : 18.sp,
            fontWeight: FontWeight.w600,
            color: colorScheme.onSurface,
          ),
        ),
      ),
    );
  }
}
