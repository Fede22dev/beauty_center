import 'package:beauty_center/core/extensions/riverpod_l10n_extensions.dart';
import 'package:flutter/material.dart';
import 'package:material_symbols_icons/symbols.dart';

import '../../features/appointments/presentation/pages/appointments_page.dart';
import '../../features/clients/presentation/pages/clients_page.dart';
import '../../features/settings/presentation/pages/settings_page.dart';
import '../../features/statistics/presentation/pages/statistics_page.dart';
import '../../features/treatments/presentation/pages/treatments_page.dart';
import '../router/app_routes.dart';

/// UI-specific extensions for AppRoute.
extension AppRouteUiX on AppRoute {
  IconData get icon => switch (this) {
    AppRoute.appointments => Symbols.calendar_month_rounded,
    AppRoute.clients => Symbols.patient_list_rounded,
    AppRoute.treatments => Symbols.massage_rounded,
    AppRoute.statistics => Symbols.show_chart_rounded,
    AppRoute.settings => Symbols.settings_rounded,
  };

  String label(final BuildContext context) => switch (this) {
    AppRoute.appointments => context.l10n.appointments,
    AppRoute.clients => context.l10n.clients,
    AppRoute.treatments => context.l10n.treatments,
    AppRoute.statistics => context.l10n.statistics,
    AppRoute.settings => context.l10n.settings,
  };

  Color get color => switch (this) {
    AppRoute.appointments => const Color(0xFFDA3935),
    AppRoute.clients => const Color(0xFF1E88E5),
    AppRoute.treatments => const Color(0xFFFFB300),
    AppRoute.statistics => const Color(0xFF43AA47),
    AppRoute.settings => const Color(0xFF8E24DF),
  };

  Widget get buildPage => switch (this) {
    AppRoute.appointments => const AppointmentsPage(),
    AppRoute.clients => const ClientsPage(),
    AppRoute.treatments => const TreatmentsPage(),
    AppRoute.statistics => const StatisticsPage(),
    AppRoute.settings => const SettingsPage(),
  };
}
