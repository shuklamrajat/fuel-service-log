import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:app_core/app_core.dart';
import 'package:flutter/material.dart';

/// Wrench Gauge: a dashboard dial whose needle is a wrench. The same artwork
/// as brand/logo.svg. The needle sweeps up to full, then settles and idles.
void wrenchnoteLogo(Canvas c, Size size, SceneFrame f) {
  onLogoGrid(c, size, (c) {
    c.drawRect(
      const Rect.fromLTWH(0, 0, 512, 512),
      Paint()..shader = ui.Gradient.linear(Offset.zero, const Offset(512, 512), const [Color(0xFF3F51C8), Color(0xFF1A237E)]),
    );
    c.save();
    c.translate(256, 256);
    c.scale(0.84);
    c.translate(-256, -256);
    const centre = Offset(256, 290);

    c.drawCircle(centre, 196, Paint()..color = const Color(0xFF0E1450));
    c.drawCircle(
      centre,
      196,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 10
        ..color = const Color(0xFF3949AB),
    );

    // The arc, from -120° to 120° measured from straight up.
    double rad(double deg) => deg * math.pi / 180;
    c.drawArc(
      Rect.fromCircle(center: centre, radius: 176),
      rad(-120 - 90),
      rad(240),
      false,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 18
        ..strokeCap = StrokeCap.round
        ..shader = ui.Gradient.linear(
          const Offset(80, 0),
          const Offset(432, 0),
          const [Color(0xFF5C6BC0), Color(0xFF7986CB), Color(0xFFFF7043)],
          const [0, .6, 1],
        ),
    );

    for (var i = 0; i <= 10; i++) {
      final a = rad(-120 + i * 24.0);
      final major = i % 5 == 0;
      final r1 = major ? 128.0 : 140.0;
      const r2 = 158.0;
      c.drawLine(
        centre + Offset(r1 * math.sin(a), -r1 * math.cos(a)),
        centre + Offset(r2 * math.sin(a), -r2 * math.cos(a)),
        Paint()
          ..strokeWidth = major ? 12 : 7
          ..strokeCap = StrokeCap.round
          ..color = i >= 8 ? const Color(0xFFFF7043) : const Color(0xFFC5CAE9),
      );
    }

    // Needle: sweeps from empty past full and settles at 48°, then idles.
    final t = f.intro.clamp(0.0, 1.0);
    final sweep = t < .6
        ? ui.lerpDouble(-110, 58, Curves.easeOutCubic.transform(t / .6))!
        : ui.lerpDouble(58, 48, Curves.easeInOut.transform((t - .6) / .4))!;
    final angle = sweep + math.sin(f.loop * 2 * 2 * math.pi) * 3;
    c.save();
    c.translate(centre.dx, centre.dy);
    c.rotate(rad(angle));
    c.drawPath(
      Path()
        ..moveTo(-14, 0)
        ..lineTo(-10, -116)
        ..arcToPoint(const Offset(-28, -172), radius: const Radius.circular(40))
        ..lineTo(-14, -146)
        ..lineTo(14, -146)
        ..lineTo(28, -172)
        ..arcToPoint(const Offset(10, -116), radius: const Radius.circular(40))
        ..lineTo(14, 0)
        ..close(),
      Paint()..color = const Color(0xFFFFF3EE),
    );
    c.restore();
    c.drawCircle(centre, 28, Paint()..color = const Color(0xFFFF7043));
    c.drawCircle(centre, 10, Paint()..color = const Color(0xFF0E1450));

    // Fuel pump under the dial.
    const pumpColor = Color(0xFFC5CAE9);
    c.drawPath(
      Path()
        ..addRect(const Rect.fromLTRB(226, 382, 266, 436))
        ..moveTo(266, 394)
        ..lineTo(280, 402)
        ..lineTo(280, 426)
        ..arcToPoint(const Offset(296, 426), radius: const Radius.circular(8), clockwise: false)
        ..lineTo(296, 392),
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 9
        ..strokeJoin = StrokeJoin.round
        ..strokeCap = StrokeCap.round
        ..color = pumpColor,
    );
    c.drawRRect(
      RRect.fromRectAndRadius(const Rect.fromLTWH(234, 392, 24, 14), const Radius.circular(3)),
      Paint()..color = pumpColor,
    );
    c.restore();
  });
}
