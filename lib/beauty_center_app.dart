import 'dart:async';

import 'package:adaptive_theme/adaptive_theme.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_fgbg/flutter_fgbg.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:material_symbols_icons/symbols.dart';
import 'package:talker_flutter/talker_flutter.dart';

import 'core/command_palette/command_palette.dart';
import 'core/connectivity/connectivity_providers.dart';
import 'core/constants/app_constants.dart';
import 'core/logging/app_logger.dart';
import 'core/providers/background_provider.dart';
import 'core/sync/app_sync_manager.dart';
import 'core/theme/app_theme.dart';
import 'core/utils/navigator_key.dart';
import 'core/widgets/app_loading_screen.dart';
import 'core/widgets/offline_sync_indicator.dart';
import 'home/presentation/home_loading_screen.dart';
import 'l10n/app_localizations.dart';

class BeautyCenterApp extends ConsumerStatefulWidget {
  const BeautyCenterApp({super.key, this.savedThemeMode});

  final AdaptiveThemeMode? savedThemeMode;

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
    // Initialize unified app sync manager
    ref.watch(appSyncManagerProvider);

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

        return AdaptiveTheme(
          light: AppTheme.light,
          dark: AppTheme.dark,
          initial: widget.savedThemeMode ?? AdaptiveThemeMode.light,
          builder: (final theme, final darkTheme) => MaterialApp(
            title: 'Beauty Center',
            navigatorKey: navigatorKey,
            debugShowCheckedModeBanner: false,
            localizationsDelegates: AppLocalizations.localizationsDelegates,
            supportedLocales: AppLocalizations.supportedLocales,
            theme: theme,
            darkTheme: darkTheme,
            home: const AppLoadingScreen(
              child: HomeLoadingScreen(),
            ),
            navigatorObservers: [TalkerRouteObserver(AppLogger.talker)],
            builder: (final context, final child) {
              ErrorWidget.builder = (FlutterErrorDetails details) {
                final cs = Theme.of(context).colorScheme;

                return Material(
                  color: cs.surfaceContainer,
                  child: Center(
                    child: Padding(
                      padding: EdgeInsets.all(kIsWindows ? 20 : 20.w),
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(
                            Symbols.warning_amber_rounded,
                            color: cs.error,
                            size: kIsWindows ? 50 : 50.sp,
                          ),
                          SizedBox(height: kIsWindows ? 16 : 16.h),
                          Text(
                            'Ops! Problema di visualizzazione.',
                            style: Theme.of(context).textTheme.titleMedium,
                            textAlign: TextAlign.center,
                          ),
                          SizedBox(height: kIsWindows ? 8 : 8.h),
                          // Mostriamo i dettagli tecnici del layout
                          Text(
                            details.exceptionAsString(),
                            style: TextStyle(
                              fontSize: kIsWindows ? 10 : 10.sp,
                              color: cs.onSurface,
                            ),
                            textAlign: TextAlign.center,
                          ),
                        ],
                      ),
                    ),
                  ),
                );
              };

              return MediaQuery(
                data: MediaQuery.of(
                  context,
                ).copyWith(alwaysUse24HourFormat: true),
                child: CommandPaletteShortcut(
                  child: Stack(
                    children: [
                      child!,
                      // Global Command Palette overlay
                      const CommandPalette(),
                      // Global Offline/Sync indicator at top
                      const Positioned(
                        top: 0,
                        left: 0,
                        right: 0,
                        child: OfflineSyncIndicator(),
                      ),
                    ],
                  ),
                ),
              );
            },
          ),
        );
      },
    );
  }
}
