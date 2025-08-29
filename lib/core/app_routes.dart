enum AppRoutes {
  home('/home'),
  appointments('/appointments'),
  clients('/clients'),
  treatments('/treatments'),
  stats('/stats'),
  settings('/settings');

  final String path;

  const AppRoutes(this.path);
}
