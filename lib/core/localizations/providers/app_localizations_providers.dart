import 'dart:ui';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../l10n/app_localizations.dart';

/// System locale provider - automatically detects and provides system locale
final systemLocaleProvider = Provider<Locale>(
  (_) => PlatformDispatcher.instance.locale,
);

/// Supported locales list (read-only)
final supportedLocalesProvider = Provider<List<Locale>>(
  (_) => AppLocalizations.supportedLocales,
);

/// This determines which locale is actually being used by the app
final effectiveLocaleProvider = Provider<Locale>((final ref) {
  final systemLocale = ref.watch(systemLocaleProvider);
  final supportedLocales = ref.watch(supportedLocalesProvider);

  return _bestMatch(systemLocale, supportedLocales);
});

/// Helper function to find best locale match
Locale _bestMatch(
  final Locale systemLocale,
  final List<Locale> supportedLocales,
) => supportedLocales.firstWhere(
  (final locale) =>
      (locale.languageCode == systemLocale.languageCode &&
          locale.countryCode == systemLocale.countryCode) ||
      locale.languageCode == systemLocale.languageCode,
  orElse: () => supportedLocales.first,
);
