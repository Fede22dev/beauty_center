import 'package:drift/drift.dart';
import 'package:flutter/material.dart' as material show Color, TimeOfDay;

import '../../../../core/constants/app_constants.dart';
import '../../../../core/database/app_database.dart';

class SettingsRepository {
  SettingsRepository(this._db);

  final AppDatabase _db;

  // ========================================================================
  /// Validate cabin ID
  void _validateCabinId(final int id) {
    if (id < kMinCabinsCount || id > kMaxCabinsCount) {
      throw ArgumentError(
        'Cabin ID must be between $kMinCabinsCount and '
        '$kMaxCabinsCount, got $id',
      );
    }
  }

  /// Validate cabins count
  void _validateCabinsCount(final int count) {
    if (count < kMinCabinsCount || count > kMaxCabinsCount) {
      throw ArgumentError(
        'Cabins count must be between $kMinCabinsCount and '
        '$kMaxCabinsCount, got $count',
      );
    }
  }

  // CABINS - QUERIES
  /// Get all cabins ordered by ID
  Future<List<Cabin>> getAllCabins() => (_db.select(
    _db.cabinsTable,
  )..orderBy([(final t) => OrderingTerm.asc(t.id)])).get();

  /// Watch cabins stream
  Stream<List<Cabin>> watchCabins() => (_db.select(
    _db.cabinsTable,
  )..orderBy([(final t) => OrderingTerm.asc(t.id)])).watch();

  /// Get cabin by ID
  Future<Cabin?> getCabinById(final int id) {
    _validateCabinId(id);

    return (_db.select(
      _db.cabinsTable,
    )..where((final t) => t.id.equals(id))).getSingleOrNull();
  }

  /// Get cabins count
  Future<int> getCabinsCount() async {
    final cabins = await getAllCabins();
    return cabins.length;
  }

  // CABINS - CRUD
  /// Add new cabin
  Future<int> addCabin({
    required final int id,
    required final material.Color color,
  }) {
    _validateCabinId(id);

    return _db
        .into(_db.cabinsTable)
        .insert(
          CabinsTableCompanion.insert(id: Value(id), color: color.toARGB32()),
        );
  }

  /// Update cabin color
  Future<void> updateCabinColor({
    required final int id,
    required final material.Color color,
  }) async {
    _validateCabinId(id);

    await (_db.update(_db.cabinsTable)..where((final t) => t.id.equals(id)))
        .write(CabinsTableCompanion(color: Value(color.toARGB32())));
  }

  /// Delete cabin
  Future<void> deleteCabin(final int id) async {
    _validateCabinId(id);

    await (_db.delete(
      _db.cabinsTable,
    )..where((final t) => t.id.equals(id))).go();
  }

  /// Set cabins count (add or remove to match target)
  Future<void> setCabinsCount(final int targetCount) async {
    _validateCabinsCount(targetCount);

    final currentCabins = await getAllCabins();
    final currentCount = currentCabins.length;

    if (targetCount > currentCount) {
      // Add default cabins
      for (var newId = currentCount + 1; newId <= targetCount; newId++) {
        await addCabin(
          id: newId,
          color: material.Color(
            kDefaultCabinsColors[newId - 1 % kDefaultCabinsColors.length],
          ),
        );
      }
    } else if (targetCount < currentCount) {
      // Remove cabins from the end (highest IDs first)
      for (final cabin in currentCabins.skip(targetCount)) {
        await deleteCabin(cabin.id);
      }
    }
  }

  // ========================================================================

  /// Validate operator ID
  void _validateOperatorId(final int id) {
    if (id < kMinOperatorsCount || id > kMaxOperatorsCount) {
      throw ArgumentError(
        'Operator ID must be between $kMinOperatorsCount and '
        '$kMaxOperatorsCount, got $id',
      );
    }
  }

  /// Validate operators count
  void _validateOperatorsCount(final int count) {
    if (count < kMinOperatorsCount || count > kMaxOperatorsCount) {
      throw ArgumentError(
        'Operators count must be between $kMinOperatorsCount and '
        '$kMaxOperatorsCount, got $count',
      );
    }
  }

  // OPERATORS - QUERIES
  /// Get all operators ordered by ID
  Future<List<Operator>> getAllOperators() => (_db.select(
    _db.operatorsTable,
  )..orderBy([(final t) => OrderingTerm.asc(t.id)])).get();

  /// Watch operators stream
  Stream<List<Operator>> watchOperators() => (_db.select(
    _db.operatorsTable,
  )..orderBy([(final t) => OrderingTerm.asc(t.id)])).watch();

  /// Get operator by ID
  Future<Operator?> getOperatorById(final int id) {
    _validateOperatorId(id);

    return (_db.select(
      _db.operatorsTable,
    )..where((final t) => t.id.equals(id))).getSingleOrNull();
  }

  /// Get operators count
  Future<int> getOperatorsCount() async {
    final operators = await getAllOperators();
    return operators.length;
  }

  // OPERATORS - CRUD
  /// Add new operator
  Future<int> addOperator({required final int id, required final String name}) {
    _validateOperatorId(id);
    if (name.trim().isEmpty) return Future.value(0);

    return _db
        .into(_db.operatorsTable)
        .insert(OperatorsTableCompanion.insert(id: Value(id), name: name));
  }

  /// Update operator name
  Future<void> updateOperatorName({
    required final int id,
    required final String name,
  }) async {
    _validateOperatorId(id);
    if (name.trim().isEmpty) return;

    await (_db.update(_db.operatorsTable)..where((final t) => t.id.equals(id)))
        .write(OperatorsTableCompanion(name: Value(name)));
  }

  /// Delete operator
  Future<void> deleteOperator(final int id) async {
    _validateOperatorId(id);

    await (_db.delete(
      _db.operatorsTable,
    )..where((final t) => t.id.equals(id))).go();
  }

  /// Set operators count (add or remove to match target)
  Future<void> setOperatorsCount(final int targetCount) async {
    _validateOperatorsCount(targetCount);

    final currentOperators = await getAllOperators();
    final currentCount = currentOperators.length;

    if (targetCount > currentCount) {
      // Add default operators
      for (var newId = currentCount + 1; newId <= targetCount; newId++) {
        await addOperator(
          id: newId,
          name: kDefaultOperatorNames[newId - 1 % kDefaultOperatorNames.length],
        );
      }
    } else if (targetCount < currentCount) {
      // Remove operators from the end (highest IDs first)
      for (final operator in currentOperators.skip(targetCount)) {
        await deleteOperator(operator.id);
      }
    }
  }

  // ========================================================================

  // WORK HOURS

  /// Get work hours (singleton)
  Future<WorkHours> getWorkHours() => (_db.select(
    _db.workHoursTable,
  )..where((final t) => t.id.equals(kIdWorkHours))).getSingle();

  /// Watch work hours stream
  Stream<WorkHours> watchWorkHours() => (_db.select(
    _db.workHoursTable,
  )..where((final t) => t.id.equals(kIdWorkHours))).watchSingle();

  /// Update work hours
  Future<void> updateWorkHours({
    required final material.TimeOfDay startTime,
    required final material.TimeOfDay endTime,
  }) async {
    await (_db.update(
      _db.workHoursTable,
    )..where((final t) => t.id.equals(kIdWorkHours))).write(
      WorkHoursTableCompanion(
        startHr: Value(startTime.hour),
        startMin: Value(startTime.minute),
        endHr: Value(endTime.hour),
        endMin: Value(endTime.minute),
      ),
    );
  }
}
