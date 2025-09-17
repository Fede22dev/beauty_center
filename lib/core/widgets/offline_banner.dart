import 'dart:async';

import 'package:beauty_center/core/extensions/l10n_extensions.dart';
import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:material_symbols_icons/symbols.dart';

import '../connectivity/connectivity_repository.dart';
import '../constants/app_constants.dart';

/// Overlay that envelops the shelf and shows the offline banner at the top.
class OfflineScaffoldOverlay extends StatelessWidget {
  const OfflineScaffoldOverlay({required this.child, super.key});

  final Widget child;

  @override
  Widget build(final BuildContext context) => ValueListenableBuilder<bool>(
    valueListenable: ConnectivityRepository.instance.isOfflineListenable,
    builder: (final context, final offline, _) => Stack(
      fit: StackFit.expand,
      children: [
        child,
        Positioned(
          top: 0,
          left: 0.2.sw,
          right: 0.2.sw,
          child: OfflineBanner(isOffline: offline),
        ),
      ],
    ),
  );
}

/// Inline banner, for example inside a list of or page or app bar.
class InlineConnectivityBanner extends StatelessWidget {
  const InlineConnectivityBanner({super.key});

  @override
  Widget build(final BuildContext context) => ValueListenableBuilder<bool>(
    valueListenable: ConnectivityRepository.instance.isOfflineListenable,
    builder: (final context, final offline, _) =>
        OfflineBanner(isOffline: offline),
  );
}

class OfflineBanner extends StatefulWidget {
  const OfflineBanner({required this.isOffline, super.key});

  final bool isOffline;

  @override
  State<OfflineBanner> createState() => _OfflineBannerState();
}

class _OfflineBannerState extends State<OfflineBanner> {
  var _showOnlineBanner = false;
  var _initialized = false;

  @override
  void didUpdateWidget(covariant final OfflineBanner oldWidget) {
    super.didUpdateWidget(oldWidget);

    if (_initialized && oldWidget.isOffline && !widget.isOffline) {
      setState(() => _showOnlineBanner = true);
      Future.delayed(const Duration(seconds: 3), () {
        if (mounted) setState(() => _showOnlineBanner = false);
      });
    } else {
      _initialized = true;
    }
  }

  @override
  Widget build(final BuildContext context) {
    // Banner ONLINE
    if (_showOnlineBanner) {
      return AnimatedContainer(
        duration: kDefaultAppAnimationsDuration,
        curve: Curves.easeInOut,
        height: (kIsDesktop ? 38 : 32).h,
        width: 0.8.sw,
        decoration: BoxDecoration(
          color: Colors.green,
          borderRadius: BorderRadius.vertical(bottom: Radius.circular(8.r)),
        ),
        child: Center(
          child: Text(
            context.l10n.onlineBanner,
            style: TextStyle(
              color: Colors.white,
              fontSize: (kIsDesktop ? 6 : 13).sp,
              fontWeight: FontWeight.w700,
            ),
          ),
        ),
      );
    }

    final colorScheme = Theme.of(context).colorScheme;

    // Banner OFFLINE
    return AnimatedContainer(
      duration: kDefaultAppAnimationsDuration,
      curve: Curves.easeInOut,
      width: 0.8.sw,
      height: widget.isOffline ? (kIsDesktop ? 38 : 32).h : 0,
      decoration: BoxDecoration(
        color: widget.isOffline
            ? colorScheme.errorContainer
            : Colors.transparent,
        borderRadius: BorderRadius.vertical(bottom: Radius.circular(8.r)),
      ),
      child: widget.isOffline
          ? Center(
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    Symbols.wifi_off_rounded,
                    color: colorScheme.onErrorContainer,
                    size: (kIsDesktop ? 8 : 18).sp,
                  ),
                  SizedBox(width: 8.w),
                  Text(
                    context.l10n.offlineBanner,
                    style: TextStyle(
                      color: colorScheme.onErrorContainer,
                      fontSize: (kIsDesktop ? 6 : 13).sp,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  SizedBox(width: 8.w),
                  SizedBox.square(
                    dimension: (kIsDesktop ? 18 : 14).r,
                    child: CircularProgressIndicator(
                      strokeWidth: (kIsDesktop ? 1 : 2).w,
                      valueColor: AlwaysStoppedAnimation<Color>(
                        colorScheme.onErrorContainer,
                      ),
                    ),
                  ),
                ],
              ),
            )
          : const SizedBox.shrink(),
    );
  }
}
