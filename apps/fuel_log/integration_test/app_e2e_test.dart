// End-to-end: two vehicles, partial and forgotten fill-ups, a back-filled
// entry, a bad odometer, three service reminders, a paywalled export, then a
// switch to US units. Drives the real app on a real SQLite file.
//
// Run: tool/run_e2e.sh
//
// Hand-worked expectations (today = 11 Nov 2026, km and litres to start):
//   Civic fill-ups, typed in this order:
//     F1  1 Sep  10,000 km  40 L  $60.00  full       first full: no economy
//     F2  8 Sep  10,450 km  20 L  $31.00  partial
//     F3 12 Sep  10,600 km  25 L  $38.75  full       600 km / 45 L = 7.50 L/100 km
//     F4 20 Sep  11,100 km  35 L  $52.50  full       500 km / 35 L = 7.00
//     F5  5 Oct  11,900 km  30 L  $45.00  full, forgot the one before: no economy
//     F6 12 Oct  12,400 km  40 L  $62.00  full       500 km / 40 L = 8.00
//     F7 16 Sep  10,850 km  18 L  $27.00  partial, typed last
//        -> F4 becomes 500 km / 53 L = 10.60; average 1,600 km / 138 L = 8.625 -> 8.63
//   A fill-up on 20 Oct at 12,300 km is refused (below 12,400 on 12 Oct).
//   Reminders: Oil change every 180 d / 5,000 km, last 15 Mar at 6,000 km ->
//     overdue (due 11 Sep / 11,000 km); after logging "Oil change" 15 Sep at
//     10,800 km it resets to due 14 Mar 2027 or 15,800 km -> OK.
//     Tire rotation every 365 d / 10,000 km, last 20 Nov 2025 at 3,000 km ->
//     due 20 Nov (9 days) or 13,000 km (600 km left) -> due soon.
//     Inspection every 365 d, last 1 Oct 2025 -> due 1 Oct 2026 -> overdue.
//   Costs, all time: fuel $316.25 + service $289.99 (79.99 + 210.00) = $606.24;
//     distance 10,000 -> 12,400 km = 2,400 km; $606.24 / 2,400 = $0.25/km.
//   F-150: 80 L full at 50,000; 30 L partial at 50,300; 60 L full at 50,700
//     -> 700 km / 90 L = 12.857 -> 12.86 L/100 km. Must not touch the Civic.
//   After switching to miles, US gallons and US mpg:
//     Civic average 8.625 L/100 km = 27.27 mpg; odometer 12,400 km = 7,705 mi.
import 'dart:io';

import 'package:app_core/app_core.dart';
import 'package:app_core/testing.dart';
import 'package:drift/native.dart';
import 'package:e2e_driver/e2e_driver.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:fuel_log/src/app.dart';
import 'package:fuel_log/src/data/repository.dart';
import 'package:integration_test/integration_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

const artifactRoot = String.fromEnvironment('ARTIFACT_DIR', defaultValue: 'test-artifacts/manual');

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('two vehicles, partial/missed/back-filled fill-ups, reminders, export, units', (tester) async {
    WidgetController.hitTestWarningShouldBeFatal = true;
    Motion.ambient = false; // endless decorative loops would block pumpAndSettle
    addTearDown(() => Motion.ambient = true);
    final semantics = tester.ensureSemantics();
    final log = E2eLog('fuel_log: two vehicles, partial/missed/back-filled fills, reminders, units', artifactRoot);
    final tmp = await Directory.systemTemp.createTemp('fuel_e2e');
    final prefs = await SharedPreferences.getInstance();
    await prefs.clear();
    final db = FuelDb(NativeDatabase(File('${tmp.path}/fuel.sqlite')));
    final clock = TestClock(DateTime(2026, 11, 11, 9));
    final sharer = RecordingFileSharer();
    final d = E2eDriver(tester);
    final shots = StoreShots(tester)..usePhoneSize();

    Widget app() => ProviderScope(
      overrides: [
        sharedPrefsProvider.overrideWithValue(prefs),
        appConfigProvider.overrideWithValue(fuelConfig),
        fuelDbProvider.overrideWithValue(db),
        clockProvider.overrideWithValue(clock.call),
        fileSharerProvider.overrideWithValue(sharer),
        exportDirProvider.overrideWithValue(() async => tmp),
        reviewRequesterProvider.overrideWithValue(RecordingReviewRequester()),
        entitlementServiceProvider.overrideWithValue(LocalEntitlementService(prefs, allowDebugPurchase: true)),
      ],
      child: const FuelApp(),
    );
    await tester.pumpWidget(app());
    await tester.pumpAndSettle();
    String spoken(String k) => tester.getSemantics(find.byKey(Key(k))).label;

    Future<int> fillId(int km) async =>
        (await (db.select(db.fillUps)..where((f) => f.odometerM.equals(km * 1000))).getSingle()).id;
    Future<int> reminderId(String t) async =>
        (await (db.select(db.reminders)..where((r) => r.title.equals(t))).getSingle()).id;

    Future<String?> addFill(
      String date,
      String km,
      String litres,
      String paid, {
      bool partial = false,
      bool missed = false,
    }) async {
      await d.tapKey('add-fill');
      await d.type('fill-date', date);
      await d.type('fill-odometer', km);
      await d.type('fill-volume', litres);
      await d.type('fill-cost', paid);
      if (partial) await d.tapKey('fill-full');
      if (missed) await d.tapKey('fill-missed');
      await d.tapKey('save-fill');
      await d.waitFor(
        find.byWidgetPredicate((w) => w.key == const Key('form-error') || w.key == const Key('add-fill')),
      );
      return d.exists('form-error') ? await d.textOf('form-error') : null;
    }

    Future<void> addReminder(String title, String days, String dist, String lastDate, String lastOdo) async {
      await d.tapKey('add-reminder');
      await d.type('reminder-title', title);
      await d.type('reminder-days', days);
      await d.type('reminder-distance', dist);
      await d.type('reminder-last-date', lastDate);
      await d.type('reminder-last-odometer', lastOdo);
      await d.tapKey('save-reminder');
      await d.waitFor(find.byKey(const Key('add-service')));
    }

    try {
      await shots.take('0_welcome');
      await d.tapKey('onboarding-skip');
      await d.tapKey('add-first-vehicle');
      await d.type('vehicle-name', 'Civic');
      await d.type('vehicle-details', '2019 Honda Civic');
      await d.tapKey('save-vehicle');
      await d.waitFor(find.byKey(const Key('add-fill')));

      final civicFills = [
        ('2026-09-01', '10000', '40', '60.00', false, false),
        ('2026-09-08', '10450', '20', '31.00', true, false),
        ('2026-09-12', '10600', '25', '38.75', false, false),
        ('2026-09-20', '11100', '35', '52.50', false, false),
        ('2026-10-05', '11900', '30', '45.00', false, true),
        ('2026-10-12', '12400', '40', '62.00', false, false),
      ];
      log.inputs['civic_fills'] = [
        for (final f in civicFills) '${f.$1} ${f.$2} km ${f.$3} L \$${f.$4} partial=${f.$5} missed=${f.$6}',
      ];
      for (final f in civicFills) {
        log.check('saved fill ${f.$1}', null, await addFill(f.$1, f.$2, f.$3, f.$4, partial: f.$5, missed: f.$6));
      }
      log.check('last tank after F6', '8.00 L/100 km', await d.textOf('last-economy'));
      log.check(
        'F4 economy before back-fill',
        true,
        (await d.textsIn('fill-${await fillId(11100)}')).contains('7.00 L/100 km'),
      );
      log.check(
        'F5 shows no economy (missed previous)',
        false,
        (await d.textsIn('fill-${await fillId(11900)}')).contains('L/100 km'),
      );

      log.check('saved back-filled F7', null, await addFill('2026-09-16', '10850', '18', '27.00', partial: true));
      log.check(
        'F4 economy after back-fill',
        true,
        (await d.textsIn('fill-${await fillId(11100)}')).contains('10.60 L/100 km'),
      );
      log.check('average economy', '8.63 L/100 km', await d.textOf('avg-economy'));
      log.check(
        'economy chart, one point per measured tank (screen reader)',
        'Economy per tank. 12 Sep 7.50 L/100 km. 20 Sep 10.60 L/100 km. 12 Oct 8.00 L/100 km.',
        spoken('economy-chart'),
      );
      await shots.take('1_fuel');

      final bad = await addFill('2026-10-20', '12300', '20', '30.00');
      log.check('odometer below an earlier reading refused', true, bad?.contains('2026-10-12') ?? false);
      await tester.pageBack();
      await tester.pumpAndSettle();
      log.check('refused fill not stored', 7, (await db.select(db.fillUps).get()).length);

      // Reminders and services.
      await d.tapKey('tab-service');
      await addReminder('Oil change', '180', '5000', '2026-03-15', '6000');
      await addReminder('Tire rotation', '365', '10000', '2025-11-20', '3000');
      await addReminder('Inspection', '365', '', '2025-10-01', '');
      final oil = await reminderId('Oil change');
      log.check('oil change before service', 'Overdue', await d.textsIn('reminder-state-$oil'));

      await d.tapKey('add-service');
      await d.type('service-title', 'Oil change');
      await d.type('service-date', '2026-09-15');
      await d.type('service-odometer', '10800');
      await d.type('service-cost', '79.99');
      log.check('reset-reminder checkbox offered', true, d.exists('service-reset-reminder'));
      await d.tapKey('save-service');
      await d.waitFor(find.byKey(const Key('add-service')));

      await d.tapKey('add-service');
      await d.type('service-title', 'Brake pads');
      await d.type('service-date', '2026-10-01');
      await d.type('service-odometer', '11500');
      await d.type('service-cost', '210.00');
      await d.tapKey('save-service');
      await d.waitFor(find.byKey(const Key('add-service')));

      log.check('oil change after service', 'OK', await d.textsIn('reminder-state-$oil'));
      log.check(
        'oil change next due',
        true,
        (await d.textsIn('reminder-$oil')).contains('Due 14 Mar 2027 or 15,800 km'),
      );
      log.check('tire rotation', 'Due soon', await d.textsIn('reminder-state-${await reminderId('Tire rotation')}'));
      log.check('inspection', 'Overdue', await d.textsIn('reminder-state-${await reminderId('Inspection')}'));
      await shots.take('2_reminders');

      // Costs.
      await d.tapKey('tab-costs');
      log.check('total cost', r'$606.24', await d.textOf('cost-total'));
      log.check('fuel cost', r'$316.25', await d.textOf('cost-fuel'));
      log.check('service cost', r'$289.99', await d.textOf('cost-service'));
      log.check('distance', '2,400 km', await d.textOf('cost-distance'));
      log.check('cost per distance', r'$0.25/km', await d.textOf('cost-per-distance'));
      log.check('fuel vs service ring', r'Fuel $316.25, 52%. Service $289.99, 48%.', spoken('cost-split'));
      log.check(
        'spend by month chart',
        r'Spend by month. Jun nothing. Jul nothing. Aug nothing. '
            r'Sep $289.24: fuel $209.25, service $79.99. Oct $317.00: fuel $107.00, service $210.00. Nov nothing.',
        spoken('month-chart'),
      );
      await shots.take('3_costs');

      // Export is Pro: paywall first.
      await d.tapKey('export-csv');
      await d.waitFor(find.byKey(const Key('offer-pro_annual')));
      log.check('paywall shown before export', true, d.exists('paywall'));
      await d.reveal(find.byKey(const Key('offer-pro_annual')));
      await tester.tap(find.byKey(const Key('offer-pro_annual')));
      var sawConfetti = false;
      final confettiEnd = DateTime.now().add(const Duration(seconds: 15));
      while (sharer.shared.isEmpty) {
        if (DateTime.now().isAfter(confettiEnd)) throw StateError('CSV export did not start after purchase');
        await Future<void>.delayed(const Duration(milliseconds: 10));
        await tester.pump();
        sawConfetti |= find.byKey(const Key('celebration')).evaluate().isNotEmpty;
      }
      log.check('confetti plays after buying Pro', true, sawConfetti);
      await tester.pumpAndSettle();
      log.check('confetti cleared once landed', 0, find.byKey(const Key('celebration')).evaluate().length);
      await d.tapKey('export-pdf');
      await d.waitUntil(() => sharer.shared.length == 2, 'PDF export');
      final csv = log.keep(sharer.shared[0], 'civic.csv').readAsStringSync().replaceFirst('﻿', '');
      log.keep(sharer.shared[1], 'civic.pdf');
      final rows = csv.split('\r\n');
      final fillRows = rows
          .where((l) => RegExp(r'^2026-\d\d-\d\d,\d').hasMatch(l) && l.split(',').length >= 9)
          .toList();
      log.check('CSV fill rows in odometer order', [
        '10000.0',
        '10450.0',
        '10600.0',
        '10850.0',
        '11100.0',
        '11900.0',
        '12400.0',
      ], fillRows.map((l) => l.split(',')[1]).toList());
      log.check('CSV F4 economy', '10.60', fillRows[4].split(',')[7]);
      log.check('CSV F5 missed and no economy', ['yes', ''], [fillRows[5].split(',')[5], fillRows[5].split(',')[7]]);
      log.check('CSV total cost', 'Total cost,606.24', rows.firstWhere((l) => l.startsWith('Total cost')));
      log.check(
        'CSV average economy',
        'Average economy (L/100 km),8.63',
        rows.firstWhere((l) => l.startsWith('Average economy')),
      );

      // Second vehicle (now Pro).
      await d.tapKey('tab-fuel');
      await d.tapKey('vehicle-switcher');
      await d.pick('+ Add vehicle');
      await d.type('vehicle-name', 'F-150');
      await d.tapKey('save-vehicle');
      await d.waitFor(find.byKey(const Key('add-fill')));
      log.check('saved G1', null, await addFill('2026-10-01', '50000', '80', '120.00'));
      log.check('saved G2', null, await addFill('2026-10-10', '50300', '30', '45.00', partial: true));
      log.check('saved G3', null, await addFill('2026-10-15', '50700', '60', '90.00'));
      log.check('F-150 last tank', '12.86 L/100 km', await d.textOf('last-economy'));

      await d.tapKey('vehicle-switcher');
      await d.pick('Civic');
      log.check('Civic average unchanged by F-150', '8.63 L/100 km', await d.textOf('avg-economy'));

      // Switch to US units.
      await d.tapKey('open-settings');
      await d.tapKey('unit-distance');
      await d.pick('Miles');
      await d.tapKey('unit-volume');
      await d.pick('US gallons');
      await d.tapKey('unit-economy');
      await d.pick('mpg (US)');
      await tester.pageBack();
      await tester.pumpAndSettle();
      log.check('Civic average in US mpg', '27.27 mpg', await d.textOf('avg-economy'));
      log.check('Civic odometer in miles', '7,705 mi', await d.textOf('odometer'));
      log.check(
        'economy chart in US mpg',
        'Economy per tank. 12 Sep 31.36 mpg. 20 Sep 22.19 mpg. 12 Oct 29.40 mpg.',
        spoken('economy-chart'),
      );
      final stored = (await db.select(db.fillUps).get()).map((f) => f.odometerM).reduce((a, b) => a > b ? a : b);
      log.check('stored odometer unchanged by unit switch (m)', 50700000, stored);

      // Dark theme, then close and reopen: theme, units, vehicle and Pro stay.
      await d.tapKey('open-settings');
      await d.tapKey('settings-theme');
      await d.pick('Dark');
      log.check(
        'Settings switches the app to dark',
        Brightness.dark,
        Theme.of(tester.element(find.byKey(const Key('settings-theme')))).brightness,
      );
      await tester.pageBack();
      await tester.pumpAndSettle();
      await shots.take('4_dark_fuel');
      await d.tapKey('tab-costs');
      await shots.take('5_dark_costs');
      await tester.pumpWidget(const SizedBox.shrink());
      await tester.pumpAndSettle();
      await tester.pumpWidget(app());
      await d.waitFor(find.byKey(const Key('avg-economy')));
      log.check(
        'reopened: still dark',
        Brightness.dark,
        Theme.of(tester.element(find.byKey(const Key('avg-economy')))).brightness,
      );
      log.check('reopened: US units kept', '27.27 mpg', await d.textOf('avg-economy'));
      log.check('reopened: no onboarding again', false, d.exists('onboarding'));
    } finally {
      log.write();
      semantics.dispose();
    }
    expect(log.failures, isEmpty, reason: 'see $artifactRoot/result.json');
    await tester.pumpWidget(const SizedBox.shrink());
    await db.close().timeout(const Duration(seconds: 5), onTimeout: () {});
  }, timeout: const Timeout(Duration(minutes: 6)));
}
