import 'package:beauty_center/core/localizations/extensions/l10n_extensions.dart';
import 'package:flutter/material.dart';
import 'package:material_symbols_icons/symbols.dart';

import '../../features/appointments/presentation/pages/appointments_page.dart';
import '../../features/clients/presentation/pages/clients_page.dart';
import '../../features/settings/presentation/pages/settings_page.dart';
import '../../features/statistics/presentation/pages/statistics_page.dart';
import '../../features/suppliers/presentation/pages/suppliers_page.dart';
import '../../features/treatments/presentation/pages/treatments_page.dart';

enum AppTabs {
  appointments(
    icon: Symbols.calendar_month_rounded,
    color: Color(0xFFDA3935),
    buildPage: AppointmentsPage(),
  ),
  clients(
    icon: Symbols.patient_list_rounded,
    color: Color(0xFF1A88FA),
    buildPage: ClientsPage(),
  ),
  treatments(
    icon: Symbols.massage_rounded,
    color: Color(0xFFFFC000),
    buildPage: TreatmentsPage(),
  ),
  suppliers(
    icon: Symbols.storefront_rounded,
    color: Color(0xFF00CCD4),
    buildPage: SuppliersPage(),
  ),
  statistics(
    icon: Symbols.show_chart_rounded,
    color: Color(0xFF43DF47),
    buildPage: StatisticsPage(),
  ),
  settings(
    icon: Symbols.settings_rounded,
    color: Color(0xFF8E24DF),
    buildPage: SettingsPage(),
  );

  const AppTabs({
    required this.icon,
    required this.color,
    required this.buildPage,
  });

  static const defaultTab = AppTabs.clients; // TODO: change to appointments

  final IconData icon;
  final Color color;
  final Widget buildPage;

  String label(final BuildContext context) => _labels[this]!(context);
}

final Map<AppTabs, String Function(BuildContext)> _labels = {
  AppTabs.appointments: (final c) => c.l10n.appointments,
  AppTabs.clients: (final c) => c.l10n.clients,
  AppTabs.treatments: (final c) => c.l10n.treatments,
  AppTabs.suppliers: (final c) => c.l10n.suppliers,
  AppTabs.statistics: (final c) => c.l10n.statistics,
  AppTabs.settings: (final c) => c.l10n.settings,
};
