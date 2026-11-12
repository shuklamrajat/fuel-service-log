import 'package:intl/intl.dart';

import '../data/repository.dart';
import '../domain/engine.dart';

final _grouped = NumberFormat.decimalPattern();

String fmtDistance(int metres, Units u, {int decimals = 0}) =>
    '${_grouped.format(double.parse(formatHalfUp(distanceIn(metres, u.distance), decimals)))} ${distanceLabel(u.distance)}';

String fmtVolume(int ml, Units u) => '${formatHalfUp(volumeIn(ml, u.volume), 2)} ${volumeLabel(u.volume)}';

String fmtEconomy(int ml, int metres, Units u) =>
    '${formatHalfUp(economy(ml, metres, u.economy), 2)} ${economyLabel(u.economy)}';

String isoDate(DateTime d) => '${d.year}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';

String niceDate(DateTime d) => DateFormat('d MMM yyyy').format(d);

String shortDate(DateTime d) => DateFormat('d MMM').format(d);

DateTime? parseIsoDate(String s) {
  final m = RegExp(r'^\s*(\d{4})-(\d{1,2})-(\d{1,2})\s*$').firstMatch(s);
  if (m == null) return null;
  final y = int.parse(m.group(1)!), mo = int.parse(m.group(2)!), d = int.parse(m.group(3)!);
  final dt = DateTime(y, mo, d);
  return (dt.year == y && dt.month == mo && dt.day == d) ? dt : null;
}

double? parseNumber(String s) {
  final v = double.tryParse(s.trim().replaceAll(',', ''));
  return v == null || v.isNaN || v < 0 ? null : v;
}
