import 'package:riverpod_annotation/riverpod_annotation.dart';

part 'background_provider.g.dart';

@riverpod
class AppIsInForeground extends _$AppIsInForeground {
  @override
  bool build() {
    ref.keepAlive();
    return true; // Stato iniziale: foreground
  }

  void setForeground() => state = true;

  void setBackground() => state = false;
}
