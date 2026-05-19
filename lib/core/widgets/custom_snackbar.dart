import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:material_symbols_icons/material_symbols_icons.dart';

import '../constants/app_constants.dart';
import '../logging/app_logger.dart';
import '../utils/navigator_key.dart';

// Singleton-like reference to remove the previous snackbar immediately
OverlayEntry? _currentOverlay;
bool _isRemoving = false;

enum SnackBarType { success, error, info, warning }

/// Usa questa funzione quando non hai un BuildContext diretto (es. errori globali)
void showGlobalCustomSnackBar({
  required String message,
  final SnackBarType type = SnackBarType.info,
  final Color? okColor,
}) {
  final context = navigatorKey.currentContext;
  if (context != null) {
    showCustomSnackBar(
      context: context,
      message: message,
      type: type,
      okColor: okColor,
    );
  } else {
    AppLogger.talker.warning(
      'Impossibile mostrare SnackBar: Context nullo. Errore: $message',
    );
  }
}

void showCustomSnackBar({
  required final BuildContext context,
  required final String message,
  final SnackBarType type = SnackBarType.info,
  final Color? okColor,
}) {
  // Prevent double-removal race condition
  if (_currentOverlay != null && !_isRemoving) {
    _isRemoving = true;
    _currentOverlay?.remove();
    _currentOverlay = null;
    _isRemoving = false;
  }

  var overlayState = Overlay.maybeOf(context);

  if (overlayState == null) {
    try {
      overlayState = Navigator.maybeOf(context)?.overlay;
    } catch (_) {}
  }

  if (overlayState == null) {
    throw Exception('No Overlay found for CustomSnackBar');
  }

  final theme = Theme.of(context);
  final colorScheme = theme.colorScheme;
  final isDark = theme.brightness == Brightness.dark;

  Color typeColor;
  IconData icon;

  switch (type) {
    case SnackBarType.success:
      typeColor = Colors.green.shade600;
      icon = Symbols.check_circle_rounded;
    case SnackBarType.error:
      typeColor = colorScheme.error;
      icon = Symbols.error_rounded;
    case SnackBarType.warning:
      typeColor = Colors.orange.shade700;
      icon = Symbols.warning_rounded;
    case SnackBarType.info:
      typeColor = okColor ?? colorScheme.primary;
      icon = Symbols.info_rounded;
  }

  final overlayEntry = OverlayEntry(
    builder: (final ctx) => _ToastWidget(
      message: message,
      typeColor: typeColor,
      icon: icon,
      isDark: isDark,
      colorScheme: colorScheme,
      onDismissed: () {
        // Prevent double-removal when overlay was already replaced
        if (_currentOverlay != null && !_isRemoving) {
          _isRemoving = true;
          _currentOverlay?.remove();
          _currentOverlay = null;
          _isRemoving = false;
        }
      },
    ),
  );

  WidgetsBinding.instance.addPostFrameCallback((_) {
    overlayState?.insert(overlayEntry);
    HapticFeedback.lightImpact();
  });
  _currentOverlay = overlayEntry;
}

class _ToastWidget extends StatefulWidget {
  const _ToastWidget({
    required this.message,
    required this.typeColor,
    required this.icon,
    required this.isDark,
    required this.colorScheme,
    required this.onDismissed,
  });

  final String message;
  final Color typeColor;
  final IconData icon;
  final bool isDark;
  final ColorScheme colorScheme;
  final VoidCallback onDismissed;

  @override
  State<_ToastWidget> createState() => _ToastWidgetState();
}

class _ToastWidgetState extends State<_ToastWidget>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<Offset> _offsetAnimation;
  late Animation<double> _fadeAnimation;

  Timer? _autoDismissTimer;
  var _isInteracting = false;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 400),
      reverseDuration: const Duration(milliseconds: 300),
    );

    _offsetAnimation =
        Tween<Offset>(begin: const Offset(0, 1.5), end: Offset.zero).animate(
          CurvedAnimation(
            parent: _controller,
            curve: Curves.easeOutBack,
            reverseCurve: Curves.easeInCubic,
          ),
        );

    _fadeAnimation = CurvedAnimation(parent: _controller, curve: Curves.easeIn);

    _controller.forward();
    _scheduleAutoDismiss();
  }

  void _scheduleAutoDismiss() {
    _autoDismissTimer?.cancel();
    _autoDismissTimer = Timer(const Duration(seconds: 4), () {
      if (mounted && !_isInteracting) {
        _dismiss();
      }
    });
  }

  Future<void> _dismiss() async {
    if (!mounted) return;
    await _controller.reverse();
    widget.onDismissed();
  }

  @override
  void dispose() {
    _autoDismissTimer?.cancel();
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(final BuildContext context) {
    // Responsive dimensions
    final bottomPadding = MediaQuery.of(context).padding.bottom;

    return Positioned(
      bottom: bottomPadding + (kIsWindows ? 24 : 80.h),
      left: kIsWindows ? 0 : 16.w,
      right: kIsWindows ? 0 : 16.w,
      child: Center(
        child: ConstrainedBox(
          constraints: BoxConstraints(maxWidth: 0.9.sw),
          child: Dismissible(
            key: const ValueKey('custom_snackbar'),
            onDismissed: (final direction) => widget.onDismissed(),
            child: SlideTransition(
              position: _offsetAnimation,
              child: FadeTransition(
                opacity: _fadeAnimation,
                child: GestureDetector(
                  onTapDown: (final _) {
                    setState(() => _isInteracting = true);
                    _autoDismissTimer?.cancel();
                  },
                  onTapUp: (final _) {
                    setState(() => _isInteracting = false);
                    _scheduleAutoDismiss();
                  },
                  child: Material(
                    color: Colors.transparent,
                    child: Container(
                      margin: EdgeInsets.symmetric(
                        horizontal: kIsWindows ? 0 : 4.w,
                      ),
                      padding: EdgeInsets.symmetric(
                        horizontal: kIsWindows ? 16 : 16.w,
                        vertical: kIsWindows ? 12 : 12.h,
                      ),
                      decoration: BoxDecoration(
                        color: widget.isDark
                            ? const Color(0xFF303030).withValues(alpha: 0.95)
                            : Colors.white.withValues(alpha: 0.95),
                        borderRadius: BorderRadius.circular(
                          kIsWindows ? 16 : 16.r,
                        ),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withValues(alpha: 0.15),
                            blurRadius: 20,
                            offset: const Offset(0, 8),
                          ),
                        ],
                        border: Border.all(
                          color: widget.isDark
                              ? Colors.white.withValues(alpha: 0.1)
                              : Colors.black.withValues(alpha: 0.05),
                        ),
                      ),
                      child: Row(
                        children: [
                          Container(
                            padding: EdgeInsets.all(kIsWindows ? 8 : 8.w),
                            decoration: BoxDecoration(
                              color: widget.typeColor.withValues(alpha: 0.1),
                              shape: BoxShape.circle,
                            ),
                            child: Icon(
                              widget.icon,
                              color: widget.typeColor,
                              size: kIsWindows ? 24 : 24.sp,
                            ),
                          ),
                          SizedBox(width: kIsWindows ? 12 : 12.w),

                          Expanded(
                            child: Text(
                              widget.message,
                              style: TextStyle(
                                color: widget.colorScheme.onSurface,
                                fontSize: kIsWindows ? 14 : 14.sp,
                                fontWeight: FontWeight.w500,
                                height: 1.4,
                              ),
                              maxLines: 3,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),

                          if (!kIsWindows) ...[
                            SizedBox(width: kIsWindows ? 8 : 8.w),
                            IconButton(
                              onPressed: _dismiss,
                              icon: Icon(
                                Symbols.close_rounded,
                                size: kIsWindows ? 20 : 20.sp,
                                color: widget.colorScheme.onSurfaceVariant,
                              ),
                              padding: EdgeInsets.zero,
                              constraints: const BoxConstraints(),
                              style: const ButtonStyle(
                                tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                              ),
                            ),
                          ],
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
