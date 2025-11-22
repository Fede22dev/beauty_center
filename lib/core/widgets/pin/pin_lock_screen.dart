import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:material_symbols_icons/symbols.dart';
import 'package:pinput/pinput.dart';

import '../../config/app_secrets.dart';
import '../../constants/app_constants.dart';
import '../../providers/pin_lock_provider.dart';

class PinLockScreen extends ConsumerStatefulWidget {
  const PinLockScreen({this.pageColor, super.key});

  final Color? pageColor;

  @override
  ConsumerState<PinLockScreen> createState() => _PinLockScreenState();
}

class _PinLockScreenState extends ConsumerState<PinLockScreen> {
  late final TextEditingController _pinController;
  late final FocusNode _focusNode;
  late final int _pinLength;

  String? _errorMessage;
  var _isVerifying = false;

  @override
  void initState() {
    super.initState();
    _pinController = TextEditingController();
    _focusNode = FocusNode();
    _pinLength = AppSecrets.adminPin.length;
  }

  @override
  void dispose() {
    _pinController.dispose();
    _focusNode.dispose();
    super.dispose();
  }

  Future<void> _onPinCompleted(final String pin) async {
    if (_isVerifying || !mounted) return;

    setState(() {
      _isVerifying = true;
    });

    await Future<void>.delayed(100.ms);
    if (!mounted) return;

    if (pin == AppSecrets.adminPin) {
      ref.read(pinLockProvider.notifier).unlock();
      return;
    }

    setState(() {
      _errorMessage = 'PIN non valido';
      _isVerifying = false;
    });

    await Future<void>.delayed(100.ms);
    if (mounted && _pinController.text.isNotEmpty) {
      _pinController.clear();
      _focusNode.requestFocus();
    }
  }

  @override
  Widget build(final BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    final effectivePageColor =
        widget.pageColor ??
        Theme.of(context).colorScheme.surfaceContainerHighest;

    return Scaffold(
      body: DecoratedBox(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: [
              effectivePageColor.withValues(alpha: 0.25),
              colorScheme.primary.withValues(alpha: 0.25),
            ],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
        ),
        child: SafeArea(
          child: Center(
            child: SingleChildScrollView(
              physics: const BouncingScrollPhysics(),
              padding: EdgeInsets.symmetric(
                horizontal: kIsWindows ? 32 : 32.w,
                vertical: kIsWindows ? 24 : 24.h,
              ),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  _buildLockIcon(colorScheme),
                  SizedBox(height: kIsWindows ? 32 : 32.h),
                  _buildTitle(),
                  SizedBox(height: kIsWindows ? 48 : 48.h),
                  _buildPinInput(colorScheme),
                  SizedBox(height: kIsWindows ? 24 : 24.h),
                  _buildErrorMessage(colorScheme),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildLockIcon(final ColorScheme colorScheme) =>
      Container(
            padding: EdgeInsets.all(kIsWindows ? 24 : 24.w),
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              gradient: LinearGradient(
                colors: [
                  colorScheme.primary.withValues(alpha: 0.2),
                  colorScheme.primary.withValues(alpha: 0.05),
                ],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              boxShadow: [
                BoxShadow(
                  color: colorScheme.primary.withValues(alpha: 0.1),
                  blurRadius: kIsWindows ? 32 : 32.r,
                  spreadRadius: kIsWindows ? 8 : 8.r,
                ),
              ],
            ),
            child: Icon(
              Symbols.shield_lock_rounded,
              size: kIsWindows ? 64 : 64.sp,
              color: colorScheme.primary,
            ),
          )
          .animate()
          .fadeIn(duration: kDefaultAppAnimationsDuration, delay: 100.ms)
          .scale(
            begin: const Offset(0.8, 0.8),
            duration: kDefaultAppAnimationsDuration,
          );

  Widget _buildTitle() =>
      Text(
            'Inserisci il PIN admin',
            style: TextStyle(
              fontSize: kIsWindows ? 20 : 20.sp,
              fontWeight: FontWeight.bold,
              letterSpacing: -0.5,
            ),
            textAlign: TextAlign.center,
          )
          .animate()
          .fadeIn(duration: kDefaultAppAnimationsDuration, delay: 200.ms)
          .slideY(begin: -0.2, end: 0, duration: kDefaultAppAnimationsDuration);

  Widget _buildPinInput(final ColorScheme colorScheme) {
    final defaultPinTheme = PinTheme(
      width: kIsWindows ? 56 : 56.w,
      height: kIsWindows ? 64 : 64.h,
      textStyle: TextStyle(
        fontSize: kIsWindows ? 24 : 24.sp,
        fontWeight: FontWeight.w600,
        color: colorScheme.onSurface,
      ),
      decoration: BoxDecoration(
        color: colorScheme.surface.withValues(alpha: 0.5),
        borderRadius: BorderRadius.circular(kIsWindows ? 16 : 16.r),
        border: Border.all(
          color: colorScheme.outline.withValues(alpha: 0.2),
          width: kIsWindows ? 1.5 : 1.5.w,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.05),
            blurRadius: kIsWindows ? 8 : 8.r,
            offset: const Offset(0, 2),
          ),
        ],
      ),
    );

    final focusedPinTheme = defaultPinTheme.copyWith(
      decoration: defaultPinTheme.decoration!.copyWith(
        color: colorScheme.primaryContainer.withValues(alpha: 0.3),
        border: Border.all(
          color: colorScheme.primary,
          width: kIsWindows ? 2 : 2.w,
        ),
        boxShadow: [
          BoxShadow(
            color: colorScheme.primary.withValues(alpha: 0.25),
            blurRadius: kIsWindows ? 16 : 16.r,
            spreadRadius: kIsWindows ? 2 : 2.r,
          ),
        ],
      ),
    );

    final errorPinTheme = defaultPinTheme.copyWith(
      decoration: defaultPinTheme.decoration!.copyWith(
        color: colorScheme.errorContainer.withValues(alpha: 0.2),
        border: Border.all(
          color: colorScheme.error,
          width: kIsWindows ? 2 : 2.w,
        ),
      ),
    );

    final submittedPinTheme = defaultPinTheme.copyWith(
      decoration: defaultPinTheme.decoration!.copyWith(
        color: colorScheme.primary.withValues(alpha: 0.1),
        border: Border.all(
          color: colorScheme.primary.withValues(alpha: 0.5),
          width: kIsWindows ? 1.5 : 1.5.w,
        ),
      ),
    );

    return Animate(
          effects: _errorMessage != null
              ? [
                  const ShakeEffect(
                    duration: kDefaultAppAnimationsDuration,
                    hz: 4,
                    offset: Offset(10, 0),
                  ),
                ]
              : [],
          child: Pinput(
            controller: _pinController,
            focusNode: _focusNode,
            length: _pinLength,
            defaultPinTheme: defaultPinTheme,
            focusedPinTheme: focusedPinTheme,
            submittedPinTheme: submittedPinTheme,
            errorPinTheme: _errorMessage != null ? errorPinTheme : null,
            onChanged: (final value) {
              if (_errorMessage != null) {
                setState(() {
                  _errorMessage = null;
                });
              }
            },
            onCompleted: _onPinCompleted,
            enabled: !_isVerifying,
            obscureText: true,
            autofocus: true,
            obscuringWidget: Container(
              width: kIsWindows ? 10 : 10.w,
              height: kIsWindows ? 10 : 10.w,
              decoration: BoxDecoration(
                color: colorScheme.primary,
                shape: BoxShape.circle,
              ),
            ),
            cursor: Column(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                Container(
                  margin: EdgeInsets.only(bottom: kIsWindows ? 12 : 12.h),
                  width: kIsWindows ? 24 : 24.w,
                  height: kIsWindows ? 2 : 2.h,
                  decoration: BoxDecoration(
                    color: colorScheme.primary,
                    borderRadius: BorderRadius.circular(kIsWindows ? 1 : 1.r),
                  ),
                ),
              ],
            ),
            animationDuration: kDefaultAppAnimationsDuration,
            animationCurve: Curves.easeInOut,
          ),
        )
        .animate()
        .fadeIn(duration: kDefaultAppAnimationsDuration, delay: 300.ms)
        .slideY(begin: 0.2, duration: kDefaultAppAnimationsDuration)
        .then()
        .animate(target: _isVerifying ? 1 : 0)
        .scaleXY(end: 0.98, duration: kDefaultAppAnimationsDuration);
  }

  Widget _buildErrorMessage(final ColorScheme colorScheme) => AnimatedSize(
    duration: kDefaultAppAnimationsDuration,
    curve: Curves.easeOutCubic,
    alignment: Alignment.topCenter,
    child: _errorMessage == null
        ? SizedBox(height: kIsWindows ? 24 : 24.h)
        : Container(
                padding: EdgeInsets.symmetric(
                  horizontal: kIsWindows ? 16 : 16.w,
                  vertical: kIsWindows ? 12 : 12.h,
                ),
                decoration: BoxDecoration(
                  color: colorScheme.errorContainer.withValues(alpha: 0.3),
                  borderRadius: BorderRadius.circular(kIsWindows ? 12 : 12.r),
                  border: Border.all(
                    color: colorScheme.error.withValues(alpha: 0.5),
                    width: kIsWindows ? 1 : 1.w,
                  ),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      Symbols.error_outline,
                      color: colorScheme.error,
                      size: kIsWindows ? 20 : 20.sp,
                    ),
                    SizedBox(width: kIsWindows ? 8 : 8.w),
                    Flexible(
                      child: Text(
                        _errorMessage!,
                        style: TextStyle(
                          fontSize: kIsWindows ? 14 : 14.sp,
                          color: colorScheme.error,
                          fontWeight: FontWeight.w600,
                        ),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ],
                ),
              )
              .animate(key: ValueKey(_errorMessage))
              .fadeIn(
                duration: kDefaultAppAnimationsDuration,
                curve: Curves.easeOutCubic,
              )
              .slideY(
                begin: -0.3,
                end: 0,
                duration: kDefaultAppAnimationsDuration,
                curve: Curves.easeOutCubic,
              ),
  );
}
