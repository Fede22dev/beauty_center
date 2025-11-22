// ========================================================================
// CORE PROVIDERS
// ========================================================================

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../app_database.dart';

/// Database instance provider (Singleton)
final appDatabaseProvider = Provider<AppDatabase>((final ref) {
  final db = AppDatabase();
  ref.onDispose(db.close);
  return db;
});
