import 'package:app_core/app_core.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../data/repository.dart';
import '../domain/engine.dart';
import 'costs_tab.dart';
import 'edit_screens.dart';
import 'format.dart';
import 'service_tab.dart';
import 'units_section.dart';

class HomeScreen extends ConsumerStatefulWidget {
  const HomeScreen({super.key});

  @override
  ConsumerState<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends ConsumerState<HomeScreen> {
  int _tab = 0;

  @override
  Widget build(BuildContext context) {
    final vehicles = ref.watch(vehiclesProvider).value;
    final v = ref.watch(currentVehicleProvider);
    if (vehicles == null) return const Scaffold(body: Center(child: CircularProgressIndicator()));
    if (vehicles.isEmpty || v == null) {
      return Scaffold(
        appBar: AppBar(title: Text(ref.watch(appConfigProvider).appName)),
        body: EmptyState(
          icon: Icons.directions_car_outlined,
          title: 'Add your vehicle',
          body: 'Give it a name you will recognise, like "Civic" or "Work van".',
          action: FilledButton(
            key: const Key('add-first-vehicle'),
            onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const VehicleEditScreen())),
            child: const Text('Add vehicle'),
          ),
        ),
      );
    }
    return Scaffold(
      appBar: AppBar(
        title: DropdownButton<int>(
          key: const Key('vehicle-switcher'),
          value: v.id,
          underline: const SizedBox.shrink(),
          items: [
            for (final x in vehicles) DropdownMenuItem(value: x.id, child: Text(x.name)),
            const DropdownMenuItem(value: -1, child: Text('+ Add vehicle')),
          ],
          onChanged: (id) async {
            if (id == null) return;
            if (id == -1) {
              if (!await requirePro(context, ref, 'multiple_vehicles')) return;
              if (!context.mounted) return;
              await Navigator.push(context, MaterialPageRoute(builder: (_) => const VehicleEditScreen()));
              return;
            }
            await ref.read(selectedVehicleIdProvider.notifier).select(id);
          },
        ),
        actions: [
          IconButton(
            key: const Key('open-settings'),
            icon: const Icon(Icons.settings_outlined),
            onPressed: () => Navigator.push(context,
                MaterialPageRoute(builder: (_) => const CoreSettingsScreen(appSection: [UnitsSection()]))),
          ),
        ],
      ),
      body: IndexedStack(index: _tab, children: [FuelTab(vehicle: v), ServiceTab(vehicle: v), CostsTab(vehicle: v)]),
      floatingActionButton: switch (_tab) {
        0 => FloatingActionButton.extended(
            key: const Key('add-fill'),
            icon: const Icon(Icons.local_gas_station),
            label: const Text('Add fill-up'),
            onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (_) => FillEditScreen(vehicle: v))),
          ),
        1 => FloatingActionButton.extended(
            key: const Key('add-service'),
            icon: const Icon(Icons.build),
            label: const Text('Log service'),
            onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (_) => ServiceEditScreen(vehicle: v))),
          ),
        _ => null,
      },
      bottomNavigationBar: NavigationBar(
        selectedIndex: _tab,
        onDestinationSelected: (i) => setState(() => _tab = i),
        destinations: const [
          NavigationDestination(key: Key('tab-fuel'), icon: Icon(Icons.local_gas_station_outlined), label: 'Fuel'),
          NavigationDestination(key: Key('tab-service'), icon: Icon(Icons.build_outlined), label: 'Service'),
          NavigationDestination(key: Key('tab-costs'), icon: Icon(Icons.payments_outlined), label: 'Costs'),
        ],
      ),
    );
  }
}

class FuelTab extends ConsumerWidget {
  const FuelTab({super.key, required this.vehicle});
  final Vehicle vehicle;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final fills = ref.watch(fillsProvider(vehicle.id)).value ?? const <FillUp>[];
    final eco = ref.watch(economyProvider(vehicle.id));
    final units = ref.watch(unitsProvider);
    final currency = ref.watch(coreSettingsProvider).currency;
    if (fills.isEmpty) {
      return const EmptyState(
        icon: Icons.local_gas_station_outlined,
        title: 'No fill-ups yet',
        body: 'Fill the tank to the top and log it. Economy shows from the second full tank.',
      );
    }
    final last = eco?.segments.isNotEmpty == true ? eco!.segments.last : null;
    return ListView(padding: const EdgeInsets.only(bottom: 96), children: [
      Card(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Wrap(spacing: 24, runSpacing: 12, children: [
            StatTile(
              label: 'Average',
              value: eco != null && eco.hasEconomy ? fmtEconomy(eco.totalVolumeMl, eco.totalDistanceM, units) : '–',
              valueKey: const Key('avg-economy'),
            ),
            StatTile(
              label: 'Last tank',
              value: last == null ? '–' : fmtEconomy(last.volumeMl, last.distanceM, units),
              valueKey: const Key('last-economy'),
            ),
            StatTile(
              label: 'Odometer',
              value: fmtDistance(ref.watch(currentOdometerProvider(vehicle.id)) ?? 0, units),
              valueKey: const Key('odometer'),
            ),
          ]),
        ),
      ),
      for (final f in fills)
        Card(
          child: ListTile(
            key: Key('fill-${f.id}'),
            title: Text('${niceDate(f.date)} · ${fmtDistance(f.odometerM, units)}'),
            subtitle: Text(_subtitle(f, eco, units)),
            trailing: Text(Money.format(f.costCents, currency: currency)),
            onTap: () => Navigator.push(
                context, MaterialPageRoute(builder: (_) => FillEditScreen(vehicle: vehicle, fill: f))),
          ),
        ),
    ]);
  }

  String _subtitle(FillUp f, EconomyResult? eco, Units units) {
    final parts = [fmtVolume(f.volumeMl, units)];
    final seg = eco?.segmentEndingAt('${f.id}');
    if (seg != null) parts.add(fmtEconomy(seg.volumeMl, seg.distanceM, units));
    if (!f.isFull) parts.add('partial');
    if (f.missedPrevious) parts.add('after a missed fill-up');
    return parts.join(' · ');
  }
}
