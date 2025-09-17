import 'dart:math';

import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:material_symbols_icons/symbols.dart';

import '../../../../../core/constants/app_constants.dart';

class ToggleButton extends StatefulWidget {
  const ToggleButton({
    required this.isExtended,
    required this.onToggle,
    super.key,
  });

  final bool isExtended;
  final VoidCallback onToggle;

  @override
  State<ToggleButton> createState() => _ToggleButtonState();
}

class _ToggleButtonState extends State<ToggleButton> {
  var _isHovered = false;

  @override
  Widget build(final BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return TweenAnimationBuilder<double>(
      tween: Tween<double>(begin: 0, end: widget.isExtended ? 1 : 0),
      duration: kDefaultAppAnimationsDuration,
      curve: Curves.easeInOutCubic,
      builder: (final context, final value, final child) => MouseRegion(
        cursor: SystemMouseCursors.click,
        onEnter: (_) => setState(() => _isHovered = true),
        onExit: (_) => setState(() => _isHovered = false),
        child: GestureDetector(
          onTap: widget.onToggle,
          behavior: HitTestBehavior.opaque,
          child: SizedBox(
            width: 1.sw,
            child: Transform.rotate(
              angle: value * pi,
              child: Icon(
                Symbols.chevron_right_rounded,
                color: _isHovered
                    ? colorScheme.primary
                    : colorScheme.onSurfaceVariant.withValues(alpha: 0.8),
                size: 18.sp,
                weight: 500,
              ),
            ),
          ),
        ),
      ),
    );
  }
}
