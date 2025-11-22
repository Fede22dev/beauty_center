import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Notifier to track if app is in foreground or background
class AppLifecycleNotifier extends Notifier<bool> {
  @override
  bool build() => true; // Start as foreground

  void setForeground() => state = true;

  void setBackground() => state = false;
}

final appIsInForegroundProvider = NotifierProvider<AppLifecycleNotifier, bool>(
  AppLifecycleNotifier.new,
);
