// End-to-end on the build as it ships today: a new user logs two fill-ups,
// exports them and adds a second vehicle, all without a paywall.
//
// What could go wrong, written down before the code:
//   1. The shipped build still uses the locked stand-in, so a reviewer taps a
//      paid feature and lands on a paywall that cannot take a purchase.
//   2. Pro is unlocked, but Settings thanks the person for buying it, or its
//      Pro row still leads into the paywall.
//   3. Pro is only unlocked until the app restarts (it leans on a stored flag).
//   4. The privacy link opens another app's policy, or nothing at all, and a
//      phone with no browser gives no hint where the policy lives.
// Unlike app_e2e_test.dart, this run does NOT override the entitlement
// service: it uses exactly what a release build ships with.
//
// Run: tool/run_e2e.sh (runs this after app_e2e_test.dart)
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

const artifactRoot = String.fromEnvironment('ARTIFACT_DIR', defaultValue: 'test-artifacts/manual-free');
const policyUrl = 'https://shuklamrajat.github.io/widdle-privacy/wrenchnote/';

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('Wrenchnote as shipped now: every Pro feature free, privacy link', (tester) async {
    WidgetController.hitTestWarningShouldBeFatal = true;
    Motion.ambient = false; // endless decorative loops would block pumpAndSettle
    addTearDown(() => Motion.ambient = true);
    final semantics = tester.ensureSemantics();
    final log = E2eLog('fuel_log: Wrenchnote as shipped now: every Pro feature free, privacy link', artifactRoot);
    final tmp = await Directory.systemTemp.createTemp('fuel_log_free');
    final prefs = await SharedPreferences.getInstance();
    await prefs.clear();
    final db = FuelDb(NativeDatabase(File('${tmp.path}/app.sqlite')));
    final clock = TestClock(DateTime(2026, 11, 11, 9));
    final sharer = RecordingFileSharer();
    final links = RecordingLinkOpener();
    final d = E2eDriver(tester);

    // No entitlementServiceProvider override: this is the shipped default.
    Widget app() => ProviderScope(
      overrides: [
        sharedPrefsProvider.overrideWithValue(prefs),
        appConfigProvider.overrideWithValue(fuelConfig),
        fuelDbProvider.overrideWithValue(db),
        clockProvider.overrideWithValue(clock.call),
        fileSharerProvider.overrideWithValue(sharer),
        exportDirProvider.overrideWithValue(() async => tmp),
        reviewRequesterProvider.overrideWithValue(RecordingReviewRequester()),
        linkOpenerProvider.overrideWithValue(links),
      ],
      child: const FuelApp(),
    );
    await tester.pumpWidget(app());
    await tester.pumpAndSettle();

    try {
      Future<void> addFill(String date, String km, String litres, String paid) async {
        await d.tapKey('add-fill');
        await d.type('fill-date', date);
        await d.type('fill-odometer', km);
        await d.type('fill-volume', litres);
        await d.type('fill-cost', paid);
        await d.tapKey('save-fill');
        await d.waitFor(find.byKey(const Key('add-fill')));
      }

      await d.tapKey('onboarding-skip');
      await d.tapKey('add-first-vehicle');
      await d.type('vehicle-name', 'Civic');
      await d.tapKey('save-vehicle');
      await d.waitFor(find.byKey(const Key('add-fill')));
      await d.skipTour();
      log.check('desktop build shows no ad', false, d.exists('ad-banner'));
      // 500 km on 40 L between two full tanks = 8.00 L/100 km.
      await addFill('2026-10-01', '10000', '35', '52.50');
      await addFill('2026-10-12', '10500', '40', '60.00');
      log.check('economy from two full tanks', '8.00 L/100 km', await d.textOf('last-economy'));

      // Export is a Pro feature: it must go straight to the share sheet.
      await d.tapKey('tab-costs');
      await d.tapKey('export-csv');
      await d.waitUntil(() => sharer.shared.length == 1, 'CSV export');
      log.check('export: no paywall', false, d.exists('paywall'));
      final csv = log.keep(sharer.shared.single, 'civic.csv').readAsStringSync();
      log.check('CSV total is both fill-ups', true, csv.contains('Total cost,112.50'));

      // A second vehicle is a Pro feature too.
      await d.tapKey('tab-fuel');
      await d.tapKey('vehicle-switcher');
      await d.pick('+ Add vehicle');
      await d.waitFor(find.byKey(const Key('vehicle-name')));
      log.check('second vehicle: no paywall', false, d.exists('paywall'));
      await d.type('vehicle-name', 'F-150');
      await d.tapKey('save-vehicle');
      await d.waitFor(find.byKey(const Key('add-fill')));
      log.check('two vehicles saved', ['Civic', 'F-150'], [for (final v in await db.select(db.vehicles).get()) v.name]);

      // Settings: no thank-you for a purchase nobody made, no way into a
      // paywall, and the privacy policy opens at this app's own address.
      await d.tapKey('open-settings');
      log.check(
        'Settings says Pro is free for now',
        true,
        (await d.textsIn('settings-pro')).startsWith('Every Pro feature is free for now'),
      );
      await d.tapKey('settings-pro');
      log.check('tapping the Pro row opens no paywall', false, d.exists('paywall'));
      await d.tapKey('settings-privacy-policy');
      log.check("privacy policy opens this app's own page", [policyUrl], [for (final u in links.opened) '$u']);
      log.check('no error after the link opened', false, d.exists('privacy-link-failed'));
      links.works = false; // a phone with no browser
      await d.tapKey('settings-privacy-policy');
      await d.waitFor(find.byKey(const Key('privacy-link-failed')));
      log.check(
        'no browser: the address is shown instead',
        true,
        find
            .descendant(of: find.byKey(const Key('privacy-link-failed')), matching: find.textContaining(policyUrl))
            .evaluate()
            .isNotEmpty,
      );
      await tester.pageBack();
      await tester.pumpAndSettle();

      // Close and reopen: Pro must not depend on anything stored.
      await tester.pumpWidget(const SizedBox.shrink());
      await tester.pumpAndSettle();
      await tester.pumpWidget(app());
      await d.waitFor(find.byKey(const Key('add-fill')));
      await d.tapKey('vehicle-switcher');
      await d.pick('Civic');
      await d.tapKey('tab-costs');
      await d.tapKey('export-pdf');
      await d.waitUntil(() => sharer.shared.length == 2, 'PDF export after restart');
      log.check('after a restart: export still free', false, d.exists('paywall'));
      log.check('nothing about Pro was stored on the phone', <String>[], [
        for (final k in prefs.getKeys())
          if (k.toLowerCase().contains('pro')) k,
      ]);
    } finally {
      log.write();
      semantics.dispose();
    }
    expect(log.failures, isEmpty, reason: 'see $artifactRoot/result.json');
    await tester.pumpWidget(const SizedBox.shrink());
    await db.close().timeout(const Duration(seconds: 5), onTimeout: () {});
  }, timeout: const Timeout(Duration(minutes: 4)));
}
