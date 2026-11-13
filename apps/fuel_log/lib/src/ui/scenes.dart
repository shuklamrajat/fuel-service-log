// Wrenchnote's illustrations, drawn in code so they scale, theme and move.
import 'dart:math' as math;

import 'package:app_core/app_core.dart';
import 'package:flutter/material.dart';

const _orange = Color(0xFFFF7043);
const _orangeDark = Color(0xFFD84315);
const _sky = Color(0xFF90CAF9);

/// Side view of a little hatchback, [w] wide, wheels turned by [spin] turns.
void _car(Canvas c, Offset bottomCenter, double w, SceneFrame f, {double spin = 0, double bounce = 0, Color? body}) {
  final col = body ?? f.scheme.primary;
  final h = w * 0.42;
  final left = bottomCenter.dx - w / 2, base = bottomCenter.dy - w * 0.1 + bounce;
  final shell = Path()
    ..moveTo(left + w * 0.04, base)
    ..lineTo(left + w * 0.02, base - h * 0.45)
    ..quadraticBezierTo(left + w * 0.03, base - h * 0.6, left + w * 0.2, base - h * 0.62)
    ..lineTo(left + w * 0.32, base - h * 0.98)
    ..quadraticBezierTo(left + w * 0.36, base - h * 1.04, left + w * 0.44, base - h * 1.04)
    ..lineTo(left + w * 0.7, base - h * 1.04)
    ..quadraticBezierTo(left + w * 0.76, base - h * 1.02, left + w * 0.8, base - h * 0.62)
    ..quadraticBezierTo(left + w * 0.97, base - h * 0.58, left + w * 0.98, base - h * 0.35)
    ..lineTo(left + w * 0.97, base)
    ..close();
  c.drawPath(shell.shift(const Offset(0, 4)), Ink2.fill(Colors.black.withValues(alpha: 0.15)));
  c.drawPath(
    shell,
    Paint()
      ..shader = LinearGradient(
        begin: Alignment.topCenter,
        end: Alignment.bottomCenter,
        colors: [Color.lerp(col, Colors.white, 0.15)!, Color.lerp(col, Colors.black, 0.2)!],
      ).createShader(Rect.fromLTWH(left, base - h, w, h)),
  );
  // Windows.
  final glass = Ink2.fill(f.dark ? const Color(0xFF3B4A6B) : _sky);
  c.drawPath(
    Path()
      ..moveTo(left + w * 0.24, base - h * 0.62)
      ..lineTo(left + w * 0.34, base - h * 0.92)
      ..lineTo(left + w * 0.5, base - h * 0.92)
      ..lineTo(left + w * 0.5, base - h * 0.62)
      ..close(),
    glass,
  );
  c.drawPath(
    Path()
      ..moveTo(left + w * 0.54, base - h * 0.62)
      ..lineTo(left + w * 0.54, base - h * 0.92)
      ..lineTo(left + w * 0.68, base - h * 0.92)
      ..lineTo(left + w * 0.74, base - h * 0.62)
      ..close(),
    glass,
  );
  // Lights.
  c.drawCircle(Offset(left + w * 0.95, base - h * 0.4), w * 0.025, Ink2.fill(const Color(0xFFFFE082)));
  c.drawCircle(Offset(left + w * 0.04, base - h * 0.4), w * 0.02, Ink2.fill(const Color(0xFFEF5350)));
  // Wheels.
  for (final x in [0.24, 0.76]) {
    final o = Offset(left + w * x, base);
    final r = w * 0.1;
    c.drawCircle(o, r, Ink2.fill(const Color(0xFF263238)));
    c.drawCircle(o, r * 0.55, Ink2.fill(const Color(0xFFB0BEC5)));
    for (var k = 0; k < 4; k++) {
      final a = spin * 2 * math.pi + k * math.pi / 2;
      c.drawLine(o, o + Offset(math.cos(a), math.sin(a)) * r * 0.5, Ink2.stroke(const Color(0xFF546E7A), r * 0.12));
    }
  }
}

/// Wrenchnote's mascot: a notepad with a wrench clipped to it and a face.
void wrenchnote(Canvas c, Offset o, double size, SceneFrame f, {double tilt = 0, double blink = 0}) {
  if (size <= 1) return;
  c.save();
  c.translate(o.dx, o.dy);
  c.rotate(tilt);
  c.scale(size / 100);
  final pad = Rect.fromCenter(center: Offset.zero, width: 70, height: 88);
  Ink2.rrect(c, pad.shift(const Offset(3, 5)), 10, Ink2.fill(Colors.black.withValues(alpha: 0.15)));
  Ink2.rrect(c, pad, 10, Ink2.fill(f.dark ? const Color(0xFFECEFF1) : Colors.white));
  Ink2.rrect(c, Rect.fromLTWH(pad.left, pad.top, pad.width, 16), 8, Ink2.fill(_orange));
  for (var i = 0; i < 3; i++) {
    final y = pad.top + 50 + i * 10.0;
    c.drawLine(Offset(pad.left + 10, y), Offset(pad.right - 10 - i * 8, y), Ink2.stroke(const Color(0xFFB0BEC5), 3));
  }
  // Face.
  final eyeH = 7 * (1 - blink) + 1;
  c.drawOval(
    Rect.fromCenter(center: const Offset(-12, 28 - 32), width: 7, height: eyeH),
    Ink2.fill(const Color(0xFF263238)),
  );
  c.drawOval(
    Rect.fromCenter(center: const Offset(12, 28 - 32), width: 7, height: eyeH),
    Ink2.fill(const Color(0xFF263238)),
  );
  c.drawArc(
    Rect.fromCenter(center: const Offset(0, 4), width: 18, height: 12),
    0.2,
    math.pi - 0.4,
    false,
    Ink2.stroke(const Color(0xFF263238), 3),
  );
  // Wrench clipped on the side.
  c.save();
  c.translate(pad.right - 4, pad.top + 10);
  c.rotate(0.5);
  final metal = Ink2.fill(f.scheme.primary);
  Ink2.rrect(c, const Rect.fromLTWH(-5, 0, 10, 62), 5, metal);
  c.drawCircle(const Offset(0, 0), 13, metal);
  c.drawCircle(const Offset(0, -6), 7, Ink2.fill(f.dark ? f.scheme.surface : Colors.white));
  c.restore();
  c.restore();
}

double _blink(double loop) {
  final t = (loop * 2) % 1;
  return t > 0.92 ? math.sin((t - 0.92) / 0.08 * math.pi) : 0;
}

void _hills(Canvas c, Size s, SceneFrame f, double drift) {
  final w = s.width, h = s.height;
  final far = Ink2.fill(f.scheme.primary.withValues(alpha: f.dark ? 0.25 : 0.14));
  final near = Ink2.fill(f.scheme.primary.withValues(alpha: f.dark ? 0.4 : 0.24));
  for (final (paint, amp, y, speed) in [(far, 0.07, 0.62, 0.3), (near, 0.05, 0.7, 0.6)]) {
    final p = Path()..moveTo(0, h);
    for (var x = 0.0; x <= w; x += 8) {
      p.lineTo(x, h * y - h * amp * (math.sin((x / w * 2 + drift * speed) * math.pi) * 0.5 + 0.5));
    }
    p
      ..lineTo(w, h)
      ..close();
    c.drawPath(p, paint);
  }
}

void _road(Canvas c, Size s, SceneFrame f, double offset) {
  final w = s.width, h = s.height;
  final road = Rect.fromLTWH(0, h * 0.74, w, h * 0.14);
  c.drawRect(road, Ink2.fill(f.dark ? const Color(0xFF2B2F38) : const Color(0xFF455A64)));
  final dash = w * 0.1;
  for (var x = -dash * 2 + (offset % 1) * -dash * 2; x < w; x += dash * 2) {
    c.drawLine(Offset(x, road.center.dy), Offset(x + dash, road.center.dy), Ink2.stroke(const Color(0xFFFFE082), 3));
  }
}

/// Onboarding 1: the car rolls up to a pump; the gauge climbs to full.
void fillUpScene(Canvas c, Size s, SceneFrame f) {
  final w = s.width, h = s.height;
  c.clipRRect(RRect.fromRectAndRadius(Rect.fromLTWH(0, h * 0.18, w, h * 0.74), Radius.circular(w * 0.1)));
  c.drawRect(Offset.zero & s, Ink2.fill(f.scheme.primary.withValues(alpha: f.dark ? 0.12 : 0.06)));
  final roll = phase(f.intro, 0, 0.55, Curves.easeOutCubic);
  _hills(c, s, f, roll * 2 + f.loop);
  _road(c, s, f, roll * 3);
  // Pump.
  final pump = Rect.fromLTWH(w * 0.7, h * 0.4, w * 0.16, h * 0.36);
  Ink2.rrect(c, pump, 10, Ink2.fill(_orange));
  Ink2.rrect(
    c,
    Rect.fromLTWH(pump.left + w * 0.025, pump.top + h * 0.04, pump.width - w * 0.05, h * 0.09),
    5,
    Ink2.fill(f.dark ? const Color(0xFF263238) : Colors.white),
  );
  Ink2.rrect(
    c,
    Rect.fromLTWH(pump.left - w * 0.01, pump.bottom - 6, pump.width + w * 0.02, 10),
    4,
    Ink2.fill(_orangeDark),
  );
  // Car.
  final carX = -w * 0.4 + (w * 0.42 + w * 0.4) * roll;
  final settle = phase(f.intro, 0.5, 0.7, Curves.elasticOut);
  _car(c, Offset(carX, h * 0.86), w * 0.5, f, spin: roll * 3, bounce: (1 - settle) * 3);
  // Hose and drops.
  final hose = phase(f.intro, 0.55, 0.75);
  if (hose > 0) {
    final from = Offset(pump.left, pump.top + h * 0.2);
    final to = Offset.lerp(from, Offset(carX + w * 0.22, h * 0.68), hose)!;
    final path = Path()
      ..moveTo(from.dx, from.dy)
      ..quadraticBezierTo((from.dx + to.dx) / 2, to.dy + h * 0.08, to.dx, to.dy);
    c.drawPath(path, Ink2.stroke(const Color(0xFF263238), 5));
    for (var i = 0; i < 3; i++) {
      final t = (f.loop * 3 + i / 3) % 1;
      final drop = Offset(to.dx + 4, to.dy + 6 + t * h * 0.04);
      c.drawCircle(drop, 3 * (1 - t) * hose, Ink2.fill(_orange));
    }
  }
  // Gauge.
  final g = phase(f.intro, 0.15, 0.4, Curves.easeOutBack);
  final go = Offset(w * 0.24, h * 0.24);
  final gr = w * 0.15 * g;
  if (gr > 2) {
    c.drawCircle(go, gr, Ink2.fill(f.dark ? f.scheme.surfaceContainerHigh : Colors.white));
    c.drawArc(
      Rect.fromCircle(center: go, radius: gr * 0.78),
      math.pi * 0.8,
      math.pi * 1.4,
      false,
      Ink2.stroke(f.scheme.outlineVariant, gr * 0.12),
    );
    final level = phase(f.intro, 0.6, 1, Curves.easeInOutCubic) * 0.95 + 0.04 + 0.01 * f.wave();
    c.drawArc(
      Rect.fromCircle(center: go, radius: gr * 0.78),
      math.pi * 0.8,
      math.pi * 1.4 * level,
      false,
      Ink2.stroke(level > 0.6 ? f.brand.success : _orange, gr * 0.12),
    );
    final a = math.pi * 0.8 + math.pi * 1.4 * level;
    c.drawLine(go, go + Offset(math.cos(a), math.sin(a)) * gr * 0.6, Ink2.stroke(f.scheme.onSurface, gr * 0.08));
    c.drawCircle(go, gr * 0.1, Ink2.fill(f.scheme.onSurface));
  }
  paintSparkField(c, Size(w, h * 0.5), f, _orange, count: 4, seed: 6);
}

/// Onboarding 2: a gear turns while the wrench tightens a bolt; a check
/// mark lands on the service card.
void serviceScene(Canvas c, Size s, SceneFrame f) {
  final w = s.width, h = s.height;
  final o = Offset(w * 0.42, h * 0.48);
  Ink2.glow(c, o, w * 0.5, f.scheme.primary.withValues(alpha: 0.2));
  final pop = phase(f.intro, 0, 0.5, Curves.easeOutBack);
  final turn = phase(f.intro, 0, 1) * 0.5 + f.loop;
  void gear(Offset at, double r, int teeth, double angle, Color col) {
    if (r < 1) return;
    final p = Path();
    for (var i = 0; i < teeth * 2; i++) {
      final a = angle + i * math.pi / teeth;
      final rr = i.isEven ? r : r * 0.8;
      final a2 = a + math.pi / teeth;
      if (i == 0) p.moveTo(at.dx + math.cos(a) * rr, at.dy + math.sin(a) * rr);
      p.lineTo(at.dx + math.cos(a) * rr, at.dy + math.sin(a) * rr);
      p.lineTo(at.dx + math.cos(a2) * rr, at.dy + math.sin(a2) * rr);
    }
    p.close();
    c.drawPath(p, Ink2.fill(col));
    c.drawCircle(at, r * 0.35, Ink2.fill(f.dark ? f.scheme.surface : Colors.white));
  }

  gear(o, w * 0.22 * pop, 10, turn * 2 * math.pi, f.scheme.primary);
  gear(o + Offset(w * 0.3, -h * 0.16) * pop, w * 0.12 * pop, 7, -turn * 2 * math.pi * 1.8 + 0.2, _orange);
  // Wrench swinging on the big gear's hub.
  final swing = math.sin(f.loop * 4 * math.pi) * 0.25 + phase(f.intro, 0.3, 0.8, Curves.elasticOut) * 0.6 - 0.6;
  c.save();
  c.translate(o.dx, o.dy);
  c.rotate(-0.9 + swing);
  final metal = Paint()
    ..shader = const LinearGradient(colors: [Color(0xFFCFD8DC), Color(0xFF78909C)])
        .createShader(Rect.fromLTWH(0, -8, w * 0.45, 16));
  Ink2.rrect(c, Rect.fromLTWH(0, -w * 0.025, w * 0.42 * pop, w * 0.05), 8, metal);
  c.drawCircle(Offset(w * 0.42 * pop, 0), w * 0.055 * pop, metal);
  c.restore();
  // Service card with a check.
  final card = phase(f.intro, 0.45, 0.8, Curves.easeOutBack);
  if (card > 0) {
    final r = Rect.fromCenter(center: Offset(w * 0.72, h * 0.76), width: w * 0.38 * card, height: h * 0.2 * card);
    Ink2.rrect(c, r.shift(const Offset(0, 4)), 14, Ink2.fill(Colors.black.withValues(alpha: 0.12)));
    Ink2.rrect(c, r, 14, Ink2.fill(f.dark ? f.scheme.surfaceContainerHigh : Colors.white));
    final tick = phase(f.intro, 0.75, 1);
    final cc = Offset(r.left + r.height * 0.5, r.center.dy);
    c.drawCircle(cc, r.height * 0.3, Ink2.fill(f.brand.success));
    final path = Path()
      ..moveTo(cc.dx - r.height * 0.13, cc.dy)
      ..lineTo(cc.dx - r.height * 0.03, cc.dy + r.height * 0.1)
      ..lineTo(cc.dx + r.height * 0.15, cc.dy - r.height * 0.1);
    final m = path.computeMetrics().first;
    c.drawPath(m.extractPath(0, m.length * tick), Ink2.stroke(Colors.white, 4));
    for (var i = 0; i < 2; i++) {
      c.drawLine(
        Offset(r.left + r.height, r.top + r.height * (0.38 + i * 0.26)),
        Offset(r.right - 12 - i * 18, r.top + r.height * (0.38 + i * 0.26)),
        Ink2.stroke(f.scheme.outlineVariant, 5),
      );
    }
  }
  paintSparkField(c, s, f, _orange, count: 5, seed: 1);
}

/// Onboarding 3: the mascot guards a phone; the cloud is crossed out.
void garagePrivacyScene(Canvas c, Size s, SceneFrame f) {
  final w = s.width, h = s.height;
  final o = Offset(w * 0.5, h * 0.5);
  Ink2.glow(c, o, w * 0.45, f.scheme.primary.withValues(alpha: 0.2));
  final up = phase(f.intro, 0, 0.5, Curves.easeOutBack);
  final phone = Rect.fromCenter(center: o.translate(-w * 0.08, (1 - up) * h * 0.3), width: w * 0.36, height: h * 0.62);
  Ink2.rrect(c, phone.shift(const Offset(0, 6)), 26, Ink2.fill(Colors.black.withValues(alpha: 0.15)));
  Ink2.rrect(c, phone, 26, Ink2.fill(f.dark ? f.scheme.surfaceContainerHighest : f.scheme.onSurface));
  final screen = phone.deflate(8);
  Ink2.rrect(c, screen, 20, Paint()..shader = f.brand.linear.createShader(screen));
  // Lock on the screen.
  final lk = phase(f.intro, 0.35, 0.7, Curves.easeOutBack);
  final lc = screen.center.translate(0, -screen.height * 0.08);
  final lr = screen.width * 0.22 * lk;
  if (lr > 1) {
    Ink2.rrect(
      c,
      Rect.fromCenter(center: lc.translate(0, lr * 0.4), width: lr * 1.6, height: lr * 1.2),
      8,
      Ink2.fill(Colors.white),
    );
    c.drawArc(
      Rect.fromCenter(center: lc.translate(0, -lr * 0.2), width: lr, height: lr * 1.2),
      math.pi,
      math.pi,
      false,
      Ink2.stroke(Colors.white, lr * 0.22),
    );
    c.drawCircle(lc.translate(0, lr * 0.4), lr * 0.15, Ink2.fill(f.scheme.primary));
  }
  wrenchnote(
    c,
    Offset(phone.right + w * 0.08, phone.bottom - h * 0.12 + 4 * f.wave()),
    w * 0.36 * phase(f.intro, 0.45, 0.8, Curves.easeOutBack),
    f,
    tilt: 0.12 + 0.05 * f.wave(0.25),
    blink: _blink(f.loop),
  );
  final cl = phase(f.intro, 0.6, 0.95);
  if (cl > 0) {
    final cc = Offset(w * 0.8, h * 0.16);
    final p = Ink2.fill(f.scheme.outline.withValues(alpha: 0.5 * cl));
    c.drawCircle(cc, w * 0.06, p);
    c.drawCircle(cc.translate(-w * 0.06, w * 0.025), w * 0.045, p);
    c.drawCircle(cc.translate(w * 0.06, w * 0.025), w * 0.045, p);
    c.drawRect(Rect.fromLTRB(cc.dx - w * 0.06, cc.dy, cc.dx + w * 0.06, cc.dy + w * 0.07), p);
    c.drawLine(
      cc.translate(-w * 0.1, -w * 0.07),
      cc.translate(-w * 0.1 + w * 0.2 * cl, -w * 0.07 + w * 0.17 * cl),
      Ink2.stroke(f.brand.warning, 5),
    );
  }
}

/// Empty state before the first vehicle: a car bouncing on its springs,
/// with the mascot waving it in.
void newCarScene(Canvas c, Size s, SceneFrame f) {
  final w = s.width, h = s.height;
  Ink2.glow(c, Offset(w * 0.5, h * 0.6), w * 0.5, f.scheme.primary.withValues(alpha: 0.18));
  final drop = phase(f.intro, 0, 0.6, Curves.bounceOut);
  Ink2.shadow(c, Offset(w * 0.46, h * 0.82), w * 0.6 * drop, Colors.black);
  _car(
    c,
    Offset(w * 0.46, h * 0.82 - (1 - drop) * h * 0.5),
    w * 0.66,
    f,
    bounce: 2 * math.sin(f.loop * 6 * math.pi),
    spin: f.loop * 0.2,
  );
  wrenchnote(
    c,
    Offset(w * 0.84, h * 0.4),
    w * 0.28 * phase(f.intro, 0.5, 0.85, Curves.easeOutBack),
    f,
    tilt: 0.15 * f.wave(),
    blink: _blink(f.loop),
  );
  paintSparkField(c, s, f, _orange, count: 6, seed: 7);
}

/// Empty fill-ups: a fuel gauge sweeps from empty to full and back.
void gaugeScene(Canvas c, Size s, SceneFrame f) {
  final w = s.width, h = s.height;
  final o = Offset(w / 2, h * 0.62);
  final r = math.min(w, h) * 0.42 * phase(f.intro, 0, 0.4, Curves.easeOutBack);
  if (r < 2) return;
  Ink2.glow(c, o, r * 1.4, _orange.withValues(alpha: 0.15));
  final arc = Rect.fromCircle(center: o, radius: r);
  c.drawArc(arc, math.pi, math.pi, false, Ink2.stroke(f.scheme.outlineVariant, r * 0.16));
  final level = phase(f.intro, 0.3, 1, Curves.easeInOutCubic) * (0.55 + 0.35 * f.wave());
  c.drawArc(
    arc,
    math.pi,
    math.pi * level.clamp(0.02, 1.0),
    false,
    Paint()
      ..shader = const SweepGradient(
        colors: [_orange, Color(0xFF66BB6A)],
        startAngle: math.pi,
        endAngle: 2 * math.pi,
      ).createShader(arc)
      ..style = PaintingStyle.stroke
      ..strokeWidth = r * 0.16
      ..strokeCap = StrokeCap.round,
  );
  final a = math.pi + math.pi * level;
  c.drawLine(o, o + Offset(math.cos(a), math.sin(a)) * r * 0.75, Ink2.stroke(f.scheme.onSurface, r * 0.06));
  c.drawCircle(o, r * 0.09, Ink2.fill(f.scheme.onSurface));
  final tp = TextPainter(textDirection: TextDirection.ltr);
  for (final (t, x) in [('E', -0.85), ('F', 0.85)]) {
    tp.text = TextSpan(
      text: t,
      style: TextStyle(color: f.scheme.onSurfaceVariant, fontWeight: FontWeight.w800, fontSize: r * 0.18),
    );
    tp.layout();
    tp.paint(c, o + Offset(r * x - tp.width / 2, r * 0.12));
  }
}

/// Paywall: a car, a bike and a truck roll into a row of garages.
void fleetProScene(Canvas c, Size s, SceneFrame f) {
  final w = s.width, h = s.height;
  Ink2.glow(c, Offset(w / 2, h * 0.5), h * 0.7, _orange.withValues(alpha: 0.2));
  final base = h * 0.86;
  c.drawLine(Offset(w * 0.04, base), Offset(w * 0.96, base), Ink2.stroke(f.scheme.outlineVariant, 3));
  final colors = [f.scheme.primary, _orange, f.brand.success];
  for (var i = 0; i < 3; i++) {
    final rise = phase(f.intro, i * 0.1, 0.45 + i * 0.1, Curves.easeOutBack);
    final cx = w * (0.24 + i * 0.26);
    final gw = w * 0.22, gh = h * 0.58 * rise;
    final g = Rect.fromLTWH(cx - gw / 2, base - gh, gw, gh);
    if (gh < 2) continue;
    c.drawPath(
      Path()
        ..moveTo(g.left - 6, g.top + 10)
        ..lineTo(g.center.dx, g.top - gh * 0.18)
        ..lineTo(g.right + 6, g.top + 10)
        ..close(),
      Ink2.fill(Color.lerp(colors[i], Colors.black, 0.2)!),
    );
    Ink2.rrect(c, g, 6, Ink2.fill(colors[i].withValues(alpha: f.dark ? 0.45 : 0.25)));
    final roll = phase(f.intro, 0.4 + i * 0.12, 0.8 + i * 0.07, Curves.easeOutCubic);
    _car(c, Offset(cx - w * 0.6 * (1 - roll), base), gw * 0.95, f, spin: roll * 2, body: colors[i]);
  }
  wrenchnote(
    c,
    Offset(w * 0.9, h * 0.22),
    h * 0.36 * phase(f.intro, 0.75, 1, Curves.easeOutBack),
    f,
    tilt: -0.15 + 0.06 * f.wave(),
    blink: _blink(f.loop),
  );
  paintSparkField(c, s, f, _orange, count: 7, seed: 13);
}

/// The fuel hero's gauge: a red, yellow, green arc and a needle that swings
/// to [score] (0 worst to 1 best: the last tank against the average), with a
/// little wobble while ambient motion is on.
ScenePaint economyGaugeScene({required double score, required Color ink}) => (Canvas c, Size s, SceneFrame f) {
  final o = Offset(s.width / 2, s.height * 0.68);
  final r = math.min(s.width / 2, s.height * 0.62) * 0.86;
  final arc = Rect.fromCircle(center: o, radius: r);
  const start = math.pi * 0.85, sweep = math.pi * 1.3;
  final grow = phase(f.intro, 0, 0.45);
  // Red to yellow to green, in short solid steps. No gradient shader here:
  // a many-colour gradient is the one thing the Android emulator's GPU died on.
  const steps = 36;
  final band = Paint()
    ..style = PaintingStyle.stroke
    ..strokeWidth = r * 0.2;
  for (var i = 0; i < steps * grow; i++) {
    final t = i / (steps - 1);
    band.color = t < 0.5
        ? Color.lerp(const Color(0xFFEF5350), const Color(0xFFFFCA28), t * 2)!
        : Color.lerp(const Color(0xFFFFCA28), const Color(0xFF66BB6A), (t - 0.5) * 2)!;
    // A hair of overlap so no seams show between steps.
    c.drawArc(arc, start + sweep * i / steps, sweep / steps + 0.01, false, band);
  }
  // Ticks.
  for (var i = 0; i <= 6; i++) {
    final a = start + sweep * i / 6;
    final dir = Offset(math.cos(a), math.sin(a));
    c.drawLine(o + dir * r * 0.66, o + dir * r * 0.78, Ink2.stroke(ink.withValues(alpha: 0.7 * grow), 2));
  }
  final swing = phase(f.intro, 0.3, 0.9, Curves.elasticOut);
  final wobble = 0.015 * math.sin(f.loop * 6 * math.pi);
  final a = start + sweep * (score.clamp(0.0, 1.0) * swing + wobble);
  final tip = o + Offset(math.cos(a), math.sin(a)) * r * 0.82;
  c.drawLine(o, tip, Ink2.stroke(_orange, r * 0.08));
  c.drawCircle(o, r * 0.14, Ink2.fill(ink));
  c.drawCircle(o, r * 0.07, Ink2.fill(_orangeDark));
};

/// A strip of road under the fuel hero: the car drives across with moving
/// dashes and a puff from the exhaust. Still frame: parked in the middle.
void roadStripScene(Canvas c, Size s, SceneFrame f) {
  final w = s.width, h = s.height;
  final road = Rect.fromLTWH(0, h * 0.62, w, h * 0.3);
  c.drawRRect(RRect.fromRectAndRadius(road, const Radius.circular(6)), Ink2.fill(Colors.black.withValues(alpha: 0.22)));
  final dash = 18.0;
  final shift = (f.loop * 8 % 1) * dash * 2;
  for (var x = -dash * 2 - shift; x < w; x += dash * 2) {
    c.drawLine(Offset(x, road.center.dy), Offset(x + dash, road.center.dy), Ink2.stroke(const Color(0xFFFFE082), 2.5));
  }
  final carW = h * 1.25;
  final drive = f.loop == 0 ? 0.5 : f.loop;
  final x = -carW + (w + carW * 2) * drive;
  final arrive = phase(f.intro, 0.2, 0.6, Curves.easeOutBack);
  final bounce = math.sin(f.loop * 40 * math.pi) * 0.8;
  // Exhaust puffs behind the car.
  for (var i = 0; i < 3; i++) {
    final t = (f.loop * 12 + i / 3) % 1;
    c.drawCircle(Offset(x - carW * 0.55 - t * 20, road.top + h * 0.02 - t * 6), 2 + 4 * t,
        Ink2.fill(Colors.white.withValues(alpha: 0.4 * (1 - t) * arrive)));
  }
  if (arrive > 0.02) _car(c, Offset(x, road.top + h * 0.2), carW * arrive, f, spin: f.loop * 30, bounce: bounce, body: _orange);
}
