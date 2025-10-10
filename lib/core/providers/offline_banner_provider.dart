import 'package:flutter_riverpod/flutter_riverpod.dart';

enum OfflineBannerStatus { hidden, offline, online }

class OfflineBannerState {
  const OfflineBannerState(this.status);

  factory OfflineBannerState.offline() =>
      const OfflineBannerState(OfflineBannerStatus.offline);

  factory OfflineBannerState.hidden() =>
      const OfflineBannerState(OfflineBannerStatus.hidden);

  factory OfflineBannerState.online() =>
      const OfflineBannerState(OfflineBannerStatus.online);
  final OfflineBannerStatus status;

  bool get isVisible => status != OfflineBannerStatus.hidden;

  bool get isOffline => status == OfflineBannerStatus.offline;

  bool get isOnline => status == OfflineBannerStatus.online;
}

class OfflineBannerNotifier extends Notifier<OfflineBannerState> {
  @override
  OfflineBannerState build() => OfflineBannerState.hidden();

  void toggle({required final bool isOffline}) {
    if (isOffline) {
      state = OfflineBannerState.offline();
    } else {
      state = OfflineBannerState.online();
      Future.delayed(const Duration(seconds: 3), () {
        if (state.isOnline) {
          state = OfflineBannerState.hidden();
        }
      });
    }
  }
}

final offlineBannerProvider =
    NotifierProvider<OfflineBannerNotifier, OfflineBannerState>(
      OfflineBannerNotifier.new,
    );
