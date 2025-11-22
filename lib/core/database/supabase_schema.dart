/// This file defines all Supabase tables and columns as constants
library;

/// Postgres schema
class PostgresSchema {
  static const public = 'public';
}

/// Realtime channel names
class RealtimeChannels {
  static const clientsChanges = 'clients_changes';
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

/// Clients table schema
class SupabaseClientsTable extends SupabaseTableSchema {
  const SupabaseClientsTable._();

  static const instance = SupabaseClientsTable._();

  @override
  String get tableName => 'clients';

  @override
  String get channelName => RealtimeChannels.clientsChanges;

  // Column names
  static const id = 'id';
  static const firstName = 'first_name';
  static const lastName = 'last_name';
  static const phoneNumber = 'phone_number';
  static const email = 'email';
  static const birthDate = 'birth_date';
  static const address = 'address';
  static const notes = 'notes';
  static const createdAt = 'created_at';
  static const updatedAt = 'updated_at';
}

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
  static const clients = SupabaseClientsTable.instance;
  static const cabins = SupabaseCabinsTable.instance;
  static const operators = SupabaseOperatorsTable.instance;
  static const workHours = SupabaseWorkHoursTable.instance;
}
