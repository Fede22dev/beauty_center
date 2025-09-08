import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../l10n/app_localizations.dart';
import '../../l10n/app_localizations_en.dart';
import '../../l10n/app_localizations_it.dart';

// ============================================================================
// LOCALE MANAGEMENT (State Management)
// ============================================================================

/// Current app locale state
final appLocaleProvider = StateProvider<Locale>(
  (final ref) => const Locale('en'),
); // Default locale);

/// Supported locales list
final supportedLocalesProvider = Provider<List<Locale>>(
  (final ref) => AppLocalizations.supportedLocales,
);

// ============================================================================
// LOCALIZATION ACCESS (Context-dependent)
// ============================================================================

/// Primary way to get localizations in widgets
final l10nProvider = Provider.family<AppLocalizations, BuildContext>((
  final ref,
  final context,
) {
  // This will rebuild when locale changes due to MaterialApp rebuild
  final l10n = AppLocalizations.of(context);
  if (l10n == null) {
    throw StateError('AppLocalizations not found in context');
  }
  return l10n;
});

/// Null-safe version for edge cases
final l10nNullableProvider = Provider.family<AppLocalizations?, BuildContext>(
  (final ref, final context) => AppLocalizations.of(context),
);

// ============================================================================
// BUSINESS LOGIC LOCALIZATIONS (Context-free)
// ============================================================================

/// For use in providers, services, and business logic
/// Requires manual locale tracking but works without context
class LocalizationRepository {
  AppLocalizations? _current;

  void updateLocale(final Locale locale) {
    // Map locale to AppLocalizations instance
    switch (locale.languageCode) {
      case 'it':
        _current = AppLocalizationsIt();
        break;
      case 'en':
      default:
        _current = AppLocalizationsEn();
        break;
    }
  }

  AppLocalizations get current => _current ?? AppLocalizationsEn();

  String translate(final String Function(AppLocalizations) selector) =>
      selector(current);
}

/// Provider for business logic localizations
final localizationRepositoryProvider =
    StateNotifierProvider<LocalizationNotifier, AppLocalizations>((final ref) {
      final notifier = LocalizationNotifier(ref);

      // Listen to locale changes and update repository
      ref.listen(appLocaleProvider, (final previous, final next) {
        notifier.updateLocale(next);
      });

      return notifier;
    });

class LocalizationNotifier extends StateNotifier<AppLocalizations> {
  LocalizationNotifier(this.ref) : super(AppLocalizationsEn());

  final Ref ref;

  void updateLocale(final Locale locale) {
    switch (locale.languageCode) {
      case 'it':
        state = AppLocalizationsIt();
        break;
      case 'en':
      default:
        state = AppLocalizationsEn();
        break;
    }
  }
}
