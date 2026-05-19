import 'package:riverpod_annotation/riverpod_annotation.dart';

import '../app_database.dart';

part 'app_database_provider.g.dart';

/// Database instance provider (Singleton)
@Riverpod(keepAlive: true)
AppDatabase appDatabase(final Ref ref) {
  final db = AppDatabase();

  ref.onDispose(db.close);

  return db;
}
