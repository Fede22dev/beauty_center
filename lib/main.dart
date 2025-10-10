import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'beauty_center_app.dart';
import 'core/connectivity/connectivity_repository.dart';
import 'core/logging/app_logger.dart';
import 'not_supported_os_app.dart';

Future<void> main() async {
  if (kIsWeb || !(Platform.isAndroid || Platform.isWindows)) {
    runApp(const NotSupportedOsApp());
    return;
  }

  AppLogger.init();

  WidgetsFlutterBinding.ensureInitialized();
  await ConnectivityRepository.instance.init();
  runApp(const ProviderScope(child: BeautyCenterApp()));
}
