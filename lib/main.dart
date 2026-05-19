import 'dart:io';

import 'package:adaptive_theme/adaptive_theme.dart';
import 'package:beauty_center/core/widgets/custom_snackbar.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:leak_tracker/leak_tracker.dart';
import 'package:logging/logging.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:talker_riverpod_logger/talker_riverpod_logger_observer.dart';
import 'package:talker_riverpod_logger/talker_riverpod_logger_settings.dart';

import 'beauty_center_app.dart';
import 'core/constants/app_constants.dart';
import 'core/database/app_database.dart';
import 'core/logging/app_logger.dart';
import 'not_supported_os_app.dart';

Future<void> main() async {
  LeakTracking.start();

  if (kIsWeb || !(Platform.isAndroid || Platform.isWindows)) {
    runApp(const NotSupportedOsApp());
    LeakTracking.stop();
    return;
  }

  WidgetsFlutterBinding.ensureInitialized();

  hierarchicalLoggingEnabled = true;

  AppLogger.init();
  final log = AppLogger.getLogger(name: 'main');

  FlutterError.onError = (details) {
    FlutterError.presentError(details);
    AppLogger.talker.handle(
      details.exception,
      details.stack,
      'Uncaught Flutter Error',
    );
    showGlobalCustomSnackBar(
      message:
          'Ops! Si è verificato un errore imprevisto. ${details.exceptionAsString()}',
      type: SnackBarType.error,
    );
  };

  PlatformDispatcher.instance.onError = (error, stack) {
    AppLogger.talker.handle(error, stack, 'Uncaught Async Error');
    showGlobalCustomSnackBar(
      message: 'Ops! Si è verificato un errore imprevisto. $error',
      type: SnackBarType.error,
    );
    return true;
  };

  final supabaseLogger = Logger('supabase')..level = Level.ALL;
  supabaseLogger.onRecord.listen((record) {
    final message = 'Supabase: ${record.message}';
    switch (record.level) {
      case Level.SEVERE:
        AppLogger.talker.error(message, record.error, record.stackTrace);
      case Level.WARNING:
        AppLogger.talker.warning(message);
      case Level.INFO:
        AppLogger.talker.info(message);
      default:
        AppLogger.talker.debug(message);
    }
  });

  final prefs = await SharedPreferences.getInstance();
  final shouldReset = prefs.getBool(kDatabaseRequestResetKey) ?? false;

  if (shouldReset) {
    log.severe('Reset database...');
    await AppDatabase.deleteDatabaseFiles();
    await prefs.remove(kDatabaseRequestResetKey);
    log
      ..info('Files database eliminati')
      ..info('Reset preferences...');
    await prefs.remove(kLastSyncTimeAppointmentsKey);
    await prefs.remove(kLastSyncTimeOperatorsBlockedSlotsKey);
    await prefs.remove(kLastSyncTimeClientsKey);
    await prefs.remove(kLastSyncTimeServicesKey);
    await prefs.remove(kLastSyncTimeAppointmentServicesKey);
    await prefs.remove(kLastSyncTimeProductsKey);
    await prefs.remove(kLastSyncTimeQuotesKey);
    await prefs.remove(kLastSyncTimeQuoteItemsKey);
    await prefs.remove(kLastSyncTimePackagesKey);
    await prefs.remove(kLastSyncTimePackageItemsKey);
    await prefs.remove(kLastSyncTimeFidelityCardsKey);
    await prefs.remove(kLastSyncTimeFidelityTransactionsKey);
    await prefs.remove(kLastSyncTimePaymentsKey);
    await prefs.remove(kLastSyncTimeProductSalesKey);
    await prefs.remove(kLastSyncTimeClientTagsKey);
    await prefs.remove(kLastSyncTimeClientTechnicalSheetsKey);
    await prefs.remove(kLastSyncTimeClientProductBlacklistKey);
    log.info('Preferences supabase sync resettate');
  }

  final savedThemeMode = await AdaptiveTheme.getThemeMode();

  runApp(
    ProviderScope(
      observers: [
        TalkerRiverpodObserver(
          talker: AppLogger.talker,
          settings: const TalkerRiverpodLoggerSettings(
            printProviderAdded: true, // Log quando un provider nasce
            printProviderDisposed: true, // Log quando muore (memory leak)
            printProviderFailed: true, // log errori nei provider
            printProviderUpdated: true, // false se troppi log cambio di UI
          ),
        ),
      ],
      child: BeautyCenterApp(savedThemeMode: savedThemeMode),
    ),
  );

  LeakTracking.stop();
}
