import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../connectivity/connectivity_provider.dart';
import '../constants/app_constants.dart';
import '../logging/app_logger.dart';

/// Authentication status for Supabase connection
enum SupabaseAuthStatus { initializing, disconnected, connecting, connected }

/// Immutable state for Supabase authentication
class SupabaseAuthState {
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
}

const _secureStorage = FlutterSecureStorage();

/// Supabase provider with proper initialization handling
class SupabaseAuthNotifier extends Notifier<SupabaseAuthState> {
  final log = AppLogger.getLogger(name: 'SupabaseAuthNotifier');

  var _isInitialized = false;

  @override
  SupabaseAuthState build() {
    // Listen to connectivity changes
    ref.listen<bool>(isOfflineProvider, (final prev, final next) async {
      // From offline → online AND currently disconnected
      if ((prev ?? true) && next == false && state.isDisconnected) {
        await _initializeSupabase();
      } else if (next) {
        // Gone offline
        state = SupabaseAuthState.disconnected();
      }
    });

    // Initial setup
    _initializeSupabase();
    return SupabaseAuthState.initializing();
  }

  /// Initialize Supabase client from stored credentials
  Future<void> _initializeSupabase() async {
    try {
      final url = await _secureStorage.read(
        key: kSupabaseUrlKeySecureStorageKey,
      );
      final anonKey = await _secureStorage.read(
        key: kSupabaseAnonKeySecureStorageKey,
      );

      if (url == null || anonKey == null) {
        log.fine('No stored credentials found');
        state = SupabaseAuthState.disconnected();
        return;
      }

      // Check network connectivity
      await InternetAddress.lookup(Uri.parse(url).host);

      if (!_isInitialized) {
        await Supabase.initialize(
          url: url,
          anonKey: anonKey,
          debug: kDebugMode,
        );
        _isInitialized = true;
        log.info('Supabase initialized successfully');
      }

      // Check current session
      final session = Supabase.instance.client.auth.currentSession;
      state = session != null
          ? SupabaseAuthState.connected()
          : SupabaseAuthState.disconnected();

      log.fine('Auth state: ${state.status}');
    } catch (e) {
      log.warning('Supabase initialization failed: $e');
      state = SupabaseAuthState.disconnected();
    }
  }

  /// Login with email and password
  Future<void> loginWithEmail({
    required final String url,
    required final String anonKey,
    required final String email,
    required final String password,
    required final void Function(String message) onError,
  }) async {
    state = SupabaseAuthState.connecting();

    try {
      // Validate network connectivity
      await InternetAddress.lookup(Uri.parse(url).host);

      // Check if we need to reinitialize
      if (_isInitialized) {
        // Properly dispose old client
        await Supabase.instance.client.dispose();
        _isInitialized = false;
      } else {
        await Supabase.initialize(
          url: url,
          anonKey: anonKey,
          debug: kDebugMode,
        );
        _isInitialized = true;
      }

      // Attempt sign in
      final response = await Supabase.instance.client.auth.signInWithPassword(
        email: email,
        password: password,
      );

      if (response.session != null) {
        // Save credentials securely
        await _secureStorage.write(
          key: kSupabaseUrlKeySecureStorageKey,
          value: url,
        );
        await _secureStorage.write(
          key: kSupabaseAnonKeySecureStorageKey,
          value: anonKey,
        );

        state = SupabaseAuthState.connected();
        log.info('Login successful');
      } else {
        throw Exception('Login failed: No session returned');
      }
    } catch (e) {
      log.warning('Login failed: $e');
      onError(e.toString());
      state = SupabaseAuthState.disconnected();
    }
  }

  /// Logout current user
  Future<void> logout(final void Function(String message) onError) async {
    try {
      if (_isInitialized) {
        await Supabase.instance.client.auth.signOut();
        log.info('Logout successful');
      }
    } catch (e) {
      log.warning('Logout failed: $e');
      onError(e.toString());
    } finally {
      state = SupabaseAuthState.disconnected();
    }
  }

  /// Manually trigger re-initialization (for debugging)
  Future<void> reinitialize() async {
    if (_isInitialized) {
      await Supabase.instance.client.dispose();
      _isInitialized = false;
    }
    await _initializeSupabase();
  }
}

/// Provider for Supabase authentication state
final supabaseAuthProvider =
    NotifierProvider<SupabaseAuthNotifier, SupabaseAuthState>(
      SupabaseAuthNotifier.new,
    );

/// Convenience provider to get Supabase client directly
final supabaseClientProvider = Provider<SupabaseClient?>((final ref) {
  final authState = ref.watch(supabaseAuthProvider);
  return authState.isConnected ? Supabase.instance.client : null;
});

/// Provider to check if user is authenticated
final isAuthenticatedProvider = Provider<bool>((final ref) {
  final authState = ref.watch(supabaseAuthProvider);
  return authState.isConnected;
});
