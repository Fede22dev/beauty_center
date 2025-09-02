import 'package:flex_color_scheme/flex_color_scheme.dart';
import 'package:flutter/material.dart';

class AppTheme {
  AppTheme._();

  static ThemeData get light {
    final base = FlexThemeData.light(scheme: FlexScheme.purpleM3);
    return base.copyWith(
      appBarTheme: base.appBarTheme.copyWith(elevation: 4, centerTitle: true),
      visualDensity: VisualDensity.adaptivePlatformDensity,
    );
  }

  static ThemeData get dark {
    final base = FlexThemeData.dark(scheme: FlexScheme.purpleM3);
    return base.copyWith(
      appBarTheme: base.appBarTheme.copyWith(elevation: 2, centerTitle: true),
      visualDensity: VisualDensity.adaptivePlatformDensity,
    );
  }
}
