import 'dart:math';

import 'package:flutter/material.dart';

import '../../../core/constants/app_constants.dart';

class AnimatedRotationIcon extends StatelessWidget {
  const AnimatedRotationIcon({
    required this.icon,
    required this.color,
    required this.isSelected,
    required this.size,
    super.key,
  });

  final IconData icon;
  final Color color;
  final bool isSelected;
  final double size;

  @override
  Widget build(final BuildContext context) => TweenAnimationBuilder<double>(
    tween: Tween<double>(begin: 0, end: isSelected ? 1 : 0),
    duration: Duration(
      milliseconds: (kDefaultAppAnimationsDuration.inMilliseconds * 1.5)
          .round(),
    ),
    curve: Curves.easeInOutCubic,
    builder: (final context, final value, _) => Transform.rotate(
      angle: isSelected ? value * 2 * pi : 0,
      child: Icon(
        icon,
        color: color,
        size: size,
        weight: 400 + (300 * value),
        fill: value,
      ),
    ),
  );
}
