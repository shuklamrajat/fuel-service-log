// Fuel economy, unit conversion and reminder maths.
// See docs/engine-failure-modes.md.
import 'dart:math' as math;

// ---------- units ----------

enum DistanceUnit { km, mi }

enum VolumeUnit { l, galUs, galUk }

enum EconomyUnit { lPer100km, kmPerL, mpgUs, mpgUk }

const metresPerMile = 1609.344;
const mlPerGalUs = 3785.411784;
const mlPerGalUk = 4546.09;

int metresFrom(double value, DistanceUnit u) => (value * (u == DistanceUnit.km ? 1000 : metresPerMile)).round();

double distanceIn(int metres, DistanceUnit u) => metres / (u == DistanceUnit.km ? 1000 : metresPerMile);

double _mlPer(VolumeUnit u) => switch (u) {
  VolumeUnit.l => 1000,
  VolumeUnit.galUs => mlPerGalUs,
  VolumeUnit.galUk => mlPerGalUk,
};

int mlFrom(double value, VolumeUnit u) => (value * _mlPer(u)).round();

double volumeIn(int ml, VolumeUnit u) => ml / _mlPer(u);

double lPer100km(int ml, int metres) => ml * 100 / metres;
double kmPerL(int ml, int metres) => metres / ml;
double mpgUs(int ml, int metres) => (metres / metresPerMile) / (ml / mlPerGalUs);
double mpgUk(int ml, int metres) => (metres / metresPerMile) / (ml / mlPerGalUk);

double economy(int ml, int metres, EconomyUnit u) => switch (u) {
  EconomyUnit.lPer100km => lPer100km(ml, metres),
  EconomyUnit.kmPerL => kmPerL(ml, metres),
  EconomyUnit.mpgUs => mpgUs(ml, metres),
  EconomyUnit.mpgUk => mpgUk(ml, metres),
};

String economyLabel(EconomyUnit u) => switch (u) {
  EconomyUnit.lPer100km => 'L/100 km',
  EconomyUnit.kmPerL => 'km/L',
  EconomyUnit.mpgUs => 'mpg',
  EconomyUnit.mpgUk => 'mpg (UK)',
};

String distanceLabel(DistanceUnit u) => u == DistanceUnit.km ? 'km' : 'mi';

String volumeLabel(VolumeUnit u) => switch (u) {
  VolumeUnit.l => 'L',
  VolumeUnit.galUs => 'gal',
  VolumeUnit.galUk => 'gal (UK)',
};

/// Half-up rounding to [decimals] places for display. A tiny nudge keeps
/// values like 2.675 (stored as 2.67499...) rounding the way people expect.
String formatHalfUp(double v, int decimals) {
  final p = math.pow(10, decimals);
  final neg = v < 0;
  final scaled = (v.abs() * p + 1e-7).floor() + ((v.abs() * p + 1e-7) % 1 >= 0.5 ? 1 : 0);
  final whole = scaled ~/ p;
  final frac = (scaled % p).toInt().toString().padLeft(decimals, '0');
  final s = decimals == 0 ? '$whole' : '$whole.$frac';
  return neg && scaled != 0 ? '-$s' : s;
}

// ---------- economy ----------

class FillInput {
  const FillInput({
    required this.id,
    required this.date,
    required this.odometerM,
    required this.volumeMl,
    required this.costCents,
    required this.isFull,
    required this.missedPrevious,
  });
  final String id;
  final DateTime date;
  final int odometerM;
  final int volumeMl;
  final int costCents;
  final bool isFull;
  final bool missedPrevious;
}

/// Distance driven and fuel used between two full fill-ups, ending at [endId].
class Segment {
  const Segment({
    required this.startId,
    required this.endId,
    required this.distanceM,
    required this.volumeMl,
    required this.costCents,
  });
  final String startId;
  final String endId;
  final int distanceM;
  final int volumeMl;
  final int costCents;
}

class EconomyResult {
  EconomyResult(this.ordered, this.segments);

  /// Fill-ups in odometer order.
  final List<FillInput> ordered;
  final List<Segment> segments;

  Segment? segmentEndingAt(String id) => segments.where((s) => s.endId == id).firstOrNull;
  int get totalDistanceM => segments.fold(0, (a, s) => a + s.distanceM);
  int get totalVolumeMl => segments.fold(0, (a, s) => a + s.volumeMl);
  bool get hasEconomy => totalDistanceM > 0 && totalVolumeMl > 0;
}

int _order(FillInput a, FillInput b) {
  final c = a.odometerM.compareTo(b.odometerM);
  return c != 0 ? c : a.date.compareTo(b.date);
}

EconomyResult computeEconomy(List<FillInput> fills) {
  final ordered = [...fills]..sort(_order);
  final segments = <Segment>[];
  FillInput? anchor; // last full fill-up the chain can measure from
  var accVol = 0, accCost = 0;
  for (final x in ordered) {
    if (x.missedPrevious) {
      anchor = null;
      accVol = 0;
      accCost = 0;
    }
    if (anchor == null) {
      if (x.isFull) anchor = x;
      accVol = 0;
      accCost = 0;
      continue;
    }
    accVol += x.volumeMl;
    accCost += x.costCents;
    if (x.isFull) {
      final dist = x.odometerM - anchor.odometerM;
      if (dist > 0 && accVol > 0) {
        segments.add(Segment(startId: anchor.id, endId: x.id, distanceM: dist, volumeMl: accVol, costCents: accCost));
      }
      anchor = x;
      accVol = 0;
      accCost = 0;
    }
  }
  return EconomyResult(ordered, segments);
}

typedef OdoReading = ({String id, DateTime date, int odometerM});

DateTime _day(DateTime d) => DateTime(d.year, d.month, d.day);

/// Null when [odometerM] fits between other days' readings, else a message.
String? validateOdometer(Iterable<OdoReading> existing, DateTime date, int odometerM, {String? ignoreId}) {
  if (odometerM <= 0) return 'Enter the odometer reading.';
  final day = _day(date);
  for (final e in existing) {
    if (e.id == ignoreId) continue;
    final d = _day(e.date);
    if (d.isBefore(day) && e.odometerM >= odometerM) {
      return 'That is not more than the reading on ${_iso(d)}. Check the odometer or the date.';
    }
    if (d.isAfter(day) && e.odometerM <= odometerM) {
      return 'That is not less than the reading on ${_iso(d)}. Check the odometer or the date.';
    }
  }
  return null;
}

String _iso(DateTime d) => '${d.year}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';

// ---------- reminders ----------

enum DueState { ok, soon, overdue }

class ReminderStatus {
  const ReminderStatus({this.dueDate, this.dueOdometerM, this.daysLeft, this.metresLeft, required this.state});
  final DateTime? dueDate;
  final int? dueOdometerM;
  final int? daysLeft;
  final int? metresLeft;
  final DueState state;
}

const soonDays = 30;

ReminderStatus reminderStatus({
  required int? intervalDays,
  required int? intervalM,
  required DateTime lastDoneDate,
  required int? lastDoneOdometerM,
  required DateTime now,
  required int? currentOdometerM,
}) {
  DateTime? dueDate;
  int? daysLeft;
  var state = DueState.ok;
  DueState worse(DueState a, DueState b) => a.index >= b.index ? a : b;

  if (intervalDays != null) {
    final l = _day(lastDoneDate);
    dueDate = DateTime(l.year, l.month, l.day + intervalDays);
    // Count calendar days so a DST change does not make it 8.96 days.
    final today = _day(now);
    daysLeft = DateTime.utc(
      dueDate.year,
      dueDate.month,
      dueDate.day,
    ).difference(DateTime.utc(today.year, today.month, today.day)).inDays;
    state = worse(state, daysLeft <= 0 ? DueState.overdue : (daysLeft <= soonDays ? DueState.soon : DueState.ok));
  }
  int? dueOdo, metresLeft;
  if (intervalM != null && lastDoneOdometerM != null) {
    dueOdo = lastDoneOdometerM + intervalM;
    if (currentOdometerM != null) {
      metresLeft = dueOdo - currentOdometerM;
      final soonM = math.min(intervalM ~/ 10, 1000000);
      state = worse(state, metresLeft <= 0 ? DueState.overdue : (metresLeft <= soonM ? DueState.soon : DueState.ok));
    }
  }
  return ReminderStatus(
    dueDate: dueDate,
    dueOdometerM: dueOdo,
    daysLeft: daysLeft,
    metresLeft: metresLeft,
    state: state,
  );
}

/// Money per kilometre, or null without any distance.
double? costPerKm(int cents, int metres) => metres <= 0 ? null : (cents / 100) / (metres / 1000);
