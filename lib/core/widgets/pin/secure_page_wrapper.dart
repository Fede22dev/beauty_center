import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../providers/pin_lock_provider.dart';
import 'pin_lock_screen.dart';

class SecurePageWrapper extends ConsumerWidget {
  const SecurePageWrapper({required this.child, this.pageColor, super.key});

  final Color? pageColor;
  final Widget child;

  @override
  Widget build(final BuildContext context, final WidgetRef ref) {
    final isLocked = ref.watch(pinLockProvider);

    if (isLocked) {
      return PinLockScreen(pageColor: pageColor);
    }

    return child;
  }
}
