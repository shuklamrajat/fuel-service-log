import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../data/repository.dart';
import '../domain/engine.dart';

class UnitsSection extends ConsumerWidget {
  const UnitsSection({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final u = ref.watch(unitsProvider);
    final n = ref.read(unitsProvider.notifier);
    return Column(
      children: [
        ListTile(
          leading: const Icon(Icons.straighten),
          title: const Text('Distance'),
          trailing: DropdownButton<DistanceUnit>(
            key: const Key('unit-distance'),
            value: u.distance,
            items: const [
              DropdownMenuItem(value: DistanceUnit.km, child: Text('Kilometres')),
              DropdownMenuItem(value: DistanceUnit.mi, child: Text('Miles')),
            ],
            onChanged: (v) => n.set(distance: v),
          ),
        ),
        ListTile(
          leading: const Icon(Icons.water_drop_outlined),
          title: const Text('Fuel'),
          trailing: DropdownButton<VolumeUnit>(
            key: const Key('unit-volume'),
            value: u.volume,
            items: const [
              DropdownMenuItem(value: VolumeUnit.l, child: Text('Litres')),
              DropdownMenuItem(value: VolumeUnit.galUs, child: Text('US gallons')),
              DropdownMenuItem(value: VolumeUnit.galUk, child: Text('UK gallons')),
            ],
            onChanged: (v) => n.set(volume: v),
          ),
        ),
        ListTile(
          leading: const Icon(Icons.speed),
          title: const Text('Economy'),
          trailing: DropdownButton<EconomyUnit>(
            key: const Key('unit-economy'),
            value: u.economy,
            items: const [
              DropdownMenuItem(value: EconomyUnit.lPer100km, child: Text('L/100 km')),
              DropdownMenuItem(value: EconomyUnit.kmPerL, child: Text('km/L')),
              DropdownMenuItem(value: EconomyUnit.mpgUs, child: Text('mpg (US)')),
              DropdownMenuItem(value: EconomyUnit.mpgUk, child: Text('mpg (UK)')),
            ],
            onChanged: (v) => n.set(economy: v),
          ),
        ),
      ],
    );
  }
}
