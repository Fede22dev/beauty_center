import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';

import '../constants/app_constants.dart';

class SectionCard extends StatelessWidget {
  const SectionCard({required this.child, super.key});

  final Widget child;

  @override
  Widget build(final BuildContext context) => Card(
    color: Theme.of(context).colorScheme.surfaceContainerHigh,
    elevation: 2,
    shape: RoundedRectangleBorder(
      borderRadius: BorderRadius.circular(kIsWindows ? 16 : 16.r),
    ),
    child: Padding(
      padding: EdgeInsets.all(kIsWindows ? 20 : 20.w),
      child: child,
    ),
  );
}
