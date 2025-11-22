import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../logging/app_logger.dart';
import '../app_database.dart';
import '../supabase_schema.dart';

/// Base repository implementing offline-first pattern with Supabase sync
abstract class BaseRepository {
  BaseRepository({
    required this.db,
    required this.supabase,
    required this.isOnline,
  });

  final AppDatabase db;
  final SupabaseClient? supabase;

  bool isOnline;

  var _isSyncing = false;

  final log = AppLogger.getLogger(name: 'BaseRepository');

  final Map<String, RealtimeChannel> _channels = {};

  /// Template method for bidirectional sync
  /// Call this when going online or after authentication
  Future<void> syncWithSupabase() async {
    if (!isOnline) return;

    if (_isSyncing) {
      log.fine('Sync already in progress. Skipping.');
      return;
    }

    _isSyncing = true;

    try {
      // 1. Push local -> Supabase (if empty)
      await pushLocalToSupabase();

      // 2. Pull Supabase (source of truth) -> local
      await pullSupabaseToLocal();

      // 3. Start realtime sync
      startRealtimeSync();

      log.info('Sync completed successfully');
    } catch (e, stackTrace) {
      log.warning('Sync failed', e, stackTrace);
    } finally {
      _isSyncing = false;
    }
  }

  /// Push local data to Supabase (only if Supabase tables are empty)
  /// Implement in subclasses
  Future<void> pushLocalToSupabase();

  /// Pull data from Supabase to local database (Supabase is source of truth)
  /// Implement in subclasses
  Future<void> pullSupabaseToLocal();

  /// Subscribe to a Supabase realtime channel
  /// Uses SupabaseTableSchema for type safety
  void subscribeToChannel({
    required final SupabaseTableSchema table,
    required final Future<void> Function(PostgresChangePayload) onEvent,
  }) {
    if (!isOnline) {
      log.fine('Cannot subscribe to ${table.channelName}: offline');
      return;
    }

    if (_channels.containsKey(table.channelName)) {
      log.fine('Channel ${table.channelName} already subscribed');
      return;
    }

    log.info('Subscribing to channel: ${table.channelName}');

    try {
      log.info('Subscribing to channel: ${table.channelName}');

      final channel = supabase!
          .channel(table.channelName)
          .onPostgresChanges(
            event: PostgresChangeEvent.all,
            schema: PostgresSchema.public,
            table: table.tableName,
            callback: onEvent,
          )
          .subscribe();

      _channels[table.channelName] = channel;
    } catch (e, stackTrace) {
      log.warning('Failed to subscribe to ${table.channelName}', e, stackTrace);
      // Remove from map if subscribe failed
      _channels.remove(table.channelName);
    }
  }

  /// Start realtime sync - implement in subclasses
  void startRealtimeSync();

  /// Stop all realtime subscriptions
  Future<void> stopRealtimeSync() async {
    if (_channels.isEmpty) return;

    log.info('Stopping ${_channels.length} realtime channels');

    await Future.wait(
      _channels.values.map((final channel) => channel.unsubscribe()),
    );
    _channels.clear();
  }

  /// Batch upsert uses SupabaseTableSchema
  /// Splits large datasets into chunks to respect Supabase limits
  Future<void> batchUpsert({
    required final SupabaseTableSchema table,
    required final List<Map<String, dynamic>> records,
    final int batchSize = 100,
  }) async {
    if (!isOnline || records.isEmpty) return;

    log.fine('Batch upserting ${records.length} records to ${table.tableName}');

    // Split into batches
    for (var i = 0; i < records.length; i += batchSize) {
      final batch = records.skip(i).take(batchSize).toList();

      try {
        await supabase!.from(table.tableName).upsert(batch);
        log.fine(
          'Upserted batch ${i ~/ batchSize + 1}/${(records.length / batchSize).ceil()}',
        );
      } catch (e, stackTrace) {
        log.warning(
          'Batch upsert failed for ${table.tableName}',
          e,
          stackTrace,
        );
        // Continue with next batch instead of failing completely
      }
    }
  }

  /// Check if Supabase table is empty (optimized query)
  Future<bool> isSupabaseTableEmpty(final SupabaseTableSchema table) async {
    if (!isOnline) return false;

    try {
      final response = await supabase!.from(table.tableName).select().limit(1);

      return response.isEmpty;
    } catch (e, stackTrace) {
      log.warning(
        'Failed to check if ${table.tableName} is empty',
        e,
        stackTrace,
      );
      return false;
    }
  }

  /// Batch delete with type-safe table
  Future<void> batchDelete({
    required final SupabaseTableSchema table,
    required final List<int> ids,
    final int batchSize = 100,
  }) async {
    if (!isOnline || ids.isEmpty) return;

    log.fine('Batch deleting ${ids.length} records from ${table.tableName}');

    // Delete in batches
    for (var i = 0; i < ids.length; i += batchSize) {
      final batch = ids.skip(i).take(batchSize).toList();

      try {
        await supabase!.from(table.tableName).delete().inFilter('id', batch);
        log.fine(
          'Deleted batch ${i ~/ batchSize + 1}/${(ids.length / batchSize).ceil()}',
        );
      } catch (e, stackTrace) {
        log.warning(
          'Batch delete failed for ${table.tableName}',
          e,
          stackTrace,
        );
      }
    }
  }

  /// Helper to execute non-blocking Supabase operations
  /// Use this for fire-and-forget sync operations
  void syncAsync(final Future<void> Function() operation) {
    if (!isOnline) return;

    operation().catchError((final Object e) {
      log.warning('Async sync operation failed', e);
    });
  }

  /// Helper to get Last Sync Time
  Future<DateTime?> getLastSyncTime(final String key) async {
    final prefs = await SharedPreferences.getInstance();
    final iso = prefs.getString(key);
    return iso != null ? DateTime.parse(iso).toUtc() : null;
  }

  /// Helper to save Last Sync Time
  Future<void> updateLastSyncTime(final String key) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(key, DateTime.now().toUtc().toIso8601String());
  }
}
