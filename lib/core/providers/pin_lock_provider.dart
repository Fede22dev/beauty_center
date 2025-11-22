import 'package:flutter_riverpod/flutter_riverpod.dart';

class PinLockNotifier extends Notifier<bool> {
  @override
  bool build() => true; // Locked by default

  void unlock() => state = false;

  void lock() => state = true;

  bool get isLocked => state;
}

final pinLockProvider = NotifierProvider<PinLockNotifier, bool>(
  PinLockNotifier.new,
);
