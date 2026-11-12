import 'package:app_core/app_core.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

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
        ? await ex.writePdf(
            '$base.pdf',
            await buildVehiclePdf(
              v,
              c,
              eco,
              u,
              period,
              ref.read(coreSettingsProvider).currency,
              ref.read(clockProvider)(),
            ),
          )
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

    return ListView(
      padding: const EdgeInsets.only(bottom: 32),
      children: [
        Padding(
          padding: const EdgeInsets.all(12),
          child: Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
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
            ],
          ),
        ),
        _CostHero(c: c, money: m),
        Card(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Row(
              children: [
                Expanded(
                  child: StatTile(
                    label: 'Distance',
                    value: fmtDistance(c.distanceM, units),
                    valueKey: const Key('cost-distance'),
                  ),
                ),
                Expanded(
                  child: StatTile(
                    label: 'Per distance',
                    value: costPerDistanceText(c, units, currency),
                    valueKey: const Key('cost-per-distance'),
                  ),
                ),
              ],
            ),
          ),
        ),
        Card(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(12, 14, 12, 12),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Padding(
                  padding: const EdgeInsets.only(left: 4, bottom: 8),
                  child: Text('Spend by month', style: Theme.of(context).textTheme.titleSmall),
                ),
                _MonthChart(c: c, now: ref.watch(clockProvider)(), money: m),
              ],
            ),
          ),
        ),
        Padding(
          padding: const EdgeInsets.all(12),
          child: Row(
            children: [
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
            ],
          ),
        ),
      ],
    );
  }
}

/// Total spend counting up, and a ring of fuel against service.
class _CostHero extends StatelessWidget {
  const _CostHero({required this.c, required this.money});
  final CostSummary c;
  final String Function(int) money;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final brand = BrandColors.of(context);
    final fuelColor = brand.onBrand;
    final serviceColor = brand.accent;
    String pct(int part) => c.totalCents == 0 ? '0%' : '${(part * 100 / c.totalCents).round()}%';
    final over = TextStyle(
      color: brand.onBrand.withValues(alpha: 0.75),
      fontSize: 11,
      fontWeight: FontWeight.w700,
      letterSpacing: 1.2,
    );
    Widget legend(Color col, String label, int cents, Key key) => Padding(
      padding: const EdgeInsets.only(top: 6),
      child: Row(
        children: [
          Container(
            width: 10,
            height: 10,
            decoration: BoxDecoration(color: col, shape: BoxShape.circle),
          ),
          const SizedBox(width: 8),
          Text('$label ', style: TextStyle(color: brand.onBrand.withValues(alpha: 0.8))),
          Text(
            money(cents),
            key: key,
            style: TextStyle(color: brand.onBrand, fontWeight: FontWeight.w800),
          ),
        ],
      ),
    );
    return BrandPanel(
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('TOTAL SPENT', style: over),
                CountUpText(
                  value: c.totalCents.toDouble(),
                  format: (v) => money(v.round()),
                  textKey: const Key('cost-total'),
                  style: theme.textTheme.headlineMedium?.copyWith(color: brand.onBrand, fontWeight: FontWeight.w800),
                ),
                const SizedBox(height: 6),
                legend(fuelColor, 'Fuel', c.fuelCents, const Key('cost-fuel')),
                legend(serviceColor, 'Service', c.serviceCents, const Key('cost-service')),
              ],
            ),
          ),
          AnimatedDonut(
            key: const Key('cost-split'),
            size: 104,
            thickness: 14,
            parts: [ChartPart(c.fuelCents.toDouble(), fuelColor), ChartPart(c.serviceCents.toDouble(), serviceColor)],
            semanticsLabel:
                'Fuel ${money(c.fuelCents)}, ${pct(c.fuelCents)}. Service ${money(c.serviceCents)}, ${pct(c.serviceCents)}.',
            center: Icon(Icons.directions_car_rounded, color: brand.onBrand, size: 30),
          ),
        ],
      ),
    );
  }
}

/// The last six months up to today, fuel and service stacked.
class _MonthChart extends StatelessWidget {
  const _MonthChart({required this.c, required this.now, required this.money});
  final CostSummary c;
  final DateTime now;
  final String Function(int) money;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final brand = BrandColors.of(context);
    final bars = <BarDatum>[];
    final spoken = <String>[];
    for (var k = 5; k >= 0; k--) {
      final m = DateTime(now.year, now.month - k);
      bool inMonth(DateTime d) => d.year == m.year && d.month == m.month;
      final fuel = c.fills.where((f) => inMonth(f.date)).fold(0, (a, f) => a + f.costCents);
      final service = c.services.where((s) => inMonth(s.date)).fold(0, (a, s) => a + s.costCents);
      final name = DateFormat.MMM().format(m);
      bars.add(
        BarDatum(name, [
          ChartPart(fuel / 100, scheme.primary),
          ChartPart(service / 100, brand.accent),
        ], highlight: k == 0),
      );
      spoken.add(
        fuel + service == 0
            ? '$name nothing'
            : '$name ${money(fuel + service)}: fuel ${money(fuel)}, service ${money(service)}',
      );
    }
    return AnimatedBarChart(
      key: const Key('month-chart'),
      bars: bars,
      valueLabel: (v) => v.round().toString(),
      semanticsLabel: 'Spend by month. ${spoken.join('. ')}.',
    );
  }
}
