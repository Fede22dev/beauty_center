import 'package:flutter/material.dart';
import 'package:material_symbols_icons/symbols.dart';

import '../../core/app_routes.dart';
import '../../features/appointments/presentation/pages/appointments_page.dart';
import '../../features/clients/presentation/pages/clients_page.dart';
import '../../features/settings/presentation/pages/settings_page.dart';
import '../../features/statistics/presentation/pages/statistics_page.dart';
import '../../features/treatments/presentation/pages/treatments_page.dart';
import '../../generated/l10n.dart';

/// UI-specific extensions for AppRoute (icons, localized labels).
extension AppRouteUiX on AppRoute {
  IconData get icon => switch (this) {
    AppRoute.appointments => Symbols.calendar_month_rounded,
    AppRoute.clients => Symbols.patient_list_rounded,
    AppRoute.treatments => Symbols.massage_rounded,
    AppRoute.statistics => Symbols.show_chart_rounded,
    AppRoute.settings => Symbols.settings_rounded,
  };

  String label(BuildContext context) => switch (this) {
    AppRoute.appointments => S.of(context).appointments,
    AppRoute.clients => S.of(context).clients,
    AppRoute.treatments => S.of(context).treatments,
    AppRoute.statistics => S.of(context).statistics,
    AppRoute.settings => S.of(context).settings,
  };

  Color get color => switch (this) {
    AppRoute.appointments => Color(0xFFDA3935),
    AppRoute.clients => Color(0xFF1E88E5),
    AppRoute.treatments => Color(0xFFFFB300),
    AppRoute.statistics => Color(0xFF43AA47),
    AppRoute.settings => Color(0xFF8E24DF),
  };

  Widget get buildPage => switch (this) {
    AppRoute.appointments => const AppointmentsPage(),
    AppRoute.clients => const ClientsPage(),
    AppRoute.treatments => const TreatmentsPage(),
    AppRoute.statistics => const StatisticsPage(),
    AppRoute.settings => const SettingsPage(),
  };
}
