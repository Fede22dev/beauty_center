import 'dart:async';

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

  final _log = AppLogger.getLogger(name: 'BaseRepository');

  final Map<String, RealtimeChannel> _channels = {};

  /// Tracks pending sync operations to prevent race conditions
  final Map<String, Future<void>> _pendingOperations = {};

  /// Template method for sync supabase to local
  /// Call this when going online or after authentication
  Future<void> syncWithSupabase() async {
    if (!isOnline) return;

    if (_isSyncing) {
      _log.finest('Sync already in progress. Skipping.');
      return;
    }

    _isSyncing = true;

    try {
      // 1. Pull Supabase (source of truth) -> local
      await pullSupabaseToLocal();

      // 2. Start realtime sync
      startRealtimeSync();

      _log.info('Sync completed successfully');
    } catch (e, stackTrace) {
      _log.warning('Sync failed', e, stackTrace);
    } finally {
      _isSyncing = false;
    }
  }

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
      _log.finest('Cannot subscribe to ${table.channelName}: offline');
      return;
    }

    if (_channels.containsKey(table.channelName)) {
      _log.finest('Channel ${table.channelName} already subscribed');
      return;
    }

    try {
      _log.info('Subscribing to channel: ${table.channelName}');

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
      _log.warning(
        'Failed to subscribe to ${table.channelName}',
        e,
        stackTrace,
      );
      // Remove from map if subscribe failed
      _channels.remove(table.channelName);
    }
  }

  /// Start realtime sync - implement in subclasses
  void startRealtimeSync();

  /// Stop all realtime subscriptions
  Future<void> stopRealtimeSync() async {
    if (_channels.isEmpty) return;

    _log.info('Stopping ${_channels.length} realtime channels');

    await Future.wait(
      _channels.values.map((final channel) => channel.unsubscribe()),
    );
    _channels.clear();
  }

  /// Helper to execute non-blocking Supabase operations
  /// Use this for fire-and-forget sync operations
  /// Prevents race conditions by tracking pending operations
  Future<void> syncAsync(
    final String operationId,
    final Future<void> Function() operation, {
    int maxRetries = 3,
  }) async {
    if (!isOnline) return;

    // Skip if same operation is already in progress
    if (_pendingOperations.containsKey(operationId)) {
      _log.finest('Operation $operationId already in progress, skipping');
      return;
    }

    final future = _executeWithRetry(operation, maxRetries, 1);
    _pendingOperations[operationId] = future;

    try {
      await future;
    } finally {
      _pendingOperations.remove(operationId);
    }
  }

  Future<void> _executeWithRetry(
    Future<void> Function() operation,
    int remaining,
    int attempt,
  ) async {
    try {
      await operation();
    } catch (e) {
      if (remaining > 1) {
        _log.warning(
          'Async sync operation failed, retrying (attempt $attempt)',
          e,
        );
        await Future<void>.delayed(Duration(seconds: attempt * 2));
        return _executeWithRetry(operation, remaining - 1, attempt + 1);
      }
      _log.warning('Async sync operation failed after $attempt attempts', e);
    }
  }

  /// Check if an operation is currently pending
  bool isOperationPending(String operationId) =>
      _pendingOperations.containsKey(operationId);

  /// Helper to get Last Sync Time
  Future<DateTime?> getLastSyncTime(final String key) async {
    final prefs = await SharedPreferences.getInstance();
    final lastSyncTime = prefs.getString(key);
    return lastSyncTime != null ? DateTime.parse(lastSyncTime).toUtc() : null;
  }

  /// Helper to save Last Sync Time
  Future<void> updateLastSyncTime(final String key) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(key, DateTime.now().toUtc().toIso8601String());
  }
}
