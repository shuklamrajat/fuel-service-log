import 'package:app_core/app_core.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../app.dart';
import '../data/repository.dart';
import '../export/vehicle_export.dart';
import 'format.dart';

enum CostPeriod { thisMonth, last3Months, thisYear, allTime }

class CostsTab extends ConsumerStatefulWidget {
  const CostsTab({super.key, required this.vehicle});
  final Vehicle vehicle;

  @override
  ConsumerState<CostsTab> createState() => _CostsTabState();
}

class _CostsTabState extends ConsumerState<CostsTab> {
  CostPeriod _period = CostPeriod.allTime;

  (DateTime, DateTime, String) _range(DateTime now) {
    final tomorrow = DateTime(now.year, now.month, now.day + 1);
    return switch (_period) {
      CostPeriod.thisMonth => (DateTime(now.year, now.month), tomorrow, 'This month'),
      CostPeriod.last3Months => (DateTime(now.year, now.month - 3, now.day + 1), tomorrow, 'Last 3 months'),
      CostPeriod.thisYear => (DateTime(now.year), tomorrow, 'This year'),
      CostPeriod.allTime => (DateTime(1900), DateTime(2200), 'All time'),
    };
  }

  Future<void> _export(CostSummary c, String period, {required bool pdf}) async {
    if (!await requirePro(context, ref, featureExport)) return;
    final v = widget.vehicle;
    final u = ref.read(unitsProvider);
    final eco = ref.read(economyProvider(v.id))!;
    final ex = ref.read(exportServiceProvider);
    final base = 'vehicle_${v.name}_${period.replaceAll(' ', '_').toLowerCase()}';
    final file = pdf
        ? await ex.writePdf('$base.pdf',
            await buildVehiclePdf(v, c, eco, u, period, ref.read(coreSettingsProvider).currency, ref.read(clockProvider)()))
        : await ex.writeCsv('$base.csv', buildVehicleCsv(v, c, eco, u, period));
    await ex.share(file, subject: '${v.name} history');
    await ref.read(ratingPrompterProvider).recordCompletedTask();
  }

  @override
  Widget build(BuildContext context) {
    final v = widget.vehicle;
    final fills = ref.watch(fillsProvider(v.id)).value ?? const <FillUp>[];
    final services = ref.watch(servicesProvider(v.id)).value ?? const <Service>[];
    final units = ref.watch(unitsProvider);
    final currency = ref.watch(coreSettingsProvider).currency;
    final (from, to, label) = _range(ref.watch(clockProvider)());
    final c = summarizeCosts(fills, services, from, to);
    String m(int cents) => Money.format(cents, currency: currency);

    return ListView(padding: const EdgeInsets.only(bottom: 32), children: [
      Padding(
        padding: const EdgeInsets.all(12),
        child: Wrap(spacing: 8, runSpacing: 8, children: [
          for (final (p, l) in const [
            (CostPeriod.thisMonth, 'This month'),
            (CostPeriod.last3Months, 'Last 3 months'),
            (CostPeriod.thisYear, 'This year'),
            (CostPeriod.allTime, 'All time'),
          ])
            ChoiceChip(
              key: Key('cost-period-${p.name}'),
              label: Text(l),
              selected: _period == p,
              onSelected: (_) => setState(() => _period = p),
            ),
        ]),
      ),
      Card(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Wrap(spacing: 24, runSpacing: 12, children: [
            StatTile(label: 'Total', value: m(c.totalCents), valueKey: const Key('cost-total')),
            StatTile(label: 'Fuel', value: m(c.fuelCents), valueKey: const Key('cost-fuel')),
            StatTile(label: 'Service', value: m(c.serviceCents), valueKey: const Key('cost-service')),
            StatTile(label: 'Distance', value: fmtDistance(c.distanceM, units), valueKey: const Key('cost-distance')),
            StatTile(
                label: 'Per distance',
                value: costPerDistanceText(c, units, currency),
                valueKey: const Key('cost-per-distance')),
          ]),
        ),
      ),
      Padding(
        padding: const EdgeInsets.all(12),
        child: Row(children: [
          Expanded(
            child: OutlinedButton.icon(
              key: const Key('export-csv'),
              icon: const Icon(Icons.table_chart_outlined),
              label: const Text('CSV'),
              onPressed: c.fills.isEmpty && c.services.isEmpty ? null : () => _export(c, label, pdf: false),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: FilledButton.icon(
              key: const Key('export-pdf'),
              icon: const Icon(Icons.picture_as_pdf_outlined),
              label: const Text('PDF history'),
              onPressed: c.fills.isEmpty && c.services.isEmpty ? null : () => _export(c, label, pdf: true),
            ),
          ),
        ]),
      ),
    ]);
  }
}
