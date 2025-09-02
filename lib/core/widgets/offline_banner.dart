import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:material_symbols_icons/symbols.dart';

import '../../generated/l10n.dart';
import '../connectivity/connectivity_repository.dart';
import '../constants/app_constants.dart';

class OfflineScaffoldOverlay extends StatelessWidget {
  const OfflineScaffoldOverlay({super.key, required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<bool>(
      valueListenable: ConnectivityRepository.instance.isOfflineListenable,
      builder: (context, offline, child) {
        return Stack(
          fit: StackFit.expand,
          children: [
            this.child,
            Positioned(
              top: 0,
              left: 0.2.sw,
              right: 0.2.sw,
              child: OfflineBanner(isOffline: false),
            ),
          ],
        );
      },
    );
  }
}

class InlineConnectivityBanner extends StatelessWidget {
  const InlineConnectivityBanner({super.key});

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<bool>(
      valueListenable: ConnectivityRepository.instance.isOfflineListenable,
      builder: (context, offline, child) {
        return OfflineBanner(isOffline: offline);
      },
    );
  }
}

class OfflineBanner extends StatefulWidget {
  const OfflineBanner({super.key, required this.isOffline});

  final bool isOffline;

  @override
  State<OfflineBanner> createState() => _OfflineBannerState();
}

class _OfflineBannerState extends State<OfflineBanner> {
  bool _showOnlineBanner = false;
  bool _firstBuildDone = false;

  @override
  void didUpdateWidget(covariant OfflineBanner oldWidget) {
    super.didUpdateWidget(oldWidget);

    if (_firstBuildDone) {
      if (oldWidget.isOffline && !widget.isOffline) {
        setState(() => _showOnlineBanner = true);
        Future.delayed(const Duration(seconds: 3), () {
          if (mounted) setState(() => _showOnlineBanner = false);
        });
      }
    } else {
      _firstBuildDone = true;
    }
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    if (_showOnlineBanner) {
      return AnimatedContainer(
        duration: kDefaultAppAnimationsDuration,
        height: (kTargetOsIsDesktop ? 36 : 32).h,
        width: 0.8.sw,
        decoration: BoxDecoration(
          color: Colors.green,
          borderRadius: BorderRadius.vertical(bottom: Radius.circular(8.r)),
        ),
        child: Center(
          child: Text(
            S.of(context).onlineBanner,
            style: TextStyle(
              color:
                  ThemeData.estimateBrightnessForColor(Colors.green) ==
                      Brightness.dark
                  ? Colors.white
                  : Colors.black,
              fontSize: (kTargetOsIsDesktop ? 6 : 13).sp,
              fontWeight: FontWeight.w700,
            ),
          ),
        ),
      );
    }

    return AnimatedContainer(
      duration: kDefaultAppAnimationsDuration,
      width: 0.8.sw,
      height: !widget.isOffline ? 0 : (kTargetOsIsDesktop ? 36 : 32).h,
      decoration: BoxDecoration(
        color: !widget.isOffline
            ? Colors.transparent
            : colorScheme.errorContainer,
        borderRadius: BorderRadius.vertical(bottom: Radius.circular(8.r)),
      ),
      child: !widget.isOffline
          ? const SizedBox.shrink()
          : Center(
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(
                    Symbols.wifi_off_rounded,
                    color: colorScheme.onErrorContainer,
                    size: (kTargetOsIsDesktop ? 8 : 18).sp,
                  ),
                  SizedBox(width: 8.w),
                  Text(
                    S.of(context).offlineBanner,
                    style: TextStyle(
                      color: colorScheme.onErrorContainer,
                      fontSize: (kTargetOsIsDesktop ? 6 : 13).sp,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  SizedBox(width: 8.w),
                  SizedBox.square(
                    dimension: (kTargetOsIsDesktop ? 18 : 14).r,
                    child: CircularProgressIndicator(
                      strokeWidth: (kTargetOsIsDesktop ? 1 : 2).w,
                      valueColor: AlwaysStoppedAnimation<Color>(
                        colorScheme.onErrorContainer,
                      ),
                    ),
                  ),
                ],
              ),
            ),
    );
  }
}
