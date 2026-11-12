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

    final sorted = [...reminders]..sort((a, b) => statusOf(b, now, odo).state.index - statusOf(a, now, odo).state.index);

    return ListView(padding: const EdgeInsets.only(bottom: 96), children: [
      Padding(
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 4),
        child: Text('Reminders', style: theme.textTheme.titleMedium),
      ),
      for (final r in sorted)
        Builder(builder: (context) {
          final s = statusOf(r, now, odo);
          final (label, color) = switch (s.state) {
            DueState.overdue => ('Overdue', theme.colorScheme.error),
            DueState.soon => ('Due soon', Colors.orange.shade800),
            DueState.ok => ('OK', theme.colorScheme.primary),
          };
          final due = <String>[
            if (s.dueDate != null) niceDate(s.dueDate!),
            if (s.dueOdometerM != null) fmtDistance(s.dueOdometerM!, units),
          ].join(' or ');
          return Card(
            child: ListTile(
              key: Key('reminder-${r.id}'),
              title: Text(r.title),
              subtitle: Text(due.isEmpty ? 'No due point set' : 'Due $due'),
              trailing: Chip(
                key: Key('reminder-state-${r.id}'),
                label: Text(label, style: TextStyle(color: color)),
              ),
              onTap: () => Navigator.push(
                  context, MaterialPageRoute(builder: (_) => ReminderEditScreen(vehicle: vehicle, reminder: r))),
            ),
          );
        }),
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
      Padding(
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 4),
        child: Text('Service history', style: theme.textTheme.titleMedium),
      ),
      if (services.isEmpty)
        const Padding(padding: EdgeInsets.all(16), child: Text('Nothing logged yet.')),
      for (final s in services)
        Card(
          child: ListTile(
            key: Key('service-${s.id}'),
            title: Text(s.title),
            subtitle: Text([niceDate(s.date), if (s.odometerM != null) fmtDistance(s.odometerM!, units)].join(' · ')),
            trailing: Text(Money.format(s.costCents, currency: currency)),
            onTap: () => Navigator.push(
                context, MaterialPageRoute(builder: (_) => ServiceEditScreen(vehicle: vehicle, service: s))),
          ),
        ),
    ]);
  }
}
