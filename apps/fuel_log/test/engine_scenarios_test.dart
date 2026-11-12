// Isolated scenarios for the fuel economy and reminder engine, written from
// docs/engine-failure-modes.md before the engine existed. Hand-worked numbers
// in the comments.
import 'package:flutter_test/flutter_test.dart';
import 'package:fuel_log/src/domain/engine.dart';

FillInput f(String id, DateTime d, double km, double litres, int cents, {bool full = true, bool missed = false}) =>
    FillInput(
      id: id,
      date: d,
      odometerM: (km * 1000).round(),
      volumeMl: (litres * 1000).round(),
      costCents: cents,
      isFull: full,
      missedPrevious: missed,
    );

List<FillInput> civic() => [
      f('F1', DateTime(2026, 9, 1), 10000, 40, 6000), // first full: anchor
      f('F2', DateTime(2026, 9, 8), 10450, 20, 3100, full: false),
      f('F3', DateTime(2026, 9, 12), 10600, 25, 3875), // 600 km on 45 L
      f('F4', DateTime(2026, 9, 20), 11100, 35, 5250), // 500 km on 35 L
      f('F5', DateTime(2026, 10, 5), 11900, 30, 4500, missed: true), // chain broken
      f('F6', DateTime(2026, 10, 12), 12400, 40, 6200), // 500 km on 40 L
    ];

void main() {
  test('A: partials, a missed fill-up and the average over stretches', () {
    final r = computeEconomy(civic());
    final seg = {for (final s in r.segments) s.endId: s};
    expect(seg.keys.toList(), ['F3', 'F4', 'F6']);
    expect(seg['F3']!.distanceM, 600000);
    expect(seg['F3']!.volumeMl, 45000);
    expect(seg['F3']!.costCents, 3100 + 3875);
    expect(lPer100km(seg['F3']!.volumeMl, seg['F3']!.distanceM), closeTo(7.5, 1e-9));
    expect(lPer100km(seg['F4']!.volumeMl, seg['F4']!.distanceM), closeTo(7.0, 1e-9));
    expect(lPer100km(seg['F6']!.volumeMl, seg['F6']!.distanceM), closeTo(8.0, 1e-9));
    // Average = 1600 km / 120 L = 7.5 (mean of 7.5, 7.0, 8.0 would be 7.5 too, so
    // check the totals that make it up)
    expect(r.totalDistanceM, 1600000);
    expect(r.totalVolumeMl, 120000);
  });

  test('B: a fill-up typed later but dated earlier is chained by odometer', () {
    final fills = [...civic(), f('F7', DateTime(2026, 9, 16), 10850, 18, 2700, full: false)];
    final r = computeEconomy(fills);
    final f4 = r.segments.firstWhere((s) => s.endId == 'F4');
    // F3 -> F4 now carries F7's 18 L as well: 500 km on 53 L = 10.6 L/100 km
    expect(f4.volumeMl, 53000);
    expect(lPer100km(f4.volumeMl, f4.distanceM), closeTo(10.6, 1e-9));
    // Average 1600 km / 138 L = 8.625 L/100 km; the mean of stretches would be 8.7
    expect(lPer100km(r.totalVolumeMl, r.totalDistanceM), closeTo(8.625, 1e-9));
    expect(formatHalfUp(lPer100km(r.totalVolumeMl, r.totalDistanceM), 2), '8.63');
  });

  test('C: odometer must fit between the readings on other days', () {
    final existing = [
      for (final x in civic()) (id: x.id, date: x.date, odometerM: x.odometerM),
    ];
    expect(validateOdometer(existing, DateTime(2026, 10, 20), 12300000), isNotNull); // below 12400 on 12 Oct
    expect(validateOdometer(existing, DateTime(2026, 9, 10), 10700000), isNotNull); // above 10600 on 12 Sep
    expect(validateOdometer(existing, DateTime(2026, 9, 10), 10500000), isNull);
    expect(validateOdometer(existing, DateTime(2026, 10, 20), 12500000), isNull);
    // Editing F6 itself to a nearby value is fine.
    expect(validateOdometer(existing, DateTime(2026, 10, 12), 12390000, ignoreId: 'F6'), isNull);
  });

  test('D: unit conversions and rounding', () {
    // 8.625 L/100 km = 235.214583 / 8.625 US mpg = 27.27; UK 282.480936 / 8.625 = 32.75
    const vol = 138000, dist = 1600000;
    expect(formatHalfUp(mpgUs(vol, dist), 2), '27.27');
    expect(formatHalfUp(mpgUk(vol, dist), 2), '32.75');
    expect(formatHalfUp(kmPerL(vol, dist), 2), '11.59');
    expect(metresFrom(100, DistanceUnit.mi), 160934);
    expect(mlFrom(10, VolumeUnit.galUs), 37854);
    expect(mlFrom(10, VolumeUnit.galUk), 45461);
    expect(formatHalfUp(0.125, 2), '0.13');
    expect(formatHalfUp(2.675, 2), '2.68'); // binary 2.67499.. must still round up
  });

  test('E: reminders by date or distance, whichever is first', () {
    final now = DateTime(2026, 11, 11);
    // Last done 15 Sep at 10,800 km, every 180 days or 5,000 km.
    final oil = reminderStatus(
      intervalDays: 180,
      intervalM: 5000000,
      lastDoneDate: DateTime(2026, 9, 15),
      lastDoneOdometerM: 10800000,
      now: now,
      currentOdometerM: 12400000,
    );
    expect(oil.dueDate, DateTime(2027, 3, 14));
    expect(oil.dueOdometerM, 15800000);
    expect(oil.state, DueState.ok);

    // Due 20 Nov 2026 or 13,000 km; now 9 days and 600 km away -> soon.
    final tires = reminderStatus(
      intervalDays: 365,
      intervalM: 10000000,
      lastDoneDate: DateTime(2025, 11, 20),
      lastDoneOdometerM: 3000000,
      now: now,
      currentOdometerM: 12400000,
    );
    expect(tires.state, DueState.soon);
    expect(tires.daysLeft, 9);
    expect(tires.metresLeft, 600000);

    // Date fine but distance passed -> overdue.
    final dist = reminderStatus(
      intervalDays: 365,
      intervalM: 1000000,
      lastDoneDate: DateTime(2026, 10, 1),
      lastDoneOdometerM: 11000000,
      now: now,
      currentOdometerM: 12400000,
    );
    expect(dist.state, DueState.overdue);

    // No odometer known yet: distance part unknown, date part decides.
    final noOdo = reminderStatus(
      intervalDays: 365,
      intervalM: 5000000,
      lastDoneDate: DateTime(2026, 1, 1),
      lastDoneOdometerM: null,
      now: now,
      currentOdometerM: null,
    );
    expect(noOdo.dueOdometerM, isNull);
    expect(noOdo.state, DueState.ok);
  });

  test('F: cost per distance needs some distance', () {
    expect(costPerKm(5000, 0), isNull);
    expect(costPerKm(60624, 2400000), closeTo(0.2526, 1e-4));
  });
}
