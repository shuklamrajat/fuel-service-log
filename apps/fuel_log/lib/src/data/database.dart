import 'package:drift/drift.dart';

part 'database.g.dart';

class Vehicles extends Table {
  IntColumn get id => integer().autoIncrement()();
  TextColumn get name => text().withLength(min: 1, max: 60)();
  TextColumn get details => text().withDefault(const Constant(''))();
  BoolColumn get archived => boolean().withDefault(const Constant(false))();
}

/// Distances in metres, volumes in millilitres, money in cents. Display
/// units are a setting and never change what is stored.
class FillUps extends Table {
  IntColumn get id => integer().autoIncrement()();
  IntColumn get vehicleId => integer().references(Vehicles, #id)();
  DateTimeColumn get date => dateTime()();
  IntColumn get odometerM => integer()();
  IntColumn get volumeMl => integer()();
  IntColumn get costCents => integer()();
  BoolColumn get isFull => boolean().withDefault(const Constant(true))();
  BoolColumn get missedPrevious => boolean().withDefault(const Constant(false))();
  TextColumn get note => text().withDefault(const Constant(''))();
}

class Services extends Table {
  IntColumn get id => integer().autoIncrement()();
  IntColumn get vehicleId => integer().references(Vehicles, #id)();
  DateTimeColumn get date => dateTime()();
  IntColumn get odometerM => integer().nullable()();
  TextColumn get title => text().withLength(min: 1, max: 80)();
  IntColumn get costCents => integer().withDefault(const Constant(0))();
  TextColumn get note => text().withDefault(const Constant(''))();
}

class Reminders extends Table {
  IntColumn get id => integer().autoIncrement()();
  IntColumn get vehicleId => integer().references(Vehicles, #id)();
  TextColumn get title => text().withLength(min: 1, max: 80)();
  IntColumn get intervalDays => integer().nullable()();
  IntColumn get intervalM => integer().nullable()();
  DateTimeColumn get lastDoneDate => dateTime()();
  IntColumn get lastDoneOdometerM => integer().nullable()();
}

@DriftDatabase(tables: [Vehicles, FillUps, Services, Reminders])
class FuelDb extends _$FuelDb {
  FuelDb(super.e);

  @override
  int get schemaVersion => 1;

  @override
  MigrationStrategy get migration =>
      MigrationStrategy(beforeOpen: (details) async => customStatement('PRAGMA foreign_keys = ON'));
}
