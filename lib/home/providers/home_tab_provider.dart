import 'package:riverpod_annotation/riverpod_annotation.dart';

import '../../core/tabs/app_tabs.dart';

part 'home_tab_provider.g.dart';

@riverpod
class HomeTabNotifier extends _$HomeTabNotifier {
  @override
  AppTabs build() => AppTabs.defaultTab;

  void setIndex(int index) {
    if (index < 0 || index >= AppTabs.values.length) return;

    final tab = AppTabs.values[index];
    if (state != tab) {
      state = tab;
    }
  }
}
