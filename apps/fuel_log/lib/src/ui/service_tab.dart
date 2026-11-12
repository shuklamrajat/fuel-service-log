import 'package:app_core/app_core.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../data/repository.dart';
import '../domain/engine.dart';
import 'edit_screens.dart';
import 'format.dart';

ReminderStatus statusOf(Reminder r, DateTime now, int? odo) => reminderStatus(
  intervalDays: r.intervalDays,
  intervalM: r.intervalM,
  lastDoneDate: r.lastDoneDate,
  lastDoneOdometerM: r.lastDoneOdometerM,
  now: now,
  currentOdometerM: odo,
);

class ServiceTab extends ConsumerWidget {
  const ServiceTab({super.key, required this.vehicle});
  final Vehicle vehicle;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final reminders = ref.watch(remindersProvider(vehicle.id)).value ?? const <Reminder>[];
    final services = ref.watch(servicesProvider(vehicle.id)).value ?? const <Service>[];
    final odo = ref.watch(currentOdometerProvider(vehicle.id));
    final now = ref.watch(clockProvider)();
    final units = ref.watch(unitsProvider);
    final currency = ref.watch(coreSettingsProvider).currency;
    final theme = Theme.of(context);

    final sorted = [...reminders]
      ..sort((a, b) => statusOf(b, now, odo).state.index - statusOf(a, now, odo).state.index);

    final brand = BrandColors.of(context);
    var i = 0;
    return ListView(
      padding: const EdgeInsets.only(bottom: 96),
      children: [
        const SectionHeader('Reminders'),
        for (final r in sorted)
          Builder(
            builder: (context) {
              final s = statusOf(r, now, odo);
              final (label, color) = switch (s.state) {
                DueState.overdue => ('Overdue', theme.colorScheme.error),
                DueState.soon => ('Due soon', brand.warning),
                DueState.ok => ('OK', brand.success),
              };
              final due = <String>[
                if (s.dueDate != null) niceDate(s.dueDate!),
                if (s.dueOdometerM != null) fmtDistance(s.dueOdometerM!, units),
              ].join(' or ');
              return Appear(
                index: i++,
                child: Card(
                  child: ListTile(
                    key: Key('reminder-${r.id}'),
                    leading: _DueRing(used: _used(r, now, odo), color: color, icon: _iconFor(r.title)),
                    title: Text(r.title, style: const TextStyle(fontWeight: FontWeight.w700)),
                    subtitle: Text(due.isEmpty ? 'No due point set' : 'Due $due'),
                    trailing: Container(
                      key: Key('reminder-state-${r.id}'),
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                      decoration: BoxDecoration(
                        color: color.withValues(alpha: 0.14),
                        borderRadius: BorderRadius.circular(99),
                      ),
                      child: Text(
                        label,
                        style: TextStyle(color: color, fontWeight: FontWeight.w800, fontSize: 12),
                      ),
                    ),
                    onTap: () => Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) => ReminderEditScreen(vehicle: vehicle, reminder: r),
                      ),
                    ),
                  ),
                ),
              );
            },
          ),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: Align(
            alignment: Alignment.centerLeft,
            child: TextButton.icon(
              key: const Key('add-reminder'),
              icon: const Icon(Icons.add_alarm),
              label: const Text('Add reminder'),
              onPressed: () =>
                  Navigator.push(context, MaterialPageRoute(builder: (_) => ReminderEditScreen(vehicle: vehicle))),
            ),
          ),
        ),
        const SectionHeader('Service history'),
        if (services.isEmpty) const Padding(padding: EdgeInsets.all(16), child: Text('Nothing logged yet.')),
        for (final s in services)
          Appear(
            index: i++,
            child: Card(
              child: ListTile(
                key: Key('service-${s.id}'),
                leading: IconBadge(icon: _iconFor(s.title), size: 40),
                title: Text(s.title, style: const TextStyle(fontWeight: FontWeight.w600)),
                subtitle: Text(
                  [niceDate(s.date), if (s.odometerM != null) fmtDistance(s.odometerM!, units)].join(' · '),
                ),
                trailing: Text(
                  Money.format(s.costCents, currency: currency),
                  style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w800),
                ),
                onTap: () => Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => ServiceEditScreen(vehicle: vehicle, service: s),
                  ),
                ),
              ),
            ),
          ),
      ],
    );
  }

  /// How much of the interval has gone, by date or distance, whichever is
  /// further along (0 to 1).
  static double _used(Reminder r, DateTime now, int? odo) {
    var used = 0.0;
    if (r.intervalDays != null && r.intervalDays! > 0) {
      used = now.difference(r.lastDoneDate).inHours / 24 / r.intervalDays!;
    }
    if (r.intervalM != null && r.lastDoneOdometerM != null && odo != null && r.intervalM! > 0) {
      final d = (odo - r.lastDoneOdometerM!) / r.intervalM!;
      if (d > used) used = d;
    }
    return used.clamp(0.0, 1.0);
  }

  static IconData _iconFor(String title) {
    final t = title.toLowerCase();
    if (t.contains('oil')) return Icons.oil_barrel_outlined;
    if (t.contains('tire') || t.contains('tyre')) return Icons.tire_repair_outlined;
    if (t.contains('brake')) return Icons.album_outlined;
    if (t.contains('inspect')) return Icons.fact_check_outlined;
    if (t.contains('battery')) return Icons.battery_charging_full_outlined;
    return Icons.build_outlined;
  }
}

/// A ring that fills toward the due point, drawn in when it first shows.
class _DueRing extends StatelessWidget {
  const _DueRing({required this.used, required this.color, required this.icon});
  final double used;
  final Color color;
  final IconData icon;

  @override
  Widget build(BuildContext context) {
    final track = Theme.of(context).colorScheme.surfaceContainerHighest;
    return SizedBox.square(
      dimension: 44,
      child: TweenAnimationBuilder<double>(
        tween: Tween(begin: 0, end: used),
        duration: Motion.of(context, 900),
        curve: Curves.easeOutCubic,
        builder: (_, v, child) => CustomPaint(painter: _RingPainter(v, color, track), child: child),
        child: Icon(icon, size: 20, color: color),
      ),
    );
  }
}

class _RingPainter extends CustomPainter {
  _RingPainter(this.v, this.color, this.track);
  final double v;
  final Color color;
  final Color track;

  @override
  void paint(Canvas canvas, Size size) {
    final r = Rect.fromLTWH(3, 3, size.width - 6, size.height - 6);
    canvas.drawArc(
      r,
      0,
      6.2832,
      false,
      Paint()
        ..color = track
        ..style = PaintingStyle.stroke
        ..strokeWidth = 4,
    );
    canvas.drawArc(
      r,
      -1.5708,
      6.2832 * v,
      false,
      Paint()
        ..color = color
        ..style = PaintingStyle.stroke
        ..strokeWidth = 4
        ..strokeCap = StrokeCap.round,
    );
  }

  @override
  bool shouldRepaint(_RingPainter old) => old.v != v || old.color != color;
}
