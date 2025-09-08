import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../l10n/app_localizations.dart';
import '../providers/app_providers.dart';

// ============================================================================
// EXTENSIONS FOR DIFFERENT CONTEXTS
// ============================================================================

/// Extension for WidgetRef (in ConsumerWidget, ConsumerStatefulWidget)
extension WidgetRefL10nExtensions on WidgetRef {
  /// Get localizations in Consumer widgets
  /// Usage: ref.l10n(context).welcome
  AppLocalizations l10n(final BuildContext context) =>
      read(l10nProvider(context));

  /// Watch localizations for reactive updates
  /// Usage: ref.watchL10n(context).welcome
  AppLocalizations watchL10n(final BuildContext context) =>
      watch(l10nProvider(context));

  /// For business logic - no context needed
  /// Usage: ref.l10nLogic.welcome
  AppLocalizations get l10nLogic => watch(localizationRepositoryProvider);
}

/// Extension for Ref (in providers and notifiers)
extension RefL10nExtensions on Ref {
  /// Get localizations in providers/notifiers
  /// Usage: ref.l10n.welcome
  AppLocalizations get l10n => read(localizationRepositoryProvider);

  /// Watch for reactive updates in providers
  /// Usage: ref.watchL10n.welcome
  AppLocalizations get watchL10n => watch(localizationRepositoryProvider);
}

/// Extension for BuildContext (fallback for non-Consumer widgets)
extension BuildContextL10nExtensions on BuildContext {
  /// Simple fallback for regular StatelessWidget/StatefulWidget
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
