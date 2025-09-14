import 'dart:convert';
import 'package:csv/csv.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:intl/intl.dart';

import '../app_state.dart';
import '../utils/aqi_utils.dart';

/// CSV export URL
const _csvUrl =
    'https://docs.google.com/spreadsheets/d/1aRyCU88momwOk_ONhXXzjbm0-9uoCQrRWVQlQOrTM48/export?format=csv';

/// Normalize city labels that appear in the sheet.
const Map<String, String> _cityFix = {
  'Chittagong': 'Chattogram',
  'Barisal': 'Barishal',
};

/// Divisions to show in the comparison list
const _divisions = <String>[
  'Dhaka',
  'Chattogram',
  'Rajshahi',
  'Khulna',
  'Barishal',
  'Sylhet',
  'Rangpur',
  'Mymensingh',
];

class TrendsScreen extends StatefulWidget {
  const TrendsScreen({super.key});
  @override
  State<TrendsScreen> createState() => _TrendsScreenState();
}

class _TrendsScreenState extends State<TrendsScreen> {
  late Future<_Dataset> _future;
  int _modeDays = 7; // 7 or 30

  @override
  void initState() {
    super.initState();
    _future = _loadCsv();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 16),
      children: [
        Row(
          children: [
            Text(
              'AQI Trends',
              style: theme.textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w700),
            ),
            const Spacer(),
            DropdownButton<int>(
              value: _modeDays,
              underline: Container(height: 2, color: theme.dividerColor),
              items: const [
                DropdownMenuItem(value: 7, child: Text('7 Days')),
                DropdownMenuItem(value: 30, child: Text('30 Days')),
              ],
              onChanged: (v) => setState(() => _modeDays = v ?? 7),
            ),
          ],
        ),
        const SizedBox(height: 12),

        // ---- Chart card ----
        ValueListenableBuilder<String>(
          valueListenable: AppState.of(context).division,
          builder: (context, division, _) {
            return FutureBuilder<_Dataset>(
              future: _future,
              builder: (context, s) {
                if (s.connectionState == ConnectionState.waiting) {
                  return const _Card(
                    child: SizedBox(
                      height: 230,
                      child: Center(child: CircularProgressIndicator()),
                    ),
                  );
                }
                if (s.hasError || s.data == null) {
                  return _Card(
                    child: Padding(
                      padding: const EdgeInsets.all(16),
                      child: Text('Failed to load CSV: ${s.error}'),
                    ),
                  );
                }

                final ds = s.data!;
                final end = ds.maxDate;
                final start = end.subtract(Duration(days: _modeDays - 1));

                final windowDates = List<DateTime>.generate(
                  _modeDays,
                  (i) => DateTime(end.year, end.month, end.day)
                      .subtract(Duration(days: _modeDays - 1 - i)),
                );

                // Map day -> AQI (skip DNA) for selected division
                final byDate = ds.mapForCity(division, start, end);

                // x labels
                final xLabels = windowDates
                    .map((d) => _modeDays == 7
                        ? DateFormat('EEE').format(d)
                        : DateFormat('d/MM').format(d))
                    .toList();

                // Plot spots only where AQI exists (skip DNA)
                final spots = <FlSpot>[];
                for (int i = 0; i < windowDates.length; i++) {
                  final v = byDate[windowDates[i]];
                  if (v != null) spots.add(FlSpot(i.toDouble(), v));
                }

                // y range from actual plotted points
                final yVals = spots.map((s) => s.y).toList();
                double minY = 0, maxY = 300;
                if (yVals.isNotEmpty) {
                  final lo = yVals.reduce((a, b) => a < b ? a : b);
                  final hi = yVals.reduce((a, b) => a > b ? a : b);
                  minY = (lo - 10).clamp(0, 500);
                  maxY = (hi + 10).clamp(minY + 50, 500);
                  if (maxY - minY < 60) maxY = minY + 60;
                }

                final avg = yVals.isEmpty ? null : yVals.reduce((a, b) => a + b) / yVals.length;
                final minV = yVals.isEmpty ? null : yVals.reduce((a, b) => a < b ? a : b);
                final maxV = yVals.isEmpty ? null : yVals.reduce((a, b) => a > b ? a : b);

                return _Card(
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(14, 16, 12, 14),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          '$division — Past $_modeDays Days ',
                          style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700),
                        ),
                        const SizedBox(height: 10),
                        SizedBox(
                          height: 220,
                          child: LineChart(
                            LineChartData(
                              minX: 0,
                              maxX: (windowDates.length - 1).toDouble(),
                              minY: minY,
                              maxY: maxY,
                              gridData: FlGridData(
                                show: true,
                                drawVerticalLine: true,
                                horizontalInterval: (maxY - minY) / 4,
                                getDrawingHorizontalLine: (_) => FlLine(
                                  color: theme.brightness == Brightness.dark
                                      ? Colors.white12
                                      : const Color(0xFFCBD5E1),
                                  strokeWidth: 1,
                                  dashArray: const [6, 6],
                                ),
                                getDrawingVerticalLine: (_) => FlLine(
                                  color: theme.brightness == Brightness.dark
                                      ? Colors.white12
                                      : const Color(0xFFCBD5E1),
                                  strokeWidth: 1,
                                  dashArray: const [6, 6],
                                ),
                              ),
                              titlesData: FlTitlesData(
                                topTitles:
                                    const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                                rightTitles:
                                    const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                                leftTitles: AxisTitles(
                                  sideTitles: SideTitles(
                                    showTitles: true,
                                    reservedSize: 34,
                                    interval: (maxY - minY) / 4,
                                    getTitlesWidget: (v, _) => Text(
                                      v.toInt().toString(),
                                      style: TextStyle(
                                        fontSize: 11,
                                        color: theme.textTheme.bodySmall?.color,
                                      ),
                                    ),
                                  ),
                                ),
                                bottomTitles: AxisTitles(
                                  sideTitles: SideTitles(
                                    showTitles: true,
                                    interval: 1,
                                    getTitlesWidget: (v, _) {
                                      final i = v.round().clamp(0, xLabels.length - 1);
                                      final show = _modeDays == 7 || i % 5 == 0;
                                      return Padding(
                                        padding: const EdgeInsets.only(top: 6),
                                        child: Text(
                                          show ? xLabels[i] : '',
                                          style: TextStyle(
                                            fontSize: 11,
                                            color: theme.textTheme.bodySmall?.color,
                                          ),
                                        ),
                                      );
                                    },
                                  ),
                                ),
                              ),
                              lineBarsData: [
                                LineChartBarData(
                                  spots: spots,
                                  isCurved: true,
                                  barWidth: 3,
                                  dotData: FlDotData(show: true),
                                  color: const Color(0xFF06B6D4),
                                ),
                              ],
                              borderData: FlBorderData(
                                show: true,
                                border: Border.all(
                                  color: theme.brightness == Brightness.dark
                                      ? Colors.white10
                                      : const Color(0xFFE5E7EB),
                                  width: 1,
                                ),
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(height: 10),
                        _StatsRow(avg: avg, minV: minV, maxV: maxV),
                      ],
                    ),
                  ),
                );
              },
            );
          },
        ),

        const SizedBox(height: 16),
        const Text(
          'City Comparison (7 Days Avg.)',
          style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700),
        ),
        const SizedBox(height: 8),

        // ---- 7-day averages per division ----
        FutureBuilder<_Dataset>(
          future: _future,
          builder: (context, s) {
            if (s.connectionState == ConnectionState.waiting) {
              return const _Card(
                child:
                    SizedBox(height: 120, child: Center(child: CircularProgressIndicator())),
              );
            }
            if (s.hasError || s.data == null) {
              return _Card(
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Text('Failed to load CSV: ${s.error}'),
                ),
              );
            }

            final ds = s.data!;
            final end = ds.maxDate;
            final start = end.subtract(const Duration(days: 6));

            return _Card(
              child: Column(
                children: _divisions.map((div) {
                  // collect non-DNA values only
                  final vals = ds.valuesForCityBetween(div, start, end);
                  final avg =
                      vals.isEmpty ? null : vals.reduce((a, b) => a + b) / vals.length;

                  final color =
                      aqiColor(avg?.round(), Theme.of(context).brightness);
                  final cat = aqiCategory(avg?.round());

                  return ListTile(
                    contentPadding:
                        const EdgeInsets.symmetric(horizontal: 16, vertical: 2),
                    leading: CircleAvatar(backgroundColor: color, radius: 7),
                    title: Text(div),
                    trailing: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: [
                        Text(
                          avg == null ? '—' : avg.toStringAsFixed(0),
                          style: const TextStyle(
                              fontSize: 16, fontWeight: FontWeight.w700),
                        ),
                        Text(
                          cat,
                          style: TextStyle(
                            fontSize: 12,
                            color: Theme.of(context).textTheme.bodySmall?.color,
                          ),
                        ),
                      ],
                    ),
                  );
                }).toList(),
              ),
            );
          },
        ),
      ],
    );
  }

  // ---------------- CSV loading & dataset ----------------

  Future<_Dataset> _loadCsv() async {
    final resp = await http.get(Uri.parse(_csvUrl));
    if (resp.statusCode != 200) throw Exception('HTTP ${resp.statusCode}');
    final rows =
        const CsvToListConverter(eol: '\n').convert(utf8.decode(resp.bodyBytes));

    if (rows.isEmpty) return _Dataset(const [], DateTime.now());

    final header = rows.first.map((e) => e.toString().trim()).toList();
    final hasHeader = _looksLikeHeader(header);

    final data = <_Row>[];
    for (int i = hasHeader ? 1 : 0; i < rows.length; i++) {
      final r = rows[i];
      if (r.isEmpty) continue;

      DateTime? date;
      String? city;
      double? aqi;

      if (hasHeader) {
        final m = <String, String>{};
        for (int j = 0; j < r.length && j < header.length; j++) {
          m[header[j].toLowerCase()] = r[j].toString().trim();
        }
        date = _parseDate(m['date']);
        city = (m['city'] ?? m['district'] ?? m['division'])?.trim();
        final raw = m['aqi'];
        if (raw != null && raw.isNotEmpty && raw.toUpperCase() != 'DNA') {
          final n = num.tryParse(raw);
          if (n != null) aqi = n.toDouble();
        }
      } else {
        // Fallback: [date, city, AQI, ...]
        date = _parseDate(r[0].toString());
        if (r.length > 1) city = r[1].toString().trim();
        if (r.length > 2) {
          final s = r[2].toString().trim();
          if (s.isNotEmpty && s.toUpperCase() != 'DNA') {
            final n = num.tryParse(s);
            if (n != null) aqi = n.toDouble();
          }
        }
      }

      if (date == null || city == null) continue;
      final normCity = _cityFix[city] ?? city;

      // normalize to day
      final d = DateTime(date.year, date.month, date.day);

      data.add(_Row(date: d, city: normCity, aqi: aqi)); // aqi may be null
    }

    if (data.isEmpty) return _Dataset(const [], DateTime.now());

    data.sort((a, b) => a.date.compareTo(b.date));
    final maxDate = data.last.date; // true latest date in the sheet
    return _Dataset(data, maxDate);
  }
}

// ---------------- models & helpers ----------------

class _Row {
  final DateTime date;
  final String city;
  final double? aqi; // null when DNA/empty
  const _Row({required this.date, required this.city, required this.aqi});
}

class _Dataset {
  final List<_Row> rows; // sorted by date asc
  final DateTime maxDate;
  const _Dataset(this.rows, this.maxDate);

  /// Map day -> AQI for [city] in [start..end] inclusive; skips DNA.
  /// If multiple entries per day exist, keeps the last one.
  Map<DateTime, double> mapForCity(String city, DateTime start, DateTime end) {
    final out = <DateTime, double>{};
    for (final r in rows) {
      if (r.city != city) continue;
      if (r.date.isBefore(start) || r.date.isAfter(end)) continue;
      if (r.aqi == null) continue;
      out[r.date] = r.aqi!; // last one wins
    }
    return out;
  }

  /// Non-null AQI values for [city] within [start..end] inclusive.
  List<double> valuesForCityBetween(String city, DateTime start, DateTime end) {
    final seen = <DateTime>{};
    final vals = <double>[];
    for (final r in rows) {
      if (r.city != city) continue;
      if (r.date.isBefore(start) || r.date.isAfter(end)) continue;
      if (r.aqi == null) continue;
      // avoid double-counting if multiple rows in same day
      if (seen.add(r.date)) vals.add(r.aqi!);
    }
    return vals;
  }
}

bool _looksLikeHeader(List<String> header) {
  final h = header.map((e) => e.toLowerCase()).toList();
  return h.contains('date') &&
      (h.contains('city') || h.contains('district') || h.contains('division')) &&
      h.contains('aqi');
}

/// IMPORTANT: Your sheet uses MM/dd/yyyy (e.g., 09/07/2025 = Sep 7, 2025).
/// Prefer MM/dd first to avoid interpreting as 9 July.
DateTime? _parseDate(String? s) {
  if (s == null || s.isEmpty) return null;
  final fmts = [
    DateFormat('MM/dd/yyyy'), // <-- prefer this for your sheet
    DateFormat('yyyy-MM-dd'),
    DateFormat('dd-MM-yyyy'),
    DateFormat('dd/MM/yyyy'),
  ];
  for (final f in fmts) {
    try {
      return f.parseStrict(s);
    } catch (_) {}
  }
  return null;
}

// ---------------- small UI bits ----------------

class _Card extends StatelessWidget {
  final Widget child;
  const _Card({required this.child});
  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Container(
      decoration: BoxDecoration(
        color: Theme.of(context).cardTheme.color,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: isDark ? const Color(0xFF333333) : const Color(0xFFE5E7EB),
        ),
      ),
      child: child,
    );
  }
}

class _StatsRow extends StatelessWidget {
  final double? avg, minV, maxV;
  const _StatsRow({required this.avg, required this.minV, required this.maxV});

  String _fmt(double? v) => v == null ? '—' : v.toStringAsFixed(0);

  @override
  Widget build(BuildContext context) {
    TextStyle label() => TextStyle(
          fontSize: 12,
          color: Theme.of(context).textTheme.bodySmall?.color,
        );
    const value = TextStyle(fontSize: 16, fontWeight: FontWeight.w700);

    return Padding(
      padding: const EdgeInsets.only(top: 6, bottom: 2),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
        children: [
          Column(children: [Text('Avg', style: label()), const SizedBox(height: 4), Text(_fmt(avg), style: value)]),
          Column(children: [Text('Min', style: label()), const SizedBox(height: 4), Text(_fmt(minV), style: value)]),
          Column(children: [Text('Max', style: label()), const SizedBox(height: 4), Text(_fmt(maxV), style: value)]),
        ],
      ),
    );
  }
}
