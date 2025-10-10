import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../l10n/app_localizations.dart';
import '../providers/app_localizations_providers.dart';

/// Extension for WidgetRef (ConsumerWidget, ConsumerStatefulWidget)
extension WidgetRefL10nExtensions on WidgetRef {
  /// Get localizations inside riverpod widget using context
  /// Usage: ref.l10n(context).welcome
  AppLocalizations l10n(final BuildContext context) =>
      AppLocalizations.of(context) ??
      (throw StateError(
        'AppLocalizations not found in context. '
        'Check MaterialApp.localizationsDelegates / supportedLocales.',
      ));
}

/// Extension for Ref (Provider, StateNotifier)
extension RefL10nExtensions on Ref {
  /// Get localizations inside riverpod business logic (no context needed)
  /// Usage: ref.l10n.welcome
  AppLocalizations get l10n =>
      lookupAppLocalizations(watch(effectiveLocaleProvider));
}

/// Extension for BuildContext (StatelessWidget, StatefulWidget)
extension BuildContextL10nExtensions on BuildContext {
  /// Get localizations with context
  /// Usage: context.l10n.welcome
  AppLocalizations get l10n =>
      AppLocalizations.of(this) ??
      (throw StateError('AppLocalizations not found in context'));
}
