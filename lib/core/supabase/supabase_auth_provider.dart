import 'dart:io';

import 'package:beauty_center/core/constants/app_constants.dart';
import 'package:beauty_center/core/localizations/extensions/l10n_extensions.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../connectivity/connectivity_provider.dart';

enum SupabaseAuthStatus { initializing, disconnected, connecting, connected }

class SupabaseAuthState {
  const SupabaseAuthState(this.status, [this.errorMessage]);

  factory SupabaseAuthState.initializing() =>
      const SupabaseAuthState(SupabaseAuthStatus.initializing);

  factory SupabaseAuthState.disconnected([final String? error]) =>
      SupabaseAuthState(SupabaseAuthStatus.disconnected, error);

  factory SupabaseAuthState.connecting() =>
      const SupabaseAuthState(SupabaseAuthStatus.connecting);

  factory SupabaseAuthState.connected() =>
      const SupabaseAuthState(SupabaseAuthStatus.connected);

  final SupabaseAuthStatus status;
  final String? errorMessage;

  bool get isInitializing => status == SupabaseAuthStatus.initializing;

  bool get isDisconnected => status == SupabaseAuthStatus.disconnected;

  bool get isConnecting => status == SupabaseAuthStatus.connecting;

  bool get isConnected => status == SupabaseAuthStatus.connected;
}

const _secureStorage = FlutterSecureStorage();

class SupabaseAuthNotifier extends Notifier<SupabaseAuthState> {
  @override
  SupabaseAuthState build() {
    ref.listen<bool>(isOfflineProvider, (final prev, final next) async {
      if ((prev ?? true) && next == false && state.isDisconnected) {
        await _init();
      }
    });

    _init();
    return SupabaseAuthState.initializing();
  }

  Future<void> _init() async {
    try {
      final url = await _secureStorage.read(
        key: kSupabaseUrlKeySecureStorageKey,
      );
      final anonKey = await _secureStorage.read(
        key: kSupabaseAnonKeySecureStorageKey,
      );
      if (url == null || anonKey == null) return;

      await InternetAddress.lookup(Uri.parse(url).host);

      await Supabase.initialize(url: url, anonKey: anonKey);

      final session = Supabase.instance.client.auth.currentSession;
      state = session != null
          ? SupabaseAuthState.connected()
          : SupabaseAuthState.disconnected();
    } on SocketException catch (e) {
      state = SupabaseAuthState.disconnected(e.message);
    } on Exception catch (e) {
      state = SupabaseAuthState.disconnected(e.toString());
    }

    if (state.isConnected) {
      final supabase = Supabase.instance.client;
      final info = await PackageInfo.fromPlatform();

      final platform = Platform.isAndroid
          ? 'android'
          : Platform.isWindows
          ? 'windows'
          : 'unknown';

      final response = await supabase.functions.invoke(
        'check_update',
        body: {'platform': platform, 'currentVersion': info.version},
      );

      final data = response.data;
      if (data['hasUpdate'] == true) {
        print('Nuova versione disponibile: ${data['latestVersion']}');
        print('Download: ${data['downloadUrl']}');
        print('Descrizione: ${data['description']}');
      } else {
        print('App già aggiornata.');
      }
      print(data);
    }
  }

  Future<void> loginWithEmail({
    required final String url,
    required final String anonKey,
    required final String email,
    required final String password,
  }) async {
    final previousUrl = await _secureStorage.read(
      key: kSupabaseUrlKeySecureStorageKey,
    );
    final previousAnonKey = await _secureStorage.read(
      key: kSupabaseAnonKeySecureStorageKey,
    );
    final previousSession = Supabase.instance.client.auth.currentSession;

    state = SupabaseAuthState.connecting();

    try {
      await InternetAddress.lookup(Uri.parse(url).host);
      await Supabase.initialize(url: url, anonKey: anonKey);

      final response = await Supabase.instance.client.auth.signInWithPassword(
        email: email,
        password: password,
      );

      if (response.session != null) {
        await _secureStorage.write(
          key: kSupabaseUrlKeySecureStorageKey,
          value: url,
        );
        await _secureStorage.write(
          key: kSupabaseAnonKeySecureStorageKey,
          value: anonKey,
        );
        state = SupabaseAuthState.connected();
      } else {
        throw Exception(ref.l10n.loginErrorCredentials);
      }
    } on Exception catch (e) {
      if (previousUrl != null && previousAnonKey != null) {
        await Supabase.initialize(url: previousUrl, anonKey: previousAnonKey);
        if (previousSession != null) {
          state = SupabaseAuthState.connected();
        } else {
          state = SupabaseAuthState.disconnected(e.toString());
        }
      } else {
        state = SupabaseAuthState.disconnected(e.toString());
      }
    }
  }

  Future<void> logout() async {
    try {
      await Supabase.instance.client.auth.signOut();
    } on Exception catch (e) {
      state = SupabaseAuthState.disconnected(e.toString());
    }

    state = SupabaseAuthState.disconnected();
  }
}

final supabaseAuthProvider =
    NotifierProvider<SupabaseAuthNotifier, SupabaseAuthState>(
      SupabaseAuthNotifier.new,
    );
