import 'package:flutter/material.dart' as material show Color, TimeOfDay;

import '../app_database.dart';

// EXTENSIONS (models helpers)
extension CabinExtension on Cabin {
  String get displayNumber => id.toString();

  material.Color get colorValue => material.Color(color);
}

extension OperatorExtension on Operator {
  String get displayNumber => id.toString();
}

extension WorkHoursExtension on WorkHours {
  material.TimeOfDay get startTime =>
      material.TimeOfDay(hour: startHr, minute: startMin);

  material.TimeOfDay get endTime =>
      material.TimeOfDay(hour: endHr, minute: endMin);

  int get workDayMinutes {
    final start = startHr * 60 + startMin;
    final end = endHr * 60 + endMin;
    return end - start;
  }

  bool get needsSync => lastSyncedAt == null || updatedAt > lastSyncedAt!;
}
