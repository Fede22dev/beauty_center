import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:intl/intl.dart';
import 'package:logging/logging.dart';

class AppLogger {
  static bool useAnsiColor = !kReleaseMode;

  static void init({final Level? level = Level.FINE, final bool? ansiColor}) {
    useAnsiColor = ansiColor ?? stdout.supportsAnsiEscapes;

    Logger.root.level = level;
    Logger.root.onRecord.listen(_handleLog);
  }

  static Logger getLogger({final String name = 'App'}) => Logger(name);

  static void _handleLog(final LogRecord record) {
    final time = DateFormat('HH:mm:ss').format(record.time);
    final color = useAnsiColor ? _ansiColorForLevel(record.level) : '';
    final reset = useAnsiColor ? '\x1B[0m' : '';

    final timeField = '[$time]';
    final loggerName = '[${record.loggerName}]';
    final levelName = '[${record.level.name}]';

    final message = record.message;
    final error = record.error != null ? ' - ${record.error}' : '';
    final stack = record.stackTrace != null ? '\n${record.stackTrace}' : '';

    final line =
        '$color$timeField$loggerName$levelName $message$error$reset$stack';

    //stdout.writeln(line);
    print(line);
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
