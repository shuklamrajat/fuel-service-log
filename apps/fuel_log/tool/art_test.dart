// Renders store art from the app's own drawings: icon, mascot cut-outs and
// two illustrations. Run with tool/../../../tool/make_store_art.py, which
// frames them into the Play icon, launcher icons and feature graphic.
//   flutter test tool/art_test.dart --dart-define=ART_OUT=<dir>
import 'package:app_core/art.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:fuel_log/src/app.dart';
import 'package:fuel_log/src/ui/scenes.dart';

const out = String.fromEnvironment('ART_OUT', defaultValue: 'build/art');

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  test('store art', () async {
    await writeScenePng(
      '$out/icon.png',
      iconPaint((c, s, f) => wrenchnote(c, s.center(Offset.zero), s.width * 0.66, f, tilt: -0.08)),
      const Size(1024, 1024),
      fuelConfig,
    );
    await writeScenePng(
      '$out/mascot.png',
      (c, s, f) => wrenchnote(c, s.center(Offset(0, s.height * 0.02)), s.width * 0.7, f, tilt: -0.08),
      const Size(800, 800),
      fuelConfig,
    );
    await writeScenePng(
      '$out/mascot_dark.png',
      (c, s, f) => wrenchnote(c, s.center(Offset(0, s.height * 0.02)), s.width * 0.7, f, tilt: -0.08),
      const Size(800, 800),
      fuelConfig,
      brightness: Brightness.dark,
    );
    await writeScenePng('$out/hero.png', fillUpScene, const Size(900, 900), fuelConfig);
    await writeScenePng('$out/pro.png', fleetProScene, const Size(1200, 700), fuelConfig);
  });
}
