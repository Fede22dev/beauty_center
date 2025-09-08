import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/router/app_routes.dart';

/// Riverpod Notifier.
/// Holds the selected AppRoute as the single source for tab.
class HomeTabController extends Notifier<AppRoute> {
  @override
  AppRoute build() => kDefaultRoute;

  void setIndex(final int index) => state = AppRoute.values[index];

  int get index => state.index;
}

final homeTabProvider = NotifierProvider<HomeTabController, AppRoute>(
  HomeTabController.new,
);
