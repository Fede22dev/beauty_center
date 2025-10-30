/// This file defines all Supabase tables and columns as constants
library;

/// Postgres schema
class PostgresSchema {
  static const public = 'public';
}

/// Realtime channel names
class RealtimeChannels {
  static const cabinsChanges = 'cabins_changes';
  static const operatorsChanges = 'operators_changes';
  static const workHoursChanges = 'work_hours_changes';
}

/// Base class for all table schemas
abstract class SupabaseTableSchema {
  const SupabaseTableSchema();

  /// Table name in Supabase
  String get tableName;

  /// Realtime channel name
  String get channelName;

  @override
  String toString() => tableName;
}

// ========================================================================
// TABLE SCHEMAS
// ========================================================================

/// Cabins table schema
class SupabaseCabinsTable extends SupabaseTableSchema {
  const SupabaseCabinsTable._();

  static const instance = SupabaseCabinsTable._();

  @override
  String get tableName => 'cabins';

  @override
  String get channelName => RealtimeChannels.cabinsChanges;

  // Column names
  static const id = 'id';
  static const color = 'color';
}

/// Operators table schema
class SupabaseOperatorsTable extends SupabaseTableSchema {
  const SupabaseOperatorsTable._();

  static const instance = SupabaseOperatorsTable._();

  @override
  String get tableName => 'operators';

  @override
  String get channelName => RealtimeChannels.operatorsChanges;

  // Column names
  static const id = 'id';
  static const name = 'name';
}

/// Work hours table schema
class SupabaseWorkHoursTable extends SupabaseTableSchema {
  const SupabaseWorkHoursTable._();

  static const instance = SupabaseWorkHoursTable._();

  @override
  String get tableName => 'work_hours';

  @override
  String get channelName => RealtimeChannels.workHoursChanges;

  // Column names
  static const id = 'id';
  static const startHr = 'start_hr';
  static const startMin = 'start_min';
  static const endHr = 'end_hr';
  static const endMin = 'end_min';
}

// ========================================================================
// USAGE HELPERS
// ========================================================================

/// Helper class to access all table schemas
/// Usage: SupabaseSchema.cabins.tableName
abstract class SupabaseSchema {
  static const cabins = SupabaseCabinsTable.instance;
  static const operators = SupabaseOperatorsTable.instance;
  static const workHours = SupabaseWorkHoursTable.instance;
}
