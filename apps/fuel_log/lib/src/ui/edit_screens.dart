import 'package:app_core/app_core.dart';
import 'package:drift/drift.dart' show Value;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../data/repository.dart';
import '../domain/engine.dart';
import 'date_field.dart';
import 'format.dart';

String _num(double v, int decimals) {
  final s = formatHalfUp(v, decimals);
  return s.contains('.') ? s.replaceFirst(RegExp(r'\.?0+$'), '') : s;
}

/// The reason Save was refused, pinned under the title bar. At the bottom of the
/// form it sat below the keyboard on shorter screens (the Fold unfolded), so
/// tapping Save looked like it did nothing.
PreferredSizeWidget? _errorBar(BuildContext context, String? e) => e == null
    ? null
    : PreferredSize(
        preferredSize: const Size.fromHeight(48),
        child: Container(
          width: double.infinity,
          color: Theme.of(context).colorScheme.errorContainer,
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          child: Text(
            e,
            key: const Key('form-error'),
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(color: Theme.of(context).colorScheme.onErrorContainer),
          ),
        ),
      );

// ---------------- vehicle ----------------

class VehicleEditScreen extends ConsumerStatefulWidget {
  const VehicleEditScreen({super.key, this.vehicle});
  final Vehicle? vehicle;

  @override
  ConsumerState<VehicleEditScreen> createState() => _VehicleEditScreenState();
}

class _VehicleEditScreenState extends ConsumerState<VehicleEditScreen> {
  final _form = GlobalKey<FormState>();
  late final _name = TextEditingController(text: widget.vehicle?.name ?? '');
  late final _details = TextEditingController(text: widget.vehicle?.details ?? '');

  Future<void> _save() async {
    if (!_form.currentState!.validate()) return;
    final id = await ref
        .read(repositoryProvider)
        .saveVehicle(
          VehiclesCompanion(
            id: widget.vehicle == null ? const Value.absent() : Value(widget.vehicle!.id),
            name: Value(_name.text.trim()),
            details: Value(_details.text.trim()),
          ),
        );
    await ref.read(selectedVehicleIdProvider.notifier).select(id);
    if (mounted) Navigator.pop(context);
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(
      title: Text(widget.vehicle == null ? 'New vehicle' : 'Edit vehicle'),
      actions: [TextButton(key: const Key('save-vehicle'), onPressed: _save, child: const Text('Save'))],
    ),
    body: Form(
      key: _form,
      child: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          TextFormField(
            key: const Key('vehicle-name'),
            controller: _name,
            decoration: const InputDecoration(labelText: 'Name'),
            validator: (v) => (v ?? '').trim().isEmpty ? 'Give it a name' : null,
          ),
          const SizedBox(height: 12),
          TextFormField(
            key: const Key('vehicle-details'),
            controller: _details,
            decoration: const InputDecoration(labelText: 'Make, model and year (optional)'),
          ),
        ],
      ),
    ),
  );
}

// ---------------- fill-up ----------------

class FillEditScreen extends ConsumerStatefulWidget {
  const FillEditScreen({super.key, required this.vehicle, this.fill});
  final Vehicle vehicle;
  final FillUp? fill;

  @override
  ConsumerState<FillEditScreen> createState() => _FillEditScreenState();
}

class _FillEditScreenState extends ConsumerState<FillEditScreen> {
  final _form = GlobalKey<FormState>();
  late final TextEditingController _date, _odo, _vol, _cost, _note;
  late bool _full, _missed;
  String? _error;

  @override
  void initState() {
    super.initState();
    final f = widget.fill;
    final u = ref.read(unitsProvider);
    _date = TextEditingController(text: isoDate(f?.date ?? ref.read(clockProvider)()));
    _odo = TextEditingController(text: f == null ? '' : _num(distanceIn(f.odometerM, u.distance), 1));
    _vol = TextEditingController(text: f == null ? '' : _num(volumeIn(f.volumeMl, u.volume), 3));
    _cost = TextEditingController(text: f == null ? '' : Money.plain(f.costCents));
    _note = TextEditingController(text: f?.note ?? '');
    _full = f?.isFull ?? true;
    _missed = f?.missedPrevious ?? false;
    for (final c in [_vol, _cost]) {
      c.addListener(() => setState(() {}));
    }
  }

  Future<void> _save() async {
    setState(() => _error = null);
    if (!_form.currentState!.validate()) return;
    final u = ref.read(unitsProvider);
    final isNew = widget.fill == null;
    final r = await ref
        .read(repositoryProvider)
        .saveFill(
          FillUpsCompanion(
            id: isNew ? const Value.absent() : Value(widget.fill!.id),
            vehicleId: Value(widget.vehicle.id),
            date: Value(parseIsoDate(_date.text)!),
            odometerM: Value(metresFrom(parseNumber(_odo.text)!, u.distance)),
            volumeMl: Value(mlFrom(parseNumber(_vol.text)!, u.volume)),
            costCents: Value(Money.parse(_cost.text)!),
            isFull: Value(_full),
            missedPrevious: Value(_missed),
            note: Value(_note.text.trim()),
          ),
        );
    if (!mounted) return;
    if (!r.ok) {
      setState(() => _error = r.error);
      return;
    }
    if (isNew) await ref.read(ratingPrompterProvider).recordCompletedTask();
    if (mounted) Navigator.pop(context);
  }

  Future<void> _delete() async {
    if (!await confirmDialog(context, 'Delete fill-up?', 'Economy will be recalculated without it.')) return;
    await ref.read(repositoryProvider).deleteFill(widget.fill!.id);
    if (mounted) Navigator.pop(context);
  }

  @override
  Widget build(BuildContext context) {
    final u = ref.watch(unitsProvider);
    final vol = parseNumber(_vol.text), cost = Money.parse(_cost.text);
    final perUnit = (vol != null && vol > 0 && cost != null)
        ? '${Money.format((cost / vol).round(), currency: ref.watch(coreSettingsProvider).currency)} per ${volumeLabel(u.volume)}'
        : null;
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.fill == null ? 'Add fill-up' : 'Edit fill-up'),
        bottom: _errorBar(context, _error),
        actions: [
          TextButton(key: const Key('save-fill'), onPressed: _save, child: const Text('Save')),
          if (widget.fill != null)
            IconButton(
              key: const Key('delete-fill'),
              tooltip: 'Delete fill-up',
              icon: const Icon(Icons.delete_outline),
              onPressed: _delete,
            ),
        ],
      ),
      body: Form(
        key: _form,
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            DateField(controller: _date, label: 'Date', fieldKey: const Key('fill-date')),
            const SizedBox(height: 12),
            TextFormField(
              key: const Key('fill-odometer'),
              controller: _odo,
              keyboardType: const TextInputType.numberWithOptions(decimal: true),
              decoration: InputDecoration(labelText: 'Odometer (${distanceLabel(u.distance)})'),
              validator: (v) => (parseNumber(v ?? '') ?? 0) <= 0 ? 'Enter the odometer reading' : null,
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: TextFormField(
                    key: const Key('fill-volume'),
                    controller: _vol,
                    keyboardType: const TextInputType.numberWithOptions(decimal: true),
                    decoration: InputDecoration(labelText: 'Fuel (${volumeLabel(u.volume)})'),
                    validator: (v) => (parseNumber(v ?? '') ?? 0) <= 0 ? 'How much went in' : null,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: TextFormField(
                    key: const Key('fill-cost'),
                    controller: _cost,
                    keyboardType: const TextInputType.numberWithOptions(decimal: true),
                    decoration: const InputDecoration(labelText: 'Total paid'),
                    validator: (v) => Money.parse(v ?? '') == null ? 'An amount like 52.40' : null,
                  ),
                ),
              ],
            ),
            if (perUnit != null) Padding(padding: const EdgeInsets.only(top: 6), child: Text(perUnit)),
            SwitchListTile(
              key: const Key('fill-full'),
              title: const Text('Filled the tank to the top'),
              subtitle: const Text('Turn off for a partial fill-up'),
              value: _full,
              onChanged: (v) => setState(() => _full = v),
            ),
            SwitchListTile(
              key: const Key('fill-missed'),
              title: const Text('I forgot to log the fill-up before this one'),
              subtitle: const Text('Skips the economy for this tank so it stays accurate'),
              value: _missed,
              onChanged: (v) => setState(() => _missed = v),
            ),
            TextFormField(
              key: const Key('fill-note'),
              controller: _note,
              decoration: const InputDecoration(labelText: 'Note (optional)'),
            ),
          ],
        ),
      ),
    );
  }
}

// ---------------- service ----------------

class ServiceEditScreen extends ConsumerStatefulWidget {
  const ServiceEditScreen({super.key, required this.vehicle, this.service});
  final Vehicle vehicle;
  final Service? service;

  @override
  ConsumerState<ServiceEditScreen> createState() => _ServiceEditScreenState();
}

class _ServiceEditScreenState extends ConsumerState<ServiceEditScreen> {
  final _form = GlobalKey<FormState>();
  late final TextEditingController _date, _odo, _title, _cost, _note;
  bool _reset = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    final s = widget.service;
    final u = ref.read(unitsProvider);
    _date = TextEditingController(text: isoDate(s?.date ?? ref.read(clockProvider)()));
    _odo = TextEditingController(text: s?.odometerM == null ? '' : _num(distanceIn(s!.odometerM!, u.distance), 1));
    _title = TextEditingController(text: s?.title ?? '');
    _cost = TextEditingController(text: s == null ? '' : Money.plain(s.costCents));
    _note = TextEditingController(text: s?.note ?? '');
    _title.addListener(() => setState(() {}));
  }

  Reminder? _matching(List<Reminder> reminders) {
    final t = _title.text.trim().toLowerCase();
    if (t.isEmpty) return null;
    return reminders.where((r) => r.title.trim().toLowerCase() == t).firstOrNull;
  }

  Future<void> _save() async {
    setState(() => _error = null);
    if (!_form.currentState!.validate()) return;
    final u = ref.read(unitsProvider);
    final odo = parseNumber(_odo.text);
    final match = _matching(ref.read(remindersProvider(widget.vehicle.id)).value ?? const []);
    final r = await ref
        .read(repositoryProvider)
        .saveService(
          ServicesCompanion(
            id: widget.service == null ? const Value.absent() : Value(widget.service!.id),
            vehicleId: Value(widget.vehicle.id),
            date: Value(parseIsoDate(_date.text)!),
            odometerM: Value(odo == null ? null : metresFrom(odo, u.distance)),
            title: Value(_title.text.trim()),
            costCents: Value(Money.parse(_cost.text.isEmpty ? '0' : _cost.text)!),
            note: Value(_note.text.trim()),
          ),
          resetReminderId: (match != null && _reset) ? match.id : null,
        );
    if (!mounted) return;
    if (!r.ok) {
      setState(() => _error = r.error);
      return;
    }
    Navigator.pop(context);
  }

  @override
  Widget build(BuildContext context) {
    final u = ref.watch(unitsProvider);
    final reminders = ref.watch(remindersProvider(widget.vehicle.id)).value ?? const <Reminder>[];
    final match = _matching(reminders);
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.service == null ? 'Log service' : 'Edit service'),
        bottom: _errorBar(context, _error),
        actions: [
          TextButton(key: const Key('save-service'), onPressed: _save, child: const Text('Save')),
          if (widget.service != null)
            IconButton(
              tooltip: 'Delete service',
              icon: const Icon(Icons.delete_outline),
              onPressed: () async {
                if (!await confirmDialog(context, 'Delete service?', 'It will be removed from the history.')) return;
                await ref.read(repositoryProvider).deleteService(widget.service!.id);
                if (context.mounted) Navigator.pop(context);
              },
            ),
        ],
      ),
      body: Form(
        key: _form,
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            TextFormField(
              key: const Key('service-title'),
              controller: _title,
              decoration: const InputDecoration(labelText: 'What was done', hintText: 'Oil change'),
              validator: (v) => (v ?? '').trim().isEmpty ? 'Say what was done' : null,
            ),
            if (reminders.isNotEmpty && widget.service == null)
              Wrap(
                spacing: 6,
                children: [
                  for (final r in reminders) ActionChip(label: Text(r.title), onPressed: () => _title.text = r.title),
                ],
              ),
            const SizedBox(height: 12),
            DateField(controller: _date, label: 'Date', fieldKey: const Key('service-date')),
            const SizedBox(height: 12),
            TextFormField(
              key: const Key('service-odometer'),
              controller: _odo,
              keyboardType: const TextInputType.numberWithOptions(decimal: true),
              decoration: InputDecoration(labelText: 'Odometer (${distanceLabel(u.distance)}, optional)'),
            ),
            const SizedBox(height: 12),
            TextFormField(
              key: const Key('service-cost'),
              controller: _cost,
              keyboardType: const TextInputType.numberWithOptions(decimal: true),
              decoration: const InputDecoration(labelText: 'Cost'),
              validator: (v) => (v ?? '').trim().isEmpty || Money.parse(v!) != null ? null : 'An amount like 79.99',
            ),
            if (match != null)
              CheckboxListTile(
                key: const Key('service-reset-reminder'),
                title: Text('Mark "${match.title}" reminder as done'),
                value: _reset,
                onChanged: (v) => setState(() => _reset = v ?? true),
              ),
            TextFormField(
              key: const Key('service-note'),
              controller: _note,
              decoration: const InputDecoration(labelText: 'Note (optional)'),
            ),
          ],
        ),
      ),
    );
  }
}

// ---------------- reminder ----------------

class ReminderEditScreen extends ConsumerStatefulWidget {
  const ReminderEditScreen({super.key, required this.vehicle, this.reminder});
  final Vehicle vehicle;
  final Reminder? reminder;

  @override
  ConsumerState<ReminderEditScreen> createState() => _ReminderEditScreenState();
}

class _ReminderEditScreenState extends ConsumerState<ReminderEditScreen> {
  final _form = GlobalKey<FormState>();
  late final TextEditingController _title, _days, _dist, _lastDate, _lastOdo;

  @override
  void initState() {
    super.initState();
    final r = widget.reminder;
    final u = ref.read(unitsProvider);
    final odo = ref.read(currentOdometerProvider(widget.vehicle.id));
    _title = TextEditingController(text: r?.title ?? '');
    _days = TextEditingController(text: r?.intervalDays?.toString() ?? '');
    _dist = TextEditingController(text: r?.intervalM == null ? '' : _num(distanceIn(r!.intervalM!, u.distance), 0));
    _lastDate = TextEditingController(text: isoDate(r?.lastDoneDate ?? ref.read(clockProvider)()));
    final lastOdo = r == null ? odo : r.lastDoneOdometerM;
    _lastOdo = TextEditingController(text: lastOdo == null ? '' : _num(distanceIn(lastOdo, u.distance), 0));
  }

  Future<void> _save() async {
    if (!_form.currentState!.validate()) return;
    final u = ref.read(unitsProvider);
    final dist = parseNumber(_dist.text), lastOdo = parseNumber(_lastOdo.text);
    await ref
        .read(repositoryProvider)
        .saveReminder(
          RemindersCompanion(
            id: widget.reminder == null ? const Value.absent() : Value(widget.reminder!.id),
            vehicleId: Value(widget.vehicle.id),
            title: Value(_title.text.trim()),
            intervalDays: Value(int.tryParse(_days.text.trim())),
            intervalM: Value(dist == null ? null : metresFrom(dist, u.distance)),
            lastDoneDate: Value(parseIsoDate(_lastDate.text)!),
            lastDoneOdometerM: Value(lastOdo == null ? null : metresFrom(lastOdo, u.distance)),
          ),
        );
    if (mounted) Navigator.pop(context);
  }

  @override
  Widget build(BuildContext context) {
    final u = ref.watch(unitsProvider);
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.reminder == null ? 'New reminder' : 'Edit reminder'),
        actions: [
          TextButton(key: const Key('save-reminder'), onPressed: _save, child: const Text('Save')),
          if (widget.reminder != null)
            IconButton(
              tooltip: 'Delete reminder',
              icon: const Icon(Icons.delete_outline),
              onPressed: () async {
                await ref.read(repositoryProvider).deleteReminder(widget.reminder!.id);
                if (context.mounted) Navigator.pop(context);
              },
            ),
        ],
      ),
      body: Form(
        key: _form,
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            TextFormField(
              key: const Key('reminder-title'),
              controller: _title,
              decoration: const InputDecoration(labelText: 'Reminder', hintText: 'Oil change'),
              validator: (v) => (v ?? '').trim().isEmpty ? 'Name it' : null,
            ),
            const SizedBox(height: 12),
            TextFormField(
              key: const Key('reminder-days'),
              controller: _days,
              keyboardType: TextInputType.number,
              decoration: const InputDecoration(
                labelText: 'Every this many days',
                helperText: '182 = 6 months, 365 = a year',
              ),
              validator: (v) {
                final days = int.tryParse((v ?? '').trim());
                if ((v ?? '').trim().isNotEmpty && (days == null || days <= 0)) return 'Whole days';
                if ((v ?? '').trim().isEmpty && _dist.text.trim().isEmpty) return 'Set days, distance, or both';
                return null;
              },
            ),
            const SizedBox(height: 12),
            TextFormField(
              key: const Key('reminder-distance'),
              controller: _dist,
              keyboardType: TextInputType.number,
              decoration: InputDecoration(labelText: 'Every this many ${distanceLabel(u.distance)}'),
            ),
            const SizedBox(height: 12),
            DateField(controller: _lastDate, label: 'Last done on', fieldKey: const Key('reminder-last-date')),
            const SizedBox(height: 12),
            TextFormField(
              key: const Key('reminder-last-odometer'),
              controller: _lastOdo,
              keyboardType: TextInputType.number,
              decoration: InputDecoration(labelText: 'Odometer when last done (${distanceLabel(u.distance)})'),
            ),
          ],
        ),
      ),
    );
  }
}
