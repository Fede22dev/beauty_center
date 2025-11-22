import 'dart:developer' as developer;
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:intl/intl.dart';
import 'package:logging/logging.dart';

class AppLogger {
  static final _dateFormat = DateFormat('HH:mm:ss');
  static bool _useAnsiColor = !kReleaseMode;

  static void init({final Level? level = Level.FINEST, final bool? ansiColor}) {
    _useAnsiColor = ansiColor ?? stdout.supportsAnsiEscapes;

    Logger.root.level = level;
    Logger.root.onRecord.listen(_handleLog);
  }

  static Logger getLogger({final String name = 'App'}) => Logger(name);

  static void _handleLog(final LogRecord record) {
    final buffer = StringBuffer();

    // 1. Timestamp
    // Note: developer.log usually adds its own timestamp in DevTools,
    // but we keep this for raw terminal output clarity.
    final time = _dateFormat.format(record.time);
    buffer
      ..write('[$time]')
      // 2. Logger Name
      ..write('[${record.loggerName}]');

    // 3. Level
    if (_useAnsiColor) {
      buffer
        ..write(_ansiColorForLevel(record.level))
        ..write('[${record.level.name}]')
        ..write('\x1B[0m'); // Reset
    } else {
      buffer.write('[${record.level.name}]');
    }

    // 4. Message
    buffer.write(' ${record.message}');

    // 'print' truncates long messages on Android.
    // 'stdout' often fails in Flutter mobile environments.
    // 'developer.log' handles long strings, errors, and stack traces natively.
    developer.log(
      buffer.toString(),
      name: record.loggerName,
      level: record.level.value,
      error: record.error,
      stackTrace: record.stackTrace,
      time: record.time,
    );
  }

  static String _ansiColorForLevel(final Level level) {
    if (level >= Level.SHOUT) return '\x1B[35m'; // Magenta
    if (level >= Level.SEVERE) return '\x1B[31m'; // Red
    if (level >= Level.WARNING) return '\x1B[33m'; // Yellow
    if (level >= Level.INFO) return '\x1B[32m'; // Green
    if (level >= Level.CONFIG) return '\x1B[36m'; // Cyan
    return '\x1B[90m'; // Grey
  }
}
