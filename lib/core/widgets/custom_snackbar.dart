import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';

import '../constants/app_constants.dart';

OverlayEntry? _currentOverlay;

void showCustomSnackBar({
  required final BuildContext context,
  required final String message,
  required final Color okColor,
}) {
  final theme = Theme.of(context);
  final isDark = theme.brightness == Brightness.dark;
  final colorScheme = theme.colorScheme;

  _currentOverlay?.remove();
  _currentOverlay = null;

  final overlayEntry = OverlayEntry(
    builder: (final context) => _AnimatedCustomSnackBar(
      message: message,
      okColor: okColor,
      isDark: isDark,
      colorScheme: colorScheme,
      onDismissed: () {
        _currentOverlay?.remove();
        _currentOverlay = null;
      },
    ),
  );

  Overlay.of(context).insert(overlayEntry);
  _currentOverlay = overlayEntry;
}

class _AnimatedCustomSnackBar extends StatefulWidget {
  const _AnimatedCustomSnackBar({
    required this.message,
    required this.okColor,
    required this.isDark,
    required this.colorScheme,
    required this.onDismissed,
  });

  final String message;
  final Color okColor;
  final bool isDark;
  final ColorScheme colorScheme;
  final VoidCallback onDismissed;

  @override
  State<_AnimatedCustomSnackBar> createState() =>
      _AnimatedCustomSnackBarState();
}

class _AnimatedCustomSnackBarState extends State<_AnimatedCustomSnackBar>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<Offset> _offset;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: kDefaultAppAnimationsDuration,
    );

    _offset = Tween<Offset>(
      begin: const Offset(0, 1),
      end: Offset.zero,
    ).animate(CurvedAnimation(parent: _controller, curve: Curves.easeOutCubic));

    _controller.forward();

    Future<void>.delayed(const Duration(seconds: 3)).then((_) {
      if (mounted) {
        _controller.reverse().then((_) => widget.onDismissed());
      }
    });
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(final BuildContext context) => Positioned(
    bottom: kIsWindows ? 20 : MediaQuery.of(context).padding.bottom + 65.h,
    left: kIsWindows ? 16 : 16.w,
    right: kIsWindows ? 16 : 16.w,
    child: SlideTransition(
      position: _offset,
      child: Material(
        color: widget.isDark
            ? widget.colorScheme.surface.withValues(alpha: 0.9)
            : widget.colorScheme.surface.withValues(alpha: 0.95),
        elevation: 10,
        borderRadius: BorderRadius.circular(kIsWindows ? 12 : 12.r),
        child: Container(
          constraints: BoxConstraints(
            minHeight: kIsWindows ? 48 : 48.h,
            maxHeight: kIsWindows ? 100 : 100.h,
          ),
          child: Padding(
            padding: EdgeInsets.symmetric(
              horizontal: kIsWindows ? 12 : 12.w,
              vertical: kIsWindows ? 8 : 8.h,
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Expanded(
                  child: Text(
                    widget.message,
                    style: TextStyle(
                      fontSize: kIsWindows ? 14 : 14.sp,
                      color: widget.colorScheme.onSurface,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ),
                TextButton(
                  onPressed: () {
                    _controller.reverse().then((_) => widget.onDismissed());
                  },
                  child: Text('OK', style: TextStyle(color: widget.okColor)),
                ),
              ],
            ),
          ),
        ),
      ),
    ),
  );
}
