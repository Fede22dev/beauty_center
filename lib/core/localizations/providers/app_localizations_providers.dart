import 'dart:ui';

import 'package:riverpod_annotation/riverpod_annotation.dart';

import '../../../l10n/app_localizations.dart';

part 'app_localizations_providers.g.dart';

/// System locale provider
@riverpod
Locale systemLocale(final Ref ref) => PlatformDispatcher.instance.locale;

/// Supported locales list
@riverpod
List<Locale> supportedLocales(final Ref ref) =>
    AppLocalizations.supportedLocales;

/// This determines which locale is actually being used by the app
@riverpod
Locale effectiveLocale(final Ref ref) {
  final systemLocale = ref.watch(systemLocaleProvider);
  final supportedLocales = ref.watch(supportedLocalesProvider);

  return _bestMatch(systemLocale, supportedLocales);
}

/// Helper function (non serve annotazione perché è una funzione privata standard)
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
