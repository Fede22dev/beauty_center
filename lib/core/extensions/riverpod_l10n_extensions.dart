import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../l10n/app_localizations.dart';
import '../providers/app_providers.dart';

// ============================================================================
// SIMPLIFIED L10N EXTENSIONS (System Locale Only)
// ============================================================================

/// Extension for WidgetRef (in ConsumerWidget, ConsumerStatefulWidget)
extension WidgetRefL10nExtensions on WidgetRef {
  /// Get localizations using context (recommended for UI)
  /// This automatically uses the system locale via MaterialApp
  /// Usage: ref.l10n(context).welcome
  AppLocalizations l10n(final BuildContext context) {
    final l10n = AppLocalizations.of(context);
    if (l10n == null) {
      throw StateError(
        'AppLocalizations not found in context. '
        'Make sure MaterialApp.localizationsDelegates and '
        'MaterialApp.supportedLocales are configured properly.',
      );
    }
    return l10n;
  }
}

/// Extension for Ref (in providers and notifiers)
extension RefL10nExtensions on Ref {
  /// Get localizations for business logic (no context needed)
  /// This creates the localization based on effective locale
  /// Usage: ref.l10n.welcome
  AppLocalizations get l10n {
    final effectiveLocale = watch(effectiveLocaleProvider);
    return lookupAppLocalizations(effectiveLocale);
  }
}

/// Extension for BuildContext (fallback for non-Consumer widgets)
extension BuildContextL10nExtensions on BuildContext {
  /// Simple access to localizations
  /// Usage: context.l10n.welcome
  AppLocalizations get l10n {
    final l10n = AppLocalizations.of(this);
    if (l10n == null) {
      throw StateError('AppLocalizations not found in context');
    }
    return l10n;
  }

  /// Null-safe version
  AppLocalizations? get l10nNullable => AppLocalizations.of(this);
}
