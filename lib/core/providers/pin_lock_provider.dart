import 'package:riverpod_annotation/riverpod_annotation.dart';

part 'pin_lock_provider.g.dart';

@riverpod
class PinLock extends _$PinLock {
  @override
  bool build() {
    ref.keepAlive();
    return true; // Stato iniziale: bloccato
  }

  void unlock() => state = false;

  void lock() => state = true;

  bool get isLocked => state;
}
