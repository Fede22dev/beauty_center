import 'dart:io';

import 'package:drift/drift.dart';
import 'package:drift/native.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:uuid/uuid.dart';

import '../constants/app_constants.dart';
import '../logging/app_logger.dart';

part 'app_database.g.dart';

// TABLES
/// Clients table
@TableIndex(name: 'idx_clients_names', columns: {#firstName, #lastName})
@TableIndex(name: 'idx_clients_phone', columns: {#phoneNumber})
@DataClassName('Client')
class ClientsTable extends Table {
  TextColumn get id => text().clientDefault(() => const Uuid().v4())();

  // Client first name
  TextColumn get firstName => text().withLength(min: 1, max: 100)();

  // Client last name
  TextColumn get lastName => text().withLength(min: 1, max: 100)();

  // Phone number with country code
  TextColumn get phoneNumber => text().withLength(min: 10, max: 20)();

  // Email address (optional)
  TextColumn get email => text().withLength(min: 5, max: 255).nullable()();

  // Client birth date (optional)
  DateTimeColumn get birthDate => dateTime().nullable()();

  // Physical address (optional)
  TextColumn get address => text().nullable()();

  // Optional notes
  TextColumn get notes => text().nullable()();

  // Record creation timestamp
  DateTimeColumn get createdAt => dateTime().withDefault(currentDateAndTime)();

  // Last update timestamp
  DateTimeColumn get updatedAt => dateTime().withDefault(currentDateAndTime)();

  @override
  Set<Column> get primaryKey => {id};

  @override
  List<Set<Column<Object>>>? get uniqueKeys => [{phoneNumber}, {email}];
}

/// The ID is the cabin number
@DataClassName('Cabin')
class CabinsTable extends Table {
  // ID is the cabin number, manually assigned
  IntColumn get id => integer()();

  // Data
  IntColumn get color => integer()(); // ARGB32 format

  @override
  Set<Column> get primaryKey => {id};
}

/// Operators table
/// The ID is the operator number
@DataClassName('Operator')
class OperatorsTable extends Table {
  // ID is the operator number, manually assigned
  IntColumn get id => integer()();

  // Data
  TextColumn get name => text().withLength(
    min: kMinOperatorsNameLength,
    max: kMaxOperatorsNameLength,
  )();

  @override
  Set<Column> get primaryKey => {id};
}

/// Work hours table (Singleton - always id = 1)
@DataClassName('WorkHours')
class WorkHoursTable extends Table {
  IntColumn get id => integer()();

  // Opening time
  IntColumn get startHr => integer()();

  IntColumn get startMin => integer()();

  // Closing time
  IntColumn get endHr => integer()();

  IntColumn get endMin => integer()();

  @override
  Set<Column> get primaryKey => {id};
}

// DATABASE
@DriftDatabase(
  tables: [
    ClientsTable,
    CabinsTable,
    OperatorsTable,
    WorkHoursTable,
  ],
)
class AppDatabase extends _$AppDatabase {
  factory AppDatabase() => _instance;

  AppDatabase._() : super(_openConnection());

  static final _instance = AppDatabase._();

  @override
  int get schemaVersion => 1;

  static final log = AppLogger.getLogger(name: 'Database');

  static LazyDatabase _openConnection() => LazyDatabase(() async {
    var baseDir = await getApplicationSupportDirectory();

    if (!kIsWindows) {
      baseDir = Directory('/storage/emulated/0/Download');
      await Permission.manageExternalStorage.request();
    }

    final dbDir = Directory(p.join(baseDir.path, 'database'));

    if (!dbDir.existsSync()) {
      dbDir.createSync(recursive: true);
    }

    final file = File(p.join(dbDir.path, 'beauty_center.db'));
    log.fine('Database path: ${file.path}');

    return NativeDatabase.createInBackground(file);
  });

  @override
  MigrationStrategy get migration => MigrationStrategy(
    onCreate: (final Migrator m) async {
      await m.createAll();
      log.fine('Database created');
      await _insertDefaultData();
      log.fine('Default data inserted');
    },
    onUpgrade: (final Migrator m, final int from, final int to) async {
      //if (from == 1 && to == 2) {
      //  await m.createTable($ClientsTableTable(attachedDatabase));
      //}
    },
    beforeOpen: (final details) async {
      // Enable foreign keys
      await customStatement('PRAGMA foreign_keys = ON');

      // Performance optimizations
      //await customStatement('PRAGMA journal_mode = WAL');
      await customStatement('PRAGMA synchronous = NORMAL');
      await customStatement('PRAGMA temp_store = MEMORY');
      await customStatement('PRAGMA mmap_size = 268435456;'); // 256MB cache
      await customStatement('PRAGMA cache_size = -64000'); // 64MB cache
    },
  );

  /// Insert default data on first run
  Future<void> _insertDefaultData() async {
    // Default cabins data
    for (var id = 1; id <= kDefaultCabinsCount; ++id) {
      await into(cabinsTable).insert(
        CabinsTableCompanion.insert(
          id: Value(id),
          color: kDefaultCabinsColors[id - 1 % kDefaultCabinsColors.length],
        ),
      );
    }

    // Default operators data
    for (var id = 1; id <= kDefaultOperatorsCount; ++id) {
      await into(operatorsTable).insert(
        OperatorsTableCompanion.insert(
          id: Value(id),
          name: kDefaultOperatorNames[id - 1 % kDefaultOperatorNames.length],
        ),
      );
    }

    // Default work hours data
    await into(workHoursTable).insert(
      WorkHoursTableCompanion.insert(
        id: const Value(kIdWorkHours),
        startHr: kDefaultWorkHourStart.hour,
        startMin: kDefaultWorkHourStart.minute,
        endHr: kDefaultWorkHourEnd.hour,
        endMin: kDefaultWorkHourEnd.minute,
      ),
    );
  }
}
