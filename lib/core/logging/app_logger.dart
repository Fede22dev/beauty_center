import 'package:talker_flutter/talker_flutter.dart';

class AppLogger {
  static late final Talker talker;

  static void init() {
    talker = TalkerFlutter.init(
      settings: TalkerSettings(
        useConsoleLogs: true,
        useHistory: true,
        maxHistoryItems: 1000,
      ),
      logger: TalkerLogger(
        settings: TalkerLoggerSettings(
          level: LogLevel.verbose,
          enableColors: true,
          maxLineWidth: 120,
        ),
      ),
      observer: AppTalkerObserver(), // Crashlytics
    );
  }

  static LogWrapper getLogger({final String name = 'App'}) =>
      LogWrapper(name, talker);
}

class LogWrapper {
  LogWrapper(this.name, this.talker);

  final String name;
  final Talker talker;

  void finest(String message) => talker.verbose('[$name] $message');

  void info(String message) => talker.info('[$name] $message');

  void warning(String message, [Object? error, StackTrace? stackTrace]) {
    if (error != null) {
      talker.warning('[$name] $message', error, stackTrace);
    } else {
      talker.warning('[$name] $message');
    }
  }

  void severe(String message, [Object? error, StackTrace? stackTrace]) {
    if (error != null) {
      talker.error('[$name] $message', error, stackTrace);
    } else {
      talker.error('[$name] $message');
    }
  }
}

/// Observer per inviare automaticamente Errori e Log ai server remoti
class AppTalkerObserver extends TalkerObserver {
  // 1. Invia a Crashlytics le eccezioni vere e proprie (I tuoi log.severe / try-catch)
  @override
  void onError(TalkerError err) {
    super.onError(err);
    // TODO (Futuro): Invia a Crashlytics
    // FirebaseCrashlytics.instance.recordError(err.error, err.stackTrace, reason: err.message);
  }

  // 2. Invia a Crashlytics eccezioni non previste dal Framework
  @override
  void onException(TalkerException err) {
    super.onException(err);
    // TODO (Futuro): Invia a Crashlytics
    // FirebaseCrashlytics.instance.recordError(err.exception, err.stackTrace, reason: err.message);
  }

  // Opzionale: puoi inviare anche i log normali (es. gli info)
  @override
  void onLog(TalkerData log) {
    super.onLog(log);
    // FirebaseCrashlytics.instance.log(log.generateTextMessage());
  }
}
