import 'dart:async';

import 'package:beauty_center/core/utils/navigator_key.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_fgbg/flutter_fgbg.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';

import 'core/connectivity/connectivity_provider.dart';
import 'core/constants/app_constants.dart';
import 'core/providers/background_provider.dart';
import 'core/theme/app_theme.dart';
import 'features/clients/presentation/providers/clients_providers.dart';
import 'features/settings/presentation/providers/settings_provider.dart';
import 'home/presentation/home_loading_screen.dart';
import 'l10n/app_localizations.dart';

class BeautyCenterApp extends ConsumerStatefulWidget {
  const BeautyCenterApp({super.key});

  @override
  ConsumerState<BeautyCenterApp> createState() => _BeautyCenterAppState();
}

class _BeautyCenterAppState extends ConsumerState<BeautyCenterApp> {
  StreamSubscription<FGBGType>? _fgbgSubscription;

  @override
  void initState() {
    super.initState();

    // Listen to app lifecycle changes (foreground/background)
    _fgbgSubscription = FGBGEvents.instance.stream.listen(
      _handleLifecycleChange,
    );
  }

  void _handleLifecycleChange(final FGBGType event) {
    final isBackground = event == FGBGType.background;

    // Update connectivity check frequency
    ref
        .read(connectivityRepositoryProvider)
        .setBackground(isBackground: isBackground);

    // Update app lifecycle state for all sync managers
    if (isBackground) {
      ref.read(appIsInForegroundProvider.notifier).setBackground();
    } else {
      ref.read(appIsInForegroundProvider.notifier).setForeground();
    }
  }

  @override
  void dispose() {
    _fgbgSubscription?.cancel();
    super.dispose();
  }

  @override
  Widget build(final BuildContext context) {
    // Initialize all sync managers
    ref
      ..watch(settingsSyncManagerProvider)
      ..watch(clientsSyncManagerProvider);
    // TODO add others

    return ScreenUtilInit(
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
          navigatorKey: navigatorKey,
          debugShowCheckedModeBanner: false,
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          theme: AppTheme.light,
          darkTheme: AppTheme.dark,
          home: const HomeLoadingScreen(),
          builder: (final context, final child) => MediaQuery(
            data: MediaQuery.of(context).copyWith(alwaysUse24HourFormat: true),
            child: child!,
          ),
        );
      },
    );
  }
}
