import 'dart:async';

import 'package:equatable/equatable.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../connectivity/connectivity_providers.dart';
import '../constants/app_constants.dart';
import '../database/app_database.dart';
import '../logging/app_logger.dart';

part 'supabase_auth_provider.g.dart';

@riverpod
FlutterSecureStorage secureStorage(final Ref ref) =>
    const FlutterSecureStorage();

/// Authentication status for Supabase connection
enum SupabaseAuthStatus { initializing, disconnected, connecting, connected }

/// Immutable state for Supabase authentication
@immutable
class SupabaseAuthState extends Equatable {
  const SupabaseAuthState(this.status);

  factory SupabaseAuthState.initializing() =>
      const SupabaseAuthState(SupabaseAuthStatus.initializing);

  factory SupabaseAuthState.disconnected() =>
      const SupabaseAuthState(SupabaseAuthStatus.disconnected);

  factory SupabaseAuthState.connecting() =>
      const SupabaseAuthState(SupabaseAuthStatus.connecting);

  factory SupabaseAuthState.connected() =>
      const SupabaseAuthState(SupabaseAuthStatus.connected);

  final SupabaseAuthStatus status;

  bool get isInitializing => status == SupabaseAuthStatus.initializing;

  bool get isDisconnected => status == SupabaseAuthStatus.disconnected;

  bool get isConnecting => status == SupabaseAuthStatus.connecting;

  bool get isConnected => status == SupabaseAuthStatus.connected;

  @override
  List<Object?> get props => [status];
}

/// Supabase provider with proper initialization handling
@Riverpod(keepAlive: true)
class SupabaseAuth extends _$SupabaseAuth {
  final _log = AppLogger.getLogger(name: 'SupabaseAuthNotifier');

  @override
  SupabaseAuthState build() {
    // Listen to connectivity changes
    ref.listen(isConnectionUnusableProvider, (
      final prev,
      final isUnusable,
    ) async {
      final wasUnusable = prev ?? false;

      // Reconnect if network is restored and we are disconnected
      if (wasUnusable && !isUnusable && state.isDisconnected) {
        _log.info('Network restored. Retrying Supabase initialization...');
        await _initializeSupabase();
      }
    });

    // Initial setup (fire and forget)
    Future.microtask(_initializeSupabase);

    return SupabaseAuthState.initializing();
  }

  /// Metodo helper sicuro per inizializzare Supabase senza crash
  Future<void> _safeInitialize(final String url, final String anonKey) async {
    try {
      _log.info('Initializing Supabase...');
      // Only enable debug logging in debug mode to avoid credential leaks in production
      await Supabase.initialize(url: url, anonKey: anonKey, debug: kDebugMode);
    } catch (e) {
      // Ignora l'errore se è già inizializzato
      if (!e.toString().contains('already initialized')) {
        // Sanitize error message to avoid logging credentials
        final sanitizedError = e
            .toString()
            .replaceAll(anonKey, '[REDACTED]')
            .replaceAll(url, '[REDACTED_URL]');
        _log.warning('Supabase init warning: $sanitizedError');
        rethrow;
      }
    }
  }

  Future<void> _initializeSupabase() async {
    final storage = ref.read(secureStorageProvider);

    try {
      final results = await Future.wait([
        storage.read(key: kSupabaseUrlKeySecureStorageKey),
        storage.read(key: kSupabaseAnonKeySecureStorageKey),
      ]);

      final url = results[0];
      final anonKey = results[1];

      if (url == null || anonKey == null) {
        _log.finest('No credentials found.');
        state = SupabaseAuthState.disconnected();
        return;
      }

      await _safeInitialize(url, anonKey);
      _checkCurrentSession();
    } catch (e, stackTrace) {
      _log.severe('Supabase initialization failed', e, stackTrace);
      state = SupabaseAuthState.disconnected();
    }
  }

  /// Checks for active session
  void _checkCurrentSession() {
    try {
      final session = Supabase.instance.client.auth.currentSession;
      state = session != null
          ? SupabaseAuthState.connected()
          : SupabaseAuthState.disconnected();
    } catch (_) {
      state = SupabaseAuthState.disconnected();
    }
  }

  /// Login with email and password
  Future<void> loginWithEmail({
    required final String url,
    required final String anonKey,
    required final String email,
    required final String password,
  }) async {
    state = SupabaseAuthState.connecting();
    final storage = ref.read(secureStorageProvider);

    try {
      // Cleanup previous instance if needed
      try {
        await Supabase.instance.dispose();
      } catch (_) {}

      // 1. Inizializziamo in modo sicuro
      await _safeInitialize(url, anonKey);

      // 2. Login
      final response = await Supabase.instance.client.auth.signInWithPassword(
        email: email,
        password: password,
      );

      // 3. Salviamo le nuove credenziali
      if (response.session != null) {
        await Future.wait([
          storage.write(key: kSupabaseUrlKeySecureStorageKey, value: url),
          storage.write(key: kSupabaseAnonKeySecureStorageKey, value: anonKey),
        ]);

        state = SupabaseAuthState.connected();
        _log.info('Login successful');
      } else {
        throw const FormatException('Login failed: No session received');
      }
    } catch (e, stackTrace) {
      _log.warning('Login process failed', e, stackTrace);
      state = SupabaseAuthState.disconnected();
      rethrow;
    }
  }

  /// Logout current user
  Future<void> logout() async {
    final storage = ref.read(secureStorageProvider);

    try {
      try {
        await Supabase.instance.client.auth.signOut();
      } catch (_) {}

      await storage.delete(key: kSupabaseUrlKeySecureStorageKey);
      await storage.delete(key: kSupabaseAnonKeySecureStorageKey);

      final prefs = await SharedPreferences.getInstance();
      final syncKeys = prefs.getKeys().where(
        (k) => k.startsWith(kLastSyncTimePrefix),
      );
      for (final key in syncKeys) {
        await prefs.remove(key);
      }

      await AppDatabase.requestResetOnNextLaunch();

      _log.info('Logout successful');
    } catch (e, stackTrace) {
      _log.warning('Logout error', e, stackTrace);
      rethrow;
    } finally {
      state = SupabaseAuthState.disconnected();
    }
  }
}

@riverpod
SupabaseClient? supabaseClient(final Ref ref) {
  final authState = ref.watch(supabaseAuthProvider);
  if (authState.isConnected) {
    try {
      return Supabase.instance.client;
    } catch (_) {
      return null;
    }
  }
  return null;
}

@riverpod
bool isAuthenticated(final Ref ref) =>
    ref.watch(supabaseAuthProvider).isConnected;
