import 'dart:ui';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../l10n/app_localizations.dart';

// ============================================================================
// SIMPLIFIED LOCALIZATION SYSTEM (System Locale Only)
// ============================================================================

/// System locale provider - automatically detects and provides system locale
final systemLocaleProvider = Provider<Locale>(
  (final ref) => PlatformDispatcher.instance.locale,
);

/// Supported locales list (read-only)
final supportedLocalesProvider = Provider<List<Locale>>(
  (final ref) => AppLocalizations.supportedLocales,
);

/// Current effective locale provider
/// This determines which locale is actually being used by the app
final effectiveLocaleProvider = Provider<Locale>((final ref) {
  final systemLocale = ref.watch(systemLocaleProvider);
  final supportedLocales = ref.watch(supportedLocalesProvider);

  // Find the best match for system locale
  return _findBestMatch(systemLocale, supportedLocales);
});

/// Helper function to find best locale match
Locale _findBestMatch(
  final Locale systemLocale,
  final List<Locale> supportedLocales,
) {
  // First try exact match (language + country)
  for (final locale in supportedLocales) {
    if (locale.languageCode == systemLocale.languageCode &&
        locale.countryCode == systemLocale.countryCode) {
      return locale;
    }
  }

  // Then try language match only
  for (final locale in supportedLocales) {
    if (locale.languageCode == systemLocale.languageCode) {
      return locale;
    }
  }

  // Fallback to first supported locale (usually 'en')
  return supportedLocales.first;
}
