import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:material_symbols_icons/symbols.dart';

import '../connectivity/connectivity_repository.dart';
import '../constants/app_constants.dart';
import '../localizations/extensions/l10n_extensions.dart';
import '../logging/app_logger.dart';
import '../providers/offline_banner_provider.dart';

class OfflineBanner extends ConsumerStatefulWidget {
  const OfflineBanner({required this.child, super.key});

  final Widget child;

  @override
  ConsumerState<OfflineBanner> createState() => _OfflineBannerState();
}

class _OfflineBannerState extends ConsumerState<OfflineBanner> {
  static final log = AppLogger.getLogger(name: 'OfflineBanner');

  @override
  void initState() {
    super.initState();

    final isOffline = ConnectivityRepository.instance.isOfflineListenable.value;
    log.fine('Connectivity init check. isOffline: $isOffline');
    if (isOffline) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        ref.read(offlineBannerProvider.notifier).toggle(isOffline: isOffline);
      });
    }

    ConnectivityRepository.instance.isOfflineListenable.addListener(
      _updateBanner,
    );
  }

  @override
  void dispose() {
    ConnectivityRepository.instance.isOfflineListenable.removeListener(
      _updateBanner,
    );
    super.dispose();
  }

  void _updateBanner() {
    final isOffline = ConnectivityRepository.instance.isOfflineListenable.value;
    log.fine('Connectivity changed. isOffline: $isOffline');
    ref.read(offlineBannerProvider.notifier).toggle(isOffline: isOffline);
  }

  @override
  Widget build(final BuildContext context) {
    final bannerState = ref.watch(offlineBannerProvider);

    return Stack(
      fit: StackFit.expand,
      children: [
        widget.child,
        Positioned(
          top: 0,
          left: kIsWindows ? 400 : 0.2.sw,
          right: kIsWindows ? 350 : 0.2.sw,
          child: SizedBox(
            height: bannerState.isVisible ? kDefaultAppBannerOfflineHeight : 0,
            child: ClipRRect(
              borderRadius: BorderRadius.vertical(
                bottom: Radius.circular(kIsWindows ? 12 : 8.r),
              ),
              child: BackdropFilter(
                filter: ImageFilter.blur(sigmaX: 2, sigmaY: 2),
                child: AnimatedContainer(
                  duration: kDefaultAppAnimationsDuration,
                  height: bannerState.isVisible
                      ? kDefaultAppBannerOfflineHeight
                      : 0,
                  curve: Curves.easeInOut,
                  decoration: BoxDecoration(
                    color: bannerState.isOffline
                        ? Theme.of(
                            context,
                          ).colorScheme.errorContainer.withValues(alpha: 0.75)
                        : (bannerState.isOnline
                              ? Colors.green.withValues(alpha: 0.75)
                              : Colors.transparent),
                    borderRadius: BorderRadius.vertical(
                      bottom: Radius.circular(kIsWindows ? 12 : 8.r),
                    ),
                  ),
                  child: bannerState.isVisible
                      ? Center(
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              if (bannerState.isOffline)
                                Icon(
                                  Symbols.wifi_off_rounded,
                                  color: Theme.of(
                                    context,
                                  ).colorScheme.onErrorContainer,
                                  size: kIsWindows ? 24 : 18.sp,
                                ),
                              if (bannerState.isOffline)
                                SizedBox(width: kIsWindows ? 8 : 8.w),
                              Text(
                                bannerState.isOffline
                                    ? context.l10n.offlineBanner
                                    : context.l10n.onlineBanner,
                                style: TextStyle(
                                  color: bannerState.isOffline
                                      ? Theme.of(
                                          context,
                                        ).colorScheme.onErrorContainer
                                      : Colors.white,
                                  fontSize: kIsWindows ? 16 : 13.sp,
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                              if (bannerState.isOffline)
                                SizedBox(width: kIsWindows ? 8 : 8.w),
                              if (bannerState.isOffline)
                                SizedBox.square(
                                  dimension: kIsWindows ? 18 : 14.r,
                                  child: CircularProgressIndicator(
                                    strokeWidth: kIsWindows ? 3 : 2.w,
                                    valueColor: AlwaysStoppedAnimation(
                                      Theme.of(
                                        context,
                                      ).colorScheme.onErrorContainer,
                                    ),
                                  ),
                                ),
                            ],
                          ),
                        )
                      : const SizedBox.shrink(),
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }
}
