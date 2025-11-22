import 'package:beauty_center/core/constants/app_constants.dart';
import 'package:beauty_center/core/localizations/extensions/l10n_extensions.dart';
import 'package:beauty_center/core/widgets/custom_snackbar.dart';
import 'package:beauty_center/core/widgets/pin/secure_page_wrapper.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:material_symbols_icons/symbols.dart';

import '../providers/supabase_auth_provider.dart';

class SupabaseLoginDialog extends ConsumerStatefulWidget {
  const SupabaseLoginDialog({super.key});

  @override
  ConsumerState<SupabaseLoginDialog> createState() =>
      _SupabaseLoginDialogState();
}

class _SupabaseLoginDialogState extends ConsumerState<SupabaseLoginDialog> {
  final _formKey = GlobalKey<FormState>();

  static const _secureStorage = FlutterSecureStorage();

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
    if (!_formKey.currentState!.validate()) return;

    FocusScope.of(context).unfocus();

    try {
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
    } catch (e) {
      if (!mounted) return;

      showCustomSnackBar(
        context: context,
        message: 'Errore durante il login: $e',
        type: SnackBarType.error,
      );
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

    return SecurePageWrapper(
      child: AlertDialog(
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(kIsWindows ? 18 : 18.r),
        ),
        backgroundColor: colorScheme.surfaceContainerHigh,
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
            child: Form(
              key: _formKey,
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
                  TextFormField(
                    controller: _urlController,
                    decoration: const InputDecoration(
                      labelText: 'Supabase URL',
                      border: OutlineInputBorder(),
                    ),
                    keyboardType: TextInputType.url,
                    textInputAction: TextInputAction.next,
                    validator: (final value) =>
                        value == null || value.isEmpty ? 'URL richiesto' : null,
                  ),
                  SizedBox(height: kIsWindows ? 12 : 12.h),
                  TextFormField(
                    controller: _anonKeyController,
                    obscureText: !_showAnonKey,
                    validator: (final value) => value == null || value.isEmpty
                        ? 'Anon Key richiesta'
                        : null,
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
                                onPressed: () => setState(
                                  () => _showAnonKey = !_showAnonKey,
                                ),
                              ),
                            ),
                    ),
                  ),
                  SizedBox(height: kIsWindows ? 12 : 12.h),
                  AutofillGroup(
                    child: Column(
                      children: [
                        TextFormField(
                          controller: _emailController,
                          decoration: const InputDecoration(
                            labelText: 'Email',
                            border: OutlineInputBorder(),
                          ),
                          keyboardType: TextInputType.emailAddress,
                          textInputAction: TextInputAction.next,
                          autofillHints: const [AutofillHints.email],
                          validator: (final value) =>
                              value == null || value.isEmpty
                              ? 'Email richiesta'
                              : null,
                        ),
                        SizedBox(height: kIsWindows ? 12 : 12.h),
                        TextFormField(
                          controller: _passwordController,
                          obscureText: !_showPassword,
                          autofillHints: const [AutofillHints.password],
                          validator: (final value) =>
                              value == null || value.isEmpty
                              ? 'Password richiesta'
                              : null,
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
        ),
        actions: [
          TextButton.icon(
            onPressed: isLoading
                ? null
                : () async {
                    await ref.read(supabaseAuthProvider.notifier).logout();
                  },
            icon: Icon(Symbols.logout, color: colorScheme.primary),
            label: Text('Logout', style: TextStyle(color: colorScheme.primary)),
          ),
          TextButton(
            onPressed: isLoading ? null : () => Navigator.of(context).pop(),
            child: Text(context.l10n.cancel),
          ),
          SizedBox(width: kIsWindows ? 8 : 8.w),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: colorScheme.primary,
              foregroundColor: colorScheme.onPrimary,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(kIsWindows ? 12 : 12.r),
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

                if (isLoading) SizedBox(width: kIsWindows ? 8 : 8.w),
                SizedBox(width: kIsWindows ? 8 : 8.w),
                const Text('Login'),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
