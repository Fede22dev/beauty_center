import 'package:beauty_center/core/constants/app_constants.dart';
import 'package:beauty_center/core/localizations/extensions/l10n_extensions.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:material_symbols_icons/symbols.dart';

import '../supabase/supabase_auth_provider.dart';

const _secureStorage = FlutterSecureStorage();

class SupabaseLoginDialog extends ConsumerStatefulWidget {
  const SupabaseLoginDialog({super.key});

  @override
  ConsumerState<SupabaseLoginDialog> createState() =>
      _SupabaseLoginDialogState();
}

class _SupabaseLoginDialogState extends ConsumerState<SupabaseLoginDialog> {
  final _urlController = TextEditingController();
  final _anonKeyController = TextEditingController();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();

  var _showAnonKey = false;
  var _showPassword = false;

  @override
  void initState() {
    super.initState();

    _anonKeyController.addListener(() => setState(() {}));
    _passwordController.addListener(() => setState(() {}));

    _loadSavedCredentials();
  }

  Future<void> _loadSavedCredentials() async {
    final savedUrl = await _secureStorage.read(
      key: kSupabaseUrlKeySecureStorageKey,
    );
    final savedKey = await _secureStorage.read(
      key: kSupabaseAnonKeySecureStorageKey,
    );

    if (mounted) {
      setState(() {
        _urlController.text = savedUrl ?? '';
        _anonKeyController.text = savedKey ?? '';
      });
    }
  }

  Future<void> _handleLogin() async {
    await ref
        .read(supabaseAuthProvider.notifier)
        .loginWithEmail(
          url: _urlController.text.trim(),
          anonKey: _anonKeyController.text.trim(),
          email: _emailController.text.trim(),
          password: _passwordController.text.trim(),
        );

    if (!mounted) return;

    final state = ref.read(supabaseAuthProvider);
    if (state.isConnected) {
      Navigator.of(context).pop();
    }
  }

  @override
  void dispose() {
    _urlController.dispose();
    _anonKeyController.dispose();
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  @override
  Widget build(final BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final isLoading = ref.watch(supabaseAuthProvider).isConnecting;

    return AlertDialog(
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(kIsWindows ? 18 : 18.r),
      ),
      backgroundColor: colorScheme.surface,
      title: Row(
        children: [
          Icon(Symbols.cloud, color: colorScheme.primary),
          SizedBox(width: kIsWindows ? 8 : 8.w),
          const Text('Login Supabase'),
        ],
      ),
      content: SizedBox(
        width: kIsWindows ? 360 : 360.w,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                context.l10n.insertCredentialsSupabase,
                style: TextStyle(
                  color: colorScheme.onSurface.withValues(alpha: 0.8),
                  fontSize: kIsWindows ? 13 : 13.sp,
                ),
              ),
              SizedBox(height: kIsWindows ? 16 : 16.h),
              TextField(
                controller: _urlController,
                decoration: const InputDecoration(
                  labelText: 'Supabase URL',
                  border: OutlineInputBorder(),
                ),
                keyboardType: TextInputType.url,
                textInputAction: TextInputAction.next,
              ),
              SizedBox(height: kIsWindows ? 12 : 12.h),
              TextField(
                controller: _anonKeyController,
                obscureText: !_showAnonKey,
                decoration: InputDecoration(
                  labelText: 'Anon Key',
                  border: const OutlineInputBorder(),
                  suffixIcon: _anonKeyController.text.isEmpty
                      ? null
                      : Opacity(
                          opacity: 0.6,
                          child: IconButton(
                            icon: Icon(
                              _showAnonKey
                                  ? Symbols.visibility_off
                                  : Symbols.visibility,
                              weight: 600,
                            ),
                            onPressed: () =>
                                setState(() => _showAnonKey = !_showAnonKey),
                          ),
                        ),
                ),
              ),
              SizedBox(height: kIsWindows ? 12 : 12.h),
              AutofillGroup(
                child: Column(
                  children: [
                    TextField(
                      controller: _emailController,
                      decoration: const InputDecoration(
                        labelText: 'Email',
                        border: OutlineInputBorder(),
                      ),
                      keyboardType: TextInputType.emailAddress,
                      textInputAction: TextInputAction.next,
                      autofillHints: const [AutofillHints.email],
                    ),
                    SizedBox(height: kIsWindows ? 12 : 12.h),
                    TextField(
                      controller: _passwordController,
                      obscureText: !_showPassword,
                      autofillHints: const [AutofillHints.password],
                      decoration: InputDecoration(
                        labelText: 'Password',
                        border: const OutlineInputBorder(),
                        suffixIcon: _passwordController.text.isEmpty
                            ? null
                            : Opacity(
                                opacity: 0.6,
                                child: IconButton(
                                  icon: Icon(
                                    _showPassword
                                        ? Symbols.visibility_off
                                        : Symbols.visibility,
                                    weight: 600,
                                  ),
                                  onPressed: () => setState(
                                    () => _showPassword = !_showPassword,
                                  ),
                                ),
                              ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
      actions: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            TextButton.icon(
              onPressed: isLoading
                  ? null
                  : () async {
                      await ref.read(supabaseAuthProvider.notifier).logout();
                    },
              icon: Icon(Symbols.logout, color: colorScheme.primary),
              label: Text(
                'Logout',
                style: TextStyle(color: colorScheme.primary),
              ),
            ),
            Row(
              children: [
                TextButton(
                  onPressed: isLoading
                      ? null
                      : () => Navigator.of(context).pop(),
                  child: Text(context.l10n.cancel),
                ),
                SizedBox(width: kIsWindows ? 8 : 8.w),
                ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: colorScheme.primary,
                    foregroundColor: colorScheme.onPrimary,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(
                        kIsWindows ? 12 : 12.r,
                      ),
                    ),
                    padding: EdgeInsets.symmetric(
                      horizontal: kIsWindows ? 20 : 20.w,
                      vertical: kIsWindows ? 10 : 10.h,
                    ),
                  ),
                  onPressed: isLoading ? null : _handleLogin,
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      if (isLoading)
                        SizedBox(
                          height: kIsWindows ? 18 : 18.h,
                          width: kIsWindows ? 18 : 18.w,
                          child: CircularProgressIndicator(
                            strokeWidth: kIsWindows ? 2 : 2.w,
                            color: Colors.white,
                          ),
                        )
                      else
                        Icon(Symbols.login, size: kIsWindows ? 20 : 20.sp),
                      SizedBox(width: kIsWindows ? 8 : 8.w),
                      Text(isLoading ? '' : 'Login'),
                    ],
                  ),
                ),
              ],
            ),
          ],
        ),
      ],
    );
  }
}
