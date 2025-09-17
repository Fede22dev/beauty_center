import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/tabs/app_tabs.dart';

class HomeTabNotifier extends Notifier<AppTabs> {
  @override
  AppTabs build() => AppTabs.defaultTab;

  void setIndex(final int index) {
    final tab = AppTabs.values[index];
    if (index >= 0 && index < AppTabs.values.length && state != tab) {
      state = tab;
    }
  }
}

final homeTabProvider = NotifierProvider<HomeTabNotifier, AppTabs>(
  HomeTabNotifier.new,
);
