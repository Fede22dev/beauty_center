enum AppRoute { appointments, clients, treatments, statistics, settings }

// Default tab.
const AppRoute kDefaultRoute = AppRoute.appointments;

extension AppRouteX on AppRoute {
  String get segment => name;

  String get path => '/$segment';
}

bool isValidTabSegment(String? segment) {
  if (segment == null) return false;
  for (final route in AppRoute.values) {
    if (route.segment == segment) return true;
  }

  return false;
}

AppRoute appRouteFromSegmentOrDefault(String? segment) {
  if (segment == null) return kDefaultRoute;
  for (final route in AppRoute.values) {
    if (route.segment == segment) return route;
  }

  return kDefaultRoute;
}
