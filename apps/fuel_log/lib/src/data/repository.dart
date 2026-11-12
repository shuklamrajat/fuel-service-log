import 'package:app_core/app_core.dart';
import 'package:drift/drift.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../domain/engine.dart';
import 'database.dart';

export 'database.dart';

final fuelDbProvider = Provider<FuelDb>((ref) {
  final db = FuelDb(openAppDatabase('fuel'));
  ref.onDispose(db.close);
  return db;
});

final repositoryProvider = Provider<FuelRepository>((ref) => FuelRepository(ref.watch(fuelDbProvider)));

class SaveResult {
  const SaveResult.ok(this.id) : error = null;
  const SaveResult.error(this.error) : id = null;
  final int? id;
  final String? error;
  bool get ok => error == null;
}

DateTime dayOf(DateTime d) => DateTime(d.year, d.month, d.day);

class FuelRepository {
  FuelRepository(this.db);
  final FuelDb db;

  Stream<List<Vehicle>> watchVehicles() =>
      (db.select(db.vehicles)
            ..where((v) => v.archived.equals(false))
            ..orderBy([(v) => OrderingTerm(expression: v.id)]))
          .watch();

  Future<int> saveVehicle(VehiclesCompanion c) async {
    if (c.id.present) {
      await (db.update(db.vehicles)..where((v) => v.id.equals(c.id.value))).write(c);
      return c.id.value;
    }
    return db.into(db.vehicles).insert(c);
  }

  Stream<List<FillUp>> watchFills(int vehicleId) =>
      (db.select(db.fillUps)
            ..where((f) => f.vehicleId.equals(vehicleId))
            ..orderBy([(f) => OrderingTerm(expression: f.odometerM, mode: OrderingMode.desc)]))
          .watch();

  Stream<List<Service>> watchServices(int vehicleId) =>
      (db.select(db.services)
            ..where((s) => s.vehicleId.equals(vehicleId))
            ..orderBy([(s) => OrderingTerm(expression: s.date, mode: OrderingMode.desc)]))
          .watch();

  Stream<List<Reminder>> watchReminders(int vehicleId) =>
      (db.select(db.reminders)
            ..where((r) => r.vehicleId.equals(vehicleId))
            ..orderBy([(r) => OrderingTerm(expression: r.id)]))
          .watch();

  Future<List<OdoReading>> _readings(int vehicleId) async {
    final fills = await (db.select(db.fillUps)..where((f) => f.vehicleId.equals(vehicleId))).get();
    final svcs = await (db.select(
      db.services,
    )..where((s) => s.vehicleId.equals(vehicleId) & s.odometerM.isNotNull())).get();
    return [
      for (final f in fills) (id: 'f${f.id}', date: f.date, odometerM: f.odometerM),
      for (final s in svcs) (id: 's${s.id}', date: s.date, odometerM: s.odometerM!),
    ];
  }

  Future<SaveResult> saveFill(FillUpsCompanion c) async {
    final vehicleId = c.vehicleId.value;
    final err = validateOdometer(
      await _readings(vehicleId),
      c.date.value,
      c.odometerM.value,
      ignoreId: c.id.present ? 'f${c.id.value}' : null,
    );
    if (err != null) return SaveResult.error(err);
    if (c.volumeMl.value <= 0) return const SaveResult.error('Enter how much fuel went in.');
    final row = c.copyWith(date: Value(dayOf(c.date.value)));
    if (c.id.present) {
      await (db.update(db.fillUps)..where((f) => f.id.equals(c.id.value))).write(row);
      return SaveResult.ok(c.id.value);
    }
    return SaveResult.ok(await db.into(db.fillUps).insert(row));
  }

  Future<void> deleteFill(int id) => (db.delete(db.fillUps)..where((f) => f.id.equals(id))).go();

  /// Saves a service; when [resetReminderId] is set, that reminder is marked
  /// done at this service's date and odometer.
  Future<SaveResult> saveService(ServicesCompanion c, {int? resetReminderId}) async {
    final odo = c.odometerM.present ? c.odometerM.value : null;
    if (odo != null) {
      final err = validateOdometer(
        await _readings(c.vehicleId.value),
        c.date.value,
        odo,
        ignoreId: c.id.present ? 's${c.id.value}' : null,
      );
      if (err != null) return SaveResult.error(err);
    }
    final row = c.copyWith(date: Value(dayOf(c.date.value)));
    return db.transaction(() async {
      int id;
      if (c.id.present) {
        await (db.update(db.services)..where((s) => s.id.equals(c.id.value))).write(row);
        id = c.id.value;
      } else {
        id = await db.into(db.services).insert(row);
      }
      if (resetReminderId != null) {
        await (db.update(db.reminders)..where((r) => r.id.equals(resetReminderId))).write(
          RemindersCompanion(lastDoneDate: Value(dayOf(c.date.value)), lastDoneOdometerM: Value(odo)),
        );
      }
      return SaveResult.ok(id);
    });
  }

  Future<void> deleteService(int id) => (db.delete(db.services)..where((s) => s.id.equals(id))).go();

  Future<int> saveReminder(RemindersCompanion c) async {
    final row = c.copyWith(lastDoneDate: Value(dayOf(c.lastDoneDate.value)));
    if (c.id.present) {
      await (db.update(db.reminders)..where((r) => r.id.equals(c.id.value))).write(row);
      return c.id.value;
    }
    return db.into(db.reminders).insert(row);
  }

  Future<void> deleteReminder(int id) => (db.delete(db.reminders)..where((r) => r.id.equals(id))).go();
}

// ---------- settings ----------

class Units {
  const Units(this.distance, this.volume, this.economy);
  final DistanceUnit distance;
  final VolumeUnit volume;
  final EconomyUnit economy;
}

class UnitsNotifier extends Notifier<Units> {
  static final _d = PrefValue<String>('fuel.distanceUnit', DistanceUnit.km.name);
  static final _v = PrefValue<String>('fuel.volumeUnit', VolumeUnit.l.name);
  static final _e = PrefValue<String>('fuel.economyUnit', EconomyUnit.lPer100km.name);

  @override
  Units build() {
    final p = ref.watch(sharedPrefsProvider);
    T pick<T extends Enum>(List<T> values, String name, T fallback) =>
        values.where((v) => v.name == name).firstOrNull ?? fallback;
    return Units(
      pick(DistanceUnit.values, _d.read(p), DistanceUnit.km),
      pick(VolumeUnit.values, _v.read(p), VolumeUnit.l),
      pick(EconomyUnit.values, _e.read(p), EconomyUnit.lPer100km),
    );
  }

  Future<void> set({DistanceUnit? distance, VolumeUnit? volume, EconomyUnit? economy}) async {
    final p = ref.read(sharedPrefsProvider);
    if (distance != null) await _d.write(p, distance.name);
    if (volume != null) await _v.write(p, volume.name);
    if (economy != null) await _e.write(p, economy.name);
    state = Units(distance ?? state.distance, volume ?? state.volume, economy ?? state.economy);
  }
}

final unitsProvider = NotifierProvider<UnitsNotifier, Units>(UnitsNotifier.new);

// ---------- selection and derived data ----------

class SelectedVehicle extends Notifier<int?> {
  static final _pref = PrefValue<int>('fuel.selectedVehicle', -1);
  @override
  int? build() {
    final v = _pref.read(ref.watch(sharedPrefsProvider));
    return v < 0 ? null : v;
  }

  Future<void> select(int id) async {
    await _pref.write(ref.read(sharedPrefsProvider), id);
    state = id;
  }
}

final selectedVehicleIdProvider = NotifierProvider<SelectedVehicle, int?>(SelectedVehicle.new);
final vehiclesProvider = StreamProvider<List<Vehicle>>((ref) => ref.watch(repositoryProvider).watchVehicles());

final currentVehicleProvider = Provider<Vehicle?>((ref) {
  final list = ref.watch(vehiclesProvider).value ?? const [];
  if (list.isEmpty) return null;
  final id = ref.watch(selectedVehicleIdProvider);
  return list.firstWhere((v) => v.id == id, orElse: () => list.first);
});

final fillsProvider = StreamProvider.family<List<FillUp>, int>(
  (ref, id) => ref.watch(repositoryProvider).watchFills(id),
);
final servicesProvider = StreamProvider.family<List<Service>, int>(
  (ref, id) => ref.watch(repositoryProvider).watchServices(id),
);
final remindersProvider = StreamProvider.family<List<Reminder>, int>(
  (ref, id) => ref.watch(repositoryProvider).watchReminders(id),
);

FillInput toInput(FillUp f) => FillInput(
  id: '${f.id}',
  date: f.date,
  odometerM: f.odometerM,
  volumeMl: f.volumeMl,
  costCents: f.costCents,
  isFull: f.isFull,
  missedPrevious: f.missedPrevious,
);

final economyProvider = Provider.family<EconomyResult?, int>((ref, id) {
  final fills = ref.watch(fillsProvider(id)).value;
  return fills == null ? null : computeEconomy(fills.map(toInput).toList());
});

/// Highest odometer reading from fill-ups and services.
final currentOdometerProvider = Provider.family<int?, int>((ref, id) {
  final fills = ref.watch(fillsProvider(id)).value ?? const [];
  final svcs = ref.watch(servicesProvider(id)).value ?? const [];
  int? best;
  for (final o in [...fills.map((f) => f.odometerM), ...svcs.map((s) => s.odometerM).whereType<int>()]) {
    if (best == null || o > best) best = o;
  }
  return best;
});
