import 'package:flutter/foundation.dart';

const kDefaultAppAnimationsDuration = Duration(milliseconds: 350);

bool get kTargetOsIsDesktop =>
    kIsWeb ||
    defaultTargetPlatform == TargetPlatform.windows ||
    defaultTargetPlatform == TargetPlatform.linux ||
    defaultTargetPlatform == TargetPlatform.macOS;
