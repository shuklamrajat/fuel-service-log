import 'dart:typed_data';

import 'package:app_core/app_core.dart';

import '../data/repository.dart';
import '../domain/engine.dart';
import '../ui/format.dart';

class CostSummary {
  CostSummary({
    required this.fills,
    required this.services,
    required this.fuelCents,
    required this.serviceCents,
    required this.distanceM,
    required this.volumeMl,
  });
  final List<FillUp> fills;
  final List<Service> services;
  final int fuelCents;
  final int serviceCents;
  final int distanceM;
  final int volumeMl;
  int get totalCents => fuelCents + serviceCents;
}

/// Totals for entries dated in [from, toExclusive). Distance is the spread of
/// odometer readings in that window.
CostSummary summarizeCosts(List<FillUp> fills, List<Service> services, DateTime from, DateTime toExclusive) {
  bool inRange(DateTime d) => !d.isBefore(from) && d.isBefore(toExclusive);
  final f = fills.where((x) => inRange(x.date)).toList()..sort((a, b) => a.odometerM.compareTo(b.odometerM));
  final s = services.where((x) => inRange(x.date)).toList()..sort((a, b) => a.date.compareTo(b.date));
  final odos = [...f.map((x) => x.odometerM), ...s.map((x) => x.odometerM).whereType<int>()]..sort();
  return CostSummary(
    fills: f,
    services: s,
    fuelCents: f.fold(0, (a, x) => a + x.costCents),
    serviceCents: s.fold(0, (a, x) => a + x.costCents),
    distanceM: odos.length < 2 ? 0 : odos.last - odos.first,
    volumeMl: f.fold(0, (a, x) => a + x.volumeMl),
  );
}

String costPerDistanceText(CostSummary c, Units u, String currency) {
  if (c.distanceM <= 0) return '–';
  final perUnit = c.totalCents / distanceIn(c.distanceM, u.distance);
  return '${Money.format(perUnit.round(), currency: currency)}/${distanceLabel(u.distance)}';
}

String buildVehicleCsv(Vehicle v, CostSummary c, EconomyResult eco, Units u, String period) {
  final w = CsvWriter()
    ..row(['Vehicle', v.name, v.details])
    ..row(['Period', period])
    ..blank()
    ..row(['Fill-ups'])
    ..row([
      'Date', 'Odometer (${distanceLabel(u.distance)})', 'Fuel (${volumeLabel(u.volume)})', 'Total paid', 'Full tank',
      'Missed previous', 'Distance since last full (${distanceLabel(u.distance)})', 'Economy (${economyLabel(u.economy)})', 'Note'
    ]);
  for (final f in c.fills) {
    final seg = eco.segmentEndingAt('${f.id}');
    w.row([
      isoDate(f.date),
      formatHalfUp(distanceIn(f.odometerM, u.distance), 1),
      formatHalfUp(volumeIn(f.volumeMl, u.volume), 3),
      Money.plain(f.costCents),
      f.isFull ? 'yes' : 'no',
      f.missedPrevious ? 'yes' : 'no',
      seg == null ? '' : formatHalfUp(distanceIn(seg.distanceM, u.distance), 1),
      seg == null ? '' : formatHalfUp(economy(seg.volumeMl, seg.distanceM, u.economy), 2),
      f.note,
    ]);
  }
  w
    ..blank()
    ..row(['Services'])
    ..row(['Date', 'Odometer (${distanceLabel(u.distance)})', 'Service', 'Cost', 'Note']);
  for (final s in c.services) {
    w.row([
      isoDate(s.date),
      s.odometerM == null ? '' : formatHalfUp(distanceIn(s.odometerM!, u.distance), 1),
      s.title,
      Money.plain(s.costCents),
      s.note,
    ]);
  }
  w
    ..blank()
    ..row(['Fuel cost', Money.plain(c.fuelCents)])
    ..row(['Service cost', Money.plain(c.serviceCents)])
    ..row(['Total cost', Money.plain(c.totalCents)])
    ..row(['Distance (${distanceLabel(u.distance)})', formatHalfUp(distanceIn(c.distanceM, u.distance), 1)])
    ..row([
      'Average economy (${economyLabel(u.economy)})',
      eco.hasEconomy ? formatHalfUp(economy(eco.totalVolumeMl, eco.totalDistanceM, u.economy), 2) : ''
    ]);
  return w.build();
}

Future<Uint8List> buildVehiclePdf(
    Vehicle v, CostSummary c, EconomyResult eco, Units u, String period, String currency, DateTime now) {
  String m(int cents) => Money.format(cents, currency: currency);
  return buildPdfReport(
    title: 'Vehicle history: ${v.name}',
    meta: [if (v.details.isNotEmpty) v.details, 'Period: $period', 'Generated ${isoDate(now)}'],
    summary: [
      ('Fuel cost', m(c.fuelCents)),
      ('Service cost', m(c.serviceCents)),
      ('Total cost', m(c.totalCents)),
      ('Distance', fmtDistance(c.distanceM, u)),
      ('Cost per distance', costPerDistanceText(c, u, currency)),
      ('Average economy', eco.hasEconomy ? fmtEconomy(eco.totalVolumeMl, eco.totalDistanceM, u) : '–'),
    ],
    tables: [
      PdfTableSection(
        heading: 'Fill-ups',
        headers: ['Date', 'Odometer', 'Fuel', 'Paid', 'Economy'],
        columnAlignRight: const {1, 2, 3, 4},
        rows: [
          for (final f in c.fills)
            [
              isoDate(f.date),
              fmtDistance(f.odometerM, u),
              '${fmtVolume(f.volumeMl, u)}${f.isFull ? '' : ' (partial)'}',
              m(f.costCents),
              eco.segmentEndingAt('${f.id}') == null
                  ? (f.missedPrevious ? 'after missed' : '')
                  : fmtEconomy(eco.segmentEndingAt('${f.id}')!.volumeMl, eco.segmentEndingAt('${f.id}')!.distanceM, u),
            ],
        ],
      ),
      PdfTableSection(
        heading: 'Services',
        headers: const ['Date', 'Odometer', 'Service', 'Cost'],
        columnAlignRight: const {1, 3},
        rows: [
          for (final s in c.services)
            [isoDate(s.date), s.odometerM == null ? '' : fmtDistance(s.odometerM!, u), s.title, m(s.costCents)],
        ],
      ),
    ],
    footerNote: 'Made with Fuel & Service Log',
  );
}
