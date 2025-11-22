import 'dart:async';

import 'package:equatable/equatable.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../connectivity/connectivity_provider.dart';
import '../constants/app_constants.dart';
import '../logging/app_logger.dart';

final secureStorageProvider = Provider<FlutterSecureStorage>(
  (final ref) => const FlutterSecureStorage(),
);

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

  @override
  bool get stringify => true;
}

/// Supabase provider with proper initialization handling
class SupabaseAuthNotifier extends Notifier<SupabaseAuthState> {
  final _log = AppLogger.getLogger(name: 'SupabaseAuthNotifier');
  late final FlutterSecureStorage _storage;

  @override
  SupabaseAuthState build() {
    _storage = ref.read(secureStorageProvider);

    // Listen to connectivity changes
    ref.listen<bool>(isConnectionUnusableProvider, (
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

  /// Initialize Supabase client from stored credentials
  Future<void> _initializeSupabase() async {
    try {
      final results = await Future.wait([
        _storage.read(key: kSupabaseUrlKeySecureStorageKey),
        _storage.read(key: kSupabaseAnonKeySecureStorageKey),
      ]);

      final url = results[0];
      final anonKey = results[1];

      if (url == null || anonKey == null) {
        _log.fine('No credentials found.');
        state = SupabaseAuthState.disconnected();
        return;
      }

      // Initialize Supabase
      try {
        await Supabase.initialize(
          url: url,
          anonKey: anonKey,
          debug: kDebugMode,
        );
        _log.info('Supabase initialized.');
      } catch (e) {
        if (!e.toString().contains('already initialized')) {
          _log.warning('Supabase init warning: $e');
        }
      }

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

    try {
      // Cleanup previous instance if needed
      try {
        await Supabase.instance.client.dispose();
      } catch (_) {}

      await Supabase.initialize(url: url, anonKey: anonKey, debug: kDebugMode);

      final response = await Supabase.instance.client.auth.signInWithPassword(
        email: email,
        password: password,
      );

      if (response.session != null) {
        await Future.wait([
          _storage.write(key: kSupabaseUrlKeySecureStorageKey, value: url),
          _storage.write(key: kSupabaseAnonKeySecureStorageKey, value: anonKey),
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
    try {
      try {
        await Supabase.instance.client.auth.signOut();
      } catch (_) {}
      _log.info('Logout successful');
    } catch (e, stackTrace) {
      _log.warning('Logout error', e, stackTrace);
      rethrow;
    } finally {
      state = SupabaseAuthState.disconnected();
    }
  }
}

final supabaseAuthProvider =
    NotifierProvider<SupabaseAuthNotifier, SupabaseAuthState>(
      SupabaseAuthNotifier.new,
    );

final supabaseClientProvider = Provider<SupabaseClient?>((final ref) {
  final authState = ref.watch(supabaseAuthProvider);
  if (authState.isConnected) {
    try {
      return Supabase.instance.client;
    } catch (_) {
      return null;
    }
  }
  return null;
});

final isAuthenticatedProvider = Provider<bool>(
  (final ref) => ref.watch(supabaseAuthProvider).isConnected,
);
