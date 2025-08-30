enum AppRoute { appointments, clients, treatments, stats, settings }

extension AppRouteX on AppRoute {
  String get path => '/$name';

  String get segment => name;
}

bool isValidTabSegment(String? segment) {
  if (segment == null) return false;
  for (final route in AppRoute.values) {
    if (route.segment == segment) return true;
  }
  return false;
}

// Default tab
const AppRoute kDefaultRoute = AppRoute.appointments;
