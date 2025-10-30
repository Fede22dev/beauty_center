import 'dart:io';
import 'dart:math';

import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';

bool get kIsWindows => Platform.isWindows;

const kDefaultAppAnimationsDuration = Duration(milliseconds: 350);

final kDefaultAppBannerOfflineHeight = kIsWindows ? 42.0 : 32.h;

int _randomInRange(final int min, final int max) =>
    min + Random().nextInt(max - min + 1);

// Default colors for cabins
const kDefaultCabinsColors = [
  0xFFFF4081, // Hot Pink
  0xFF2979FF, // Vivid Blue
  0xFF00E676, // Bright Green
  0xFFFF9100, // Vibrant Orange
  0xFFAA00FF, // Electric Purple
  0xFFFFEA00, // Lemon Yellow
  0xFF00BFA5, // Teal
  0xFFFF5252, // Red Accent
  0xFF536DFE, // Indigo Accent
  0xFF00C853, // Emerald Green
  0xFFFF6D00, // Deep Orange Accent
  0xFFD500F9, // Magenta
  0xFF64DD17, // Lime Green
  0xFF18FFFF, // Cyan Bright
  0xFFFFD600, // Amber Accent
];

const kMinCabinsCount = 1;
final kMaxCabinsCount = kDefaultCabinsColors.length;
final kDefaultCabinsCount = _randomInRange(kMinCabinsCount, kMaxCabinsCount);

// Default operators names
const kMinOperatorsNameLength = 1;
const kMaxOperatorsNameLength = 20;

const kDefaultOperatorNames = [
  'Emma',
  'Sara',
  'Luca',
  'Olivia',
  'Mia',
  'Leo',
  'Noah',
  'Eva',
  'Ada',
  'Eli',
];

const kMinOperatorsCount = 1;
final kMaxOperatorsCount = kDefaultOperatorNames.length;
final kDefaultOperatorsCount = _randomInRange(
  kMinOperatorsCount,
  kMaxOperatorsCount,
);

const kIdWorkHours = 1;
const kDefaultWorkHourStart = TimeOfDay(hour: 9, minute: 0);
const kDefaultWorkHourEnd = TimeOfDay(hour: 18, minute: 0);

const kSupabaseUrlKeySecureStorageKey = 'supabase_url';
const kSupabaseAnonKeySecureStorageKey = 'supabase_anonkey';
