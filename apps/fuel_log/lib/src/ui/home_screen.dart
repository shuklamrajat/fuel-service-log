import 'dart:math' as math;

import 'package:app_core/app_core.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../data/repository.dart';
import '../domain/engine.dart';
import 'costs_tab.dart';
import 'edit_screens.dart';
import 'format.dart';
import 'scenes.dart';
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
          scene: newCarScene,
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
            onPressed: () => Navigator.push(
              context,
              MaterialPageRoute(builder: (_) => const CoreSettingsScreen(appSection: [UnitsSection()])),
            ),
          ),
        ],
      ),
      body: IndexedStack(
        index: _tab,
        children: [
          FuelTab(vehicle: v),
          ServiceTab(vehicle: v),
          CostsTab(vehicle: v),
        ],
      ),
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
      bottomNavigationBar: AdDock(
        child: NavigationBar(
          selectedIndex: _tab,
          onDestinationSelected: (i) => setState(() => _tab = i),
          destinations: const [
            NavigationDestination(key: Key('tab-fuel'), icon: Icon(Icons.local_gas_station_outlined), label: 'Fuel'),
            NavigationDestination(key: Key('tab-service'), icon: Icon(Icons.build_outlined), label: 'Service'),
            NavigationDestination(key: Key('tab-costs'), icon: Icon(Icons.payments_outlined), label: 'Costs'),
          ],
        ),
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
        scene: gaugeScene,
        title: 'No fill-ups yet',
        body: 'Fill the tank to the top and log it. Economy shows from the second full tank.',
      );
    }
    final last = eco?.segments.isNotEmpty == true ? eco!.segments.last : null;
    final theme = Theme.of(context);
    final brand = BrandColors.of(context);
    final byId = {for (final f in fills) '${f.id}': f};
    final hasEco = eco != null && eco.hasEconomy;
    return ListView(
      padding: const EdgeInsets.only(bottom: 96),
      children: [
        BrandPanel(
          child: Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('AVERAGE ECONOMY', style: _overline(brand)),
                    const SizedBox(height: 2),
                    FittedBox(
                      fit: BoxFit.scaleDown,
                      alignment: Alignment.centerLeft,
                      child: Text(
                        hasEco ? fmtEconomy(eco.totalVolumeMl, eco.totalDistanceM, units) : '–',
                        key: const Key('avg-economy'),
                        style: theme.textTheme.headlineMedium?.copyWith(
                          color: brand.onBrand,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                    ),
                    const SizedBox(height: 12),
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: [
                        _BrandChip(
                          icon: Icons.local_gas_station_rounded,
                          label: 'Last tank',
                          value: last == null ? '–' : fmtEconomy(last.volumeMl, last.distanceM, units),
                          valueKey: const Key('last-economy'),
                        ),
                        _BrandChip(
                          icon: Icons.speed_rounded,
                          label: 'Odometer',
                          value: fmtDistance(ref.watch(currentOdometerProvider(vehicle.id)) ?? 0, units),
                          valueKey: const Key('odometer'),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              SizedBox(
                width: 92,
                height: 92,
                child: AnimatedScene(paint: (c, s, f) => _panelGauge(c, s, f, brand.onBrand), aspectRatio: 1),
              ),
            ],
          ),
        ),
        if (eco != null && eco.segments.isNotEmpty)
          Card(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(12, 14, 12, 8),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Padding(
                    padding: const EdgeInsets.only(left: 4, bottom: 4),
                    child: Text('Economy per tank', style: theme.textTheme.titleSmall),
                  ),
                  AnimatedLineChart(
                    key: const Key('economy-chart'),
                    color: brand.accent,
                    points: [
                      for (final seg in eco.segments)
                        (shortDate(byId[seg.endId]!.date), economy(seg.volumeMl, seg.distanceM, units.economy)),
                    ],
                    valueLabel: (v) => formatHalfUp(v, 1),
                    semanticsLabel:
                        'Economy per tank. ${[for (final seg in eco.segments) '${shortDate(byId[seg.endId]!.date)} ${fmtEconomy(seg.volumeMl, seg.distanceM, units)}'].join('. ')}.',
                  ),
                ],
              ),
            ),
          ),
        SectionHeader('Fill-ups', trailing: Text('${fills.length}', style: theme.textTheme.labelLarge)),
        for (final (i, f) in fills.indexed)
          Appear(
            index: i,
            child: Card(
              child: ListTile(
                key: Key('fill-${f.id}'),
                leading: IconBadge(
                  icon: f.isFull ? Icons.local_gas_station_rounded : Icons.water_drop_outlined,
                  color: f.isFull ? theme.colorScheme.primary : brand.accent,
                  size: 40,
                ),
                title: Text(
                  '${niceDate(f.date)} · ${fmtDistance(f.odometerM, units)}',
                  style: const TextStyle(fontWeight: FontWeight.w600),
                ),
                subtitle: Text(_subtitle(f, eco, units)),
                trailing: Text(
                  Money.format(f.costCents, currency: currency),
                  style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w800),
                ),
                onTap: () => Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => FillEditScreen(vehicle: vehicle, fill: f),
                  ),
                ),
              ),
            ),
          ),
      ],
    );
  }

  static TextStyle _overline(BrandColors brand) => TextStyle(
    color: brand.onBrand.withValues(alpha: 0.75),
    fontSize: 11,
    fontWeight: FontWeight.w700,
    letterSpacing: 1.2,
  );

  String _subtitle(FillUp f, EconomyResult? eco, Units units) {
    final parts = [fmtVolume(f.volumeMl, units)];
    final seg = eco?.segmentEndingAt('${f.id}');
    if (seg != null) parts.add(fmtEconomy(seg.volumeMl, seg.distanceM, units));
    if (!f.isFull) parts.add('partial');
    if (f.missedPrevious) parts.add('after a missed fill-up');
    return parts.join(' · ');
  }
}

/// The little dial in the hero panel: the needle swings up when the screen
/// opens, then idles.
void _panelGauge(Canvas c, Size s, SceneFrame f, Color ink) {
  final o = Offset(s.width / 2, s.height * 0.6);
  final r = s.width * 0.42;
  final arc = Rect.fromCircle(center: o, radius: r);
  c.drawArc(arc, math.pi * 0.85, math.pi * 1.3, false, Ink2.stroke(ink.withValues(alpha: 0.25), 8));
  final level = phase(f.intro, 0.1, 0.9, Curves.easeOutBack) * 0.72 + 0.02 * f.wave();
  c.drawArc(arc, math.pi * 0.85, math.pi * 1.3 * level, false, Ink2.stroke(f.brand.accent, 8));
  final a = math.pi * 0.85 + math.pi * 1.3 * level;
  c.drawLine(o, o + Offset(math.cos(a), math.sin(a)) * r * 0.7, Ink2.stroke(ink, 4));
  c.drawCircle(o, 6, Ink2.fill(ink));
}

class _BrandChip extends StatelessWidget {
  const _BrandChip({required this.icon, required this.label, required this.value, this.valueKey});
  final IconData icon;
  final String label;
  final String value;
  final Key? valueKey;

  @override
  Widget build(BuildContext context) {
    final brand = BrandColors.of(context);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(color: brand.onBrand.withValues(alpha: 0.15), borderRadius: BorderRadius.circular(99)),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 14, color: brand.onBrand),
          const SizedBox(width: 5),
          Text('$label ', style: TextStyle(color: brand.onBrand.withValues(alpha: 0.8), fontSize: 12)),
          Text(
            value,
            key: valueKey,
            style: TextStyle(color: brand.onBrand, fontWeight: FontWeight.w800, fontSize: 12),
          ),
        ],
      ),
    );
  }
}
