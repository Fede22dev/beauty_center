import 'package:beauty_center/core/extensions/riverpod_l10n_extensions.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

// ignore_for_file: all

// ============================================================================
// 1. IN WIDGETS (ConsumerWidget) - PREFERITO
// ============================================================================

class MyConsumerWidget extends ConsumerWidget {
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // ✅ Best practice per widget Consumer
    final l10n = ref.l10n(context);

    return Column(
      children: [
        Text(l10n.welcome),
        Text(l10n.notSupportedOsMessage),
        ElevatedButton(
          onPressed: () => _changeLanguage(ref),
          child: Text(l10n.settings),
        ),
      ],
    );
  }

  void _changeLanguage(WidgetRef ref) {
    // Change app locale
    final currentLocale = ref.read(appLocaleProvider);
    final newLocale = currentLocale.languageCode == 'en'
        ? const Locale('it')
        : const Locale('en');
    ref.read(appLocaleProvider.notifier).state = newLocale;
  }
}

// ============================================================================
// 2. IN PROVIDERS/NOTIFIERS (Business Logic) - FUTURE-PROOF
// ============================================================================

final userServiceProvider = Provider<UserService>((ref) {
  return UserService(ref);
});

class UserService {
  UserService(this.ref);

  final Ref ref;

  String getWelcomeMessage(String username) {
    // ✅ Best practice per business logic
    final l10n = ref.l10n;
    return '${l10n.welcome}, $username!';
  }

  List<String> getValidationErrors() {
    final l10n = ref.l10n;
    return [
      l10n.fieldRequired,
      l10n.invalidEmail,
      // etc...
    ];
  }
}

// ============================================================================
// 3. IN NOTIFIERS (Complex State Management)
// ============================================================================

@immutable
class AuthState {
  const AuthState({this.isLoading = false, this.errorMessage, this.user});

  final bool isLoading;
  final String? errorMessage;
  final User? user;

  AuthState copyWith({bool? isLoading, String? errorMessage, User? user}) {
    return AuthState(
      isLoading: isLoading ?? this.isLoading,
      errorMessage: errorMessage ?? this.errorMessage,
      user: user ?? this.user,
    );
  }
}

class AuthNotifier extends StateNotifier<AuthState> {
  AuthNotifier(this.ref) : super(const AuthState());

  final Ref ref;

  Future<void> login(String email, String password) async {
    state = state.copyWith(isLoading: true, errorMessage: null);

    try {
      // Simulate API call
      await Future.delayed(const Duration(seconds: 2));

      if (email.isEmpty) {
        // ✅ Best practice per messaggi di errore localizzati
        final l10n = ref.l10n;
        state = state.copyWith(
          isLoading: false,
          errorMessage: l10n.emailRequired,
        );
        return;
      }

      // Success
      state = state.copyWith(isLoading: false, user: User(email: email));
    } catch (e) {
      final l10n = ref.l10n;
      state = state.copyWith(isLoading: false, errorMessage: l10n.genericError);
    }
  }
}

final authProvider = StateNotifierProvider<AuthNotifier, AuthState>((ref) {
  return AuthNotifier(ref);
});

// ============================================================================
// 4. IN REGULAR WIDGETS (Fallback)
// ============================================================================

class RegularWidget extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    // ✅ Fallback per widget non-Consumer
    return Text(context.l10n.appTitle);
  }
}

// ============================================================================
// 5. REACTIVE UPDATES (Advanced)
// ============================================================================

class ReactiveTranslationWidget extends ConsumerWidget {
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // ✅ Si aggiorna automaticamente quando cambia la lingua
    final l10n = ref.watchL10n(context);

    return Text(l10n.currentLanguage);
  }
}

// ============================================================================
// DUMMY CLASSES FOR EXAMPLE
// ============================================================================

class User {
  const User({required this.email});

  final String email;
}
