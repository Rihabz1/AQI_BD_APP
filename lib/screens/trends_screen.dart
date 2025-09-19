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

                // y range from actual plotted points with enhanced spacing for close values
                final yVals = spots.map((s) => s.y).toList();
                double minY = 0, maxY = 300;
                if (yVals.isNotEmpty) {
                  final lo = yVals.reduce((a, b) => a < b ? a : b);
                  final hi = yVals.reduce((a, b) => a > b ? a : b);
                  final range = hi - lo;
                  
                  // Much more aggressive spacing for close values
                  double padding;
                  double minRange;
                  
                  if (range <= 10) {
                    // Very close values (like 143, 148 or 33, 36) - maximum spacing
                    padding = 35;
                    minRange = 150;
                  } else if (range <= 20) {
                    // Close values - high spacing
                    padding = 25;
                    minRange = 120;
                  } else if (range <= 40) {
                    // Moderately close - medium spacing
                    padding = 20;
                    minRange = 100;
                  } else {
                    // Normal spacing
                    padding = 15;
                    minRange = 80;
                  }
                  
                  minY = (lo - padding).clamp(0, 500);
                  maxY = (hi + padding).clamp(minY + 50, 500);
                  
                  // Ensure minimum range for visual separation
                  if (maxY - minY < minRange) {
                    final center = (lo + hi) / 2;
                    minY = (center - minRange / 2).clamp(0, 500);
                    maxY = minY + minRange;
                  }
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
                          height: 240,
                          child: _TrendsLineChart(
                            spots: spots,
                            xLabels: xLabels,
                            windowDates: windowDates,
                            modeDays: _modeDays,
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

// NEW CLEAN LINE CHART IMPLEMENTATION
class _TrendsLineChart extends StatelessWidget {
  final List<FlSpot> spots;
  final List<String> xLabels;
  final List<DateTime> windowDates;
  final int modeDays;

  const _TrendsLineChart({
    required this.spots,
    required this.xLabels,
    required this.windowDates,
    required this.modeDays,
  });

  @override
  Widget build(BuildContext context) {
    if (spots.isEmpty) {
      return Center(
        child: Text(
          'No data available',
          style: TextStyle(
            color: Theme.of(context).textTheme.bodyMedium?.color,
            fontSize: 16,
          ),
        ),
      );
    }

    // Get min and max values from the data
    final yValues = spots.map((spot) => spot.y).toList();
    final minValue = yValues.reduce((a, b) => a < b ? a : b);
    final maxValue = yValues.reduce((a, b) => a > b ? a : b);

    // Create equal regions by dividing the full range
    final range = maxValue - minValue;
    final padding = range * 0.15; // 15% padding on each side
    
    final minY = (minValue - padding).clamp(0.0, double.infinity);
    final maxY = maxValue + padding;
    
    // Ensure we have at least 5 equal divisions
    final totalRange = maxY - minY;
    final divisions = 5;
    final gridInterval = totalRange / divisions;

    return Padding(
      padding: const EdgeInsets.all(16.0),
      child: LineChart(
        LineChartData(
          minX: 0,
          maxX: (spots.length - 1).toDouble(),
          minY: minY,
          maxY: maxY,
          
          // Grid configuration - equal divisions
          gridData: FlGridData(
            show: true,
            drawVerticalLine: false,
            horizontalInterval: gridInterval,
            getDrawingHorizontalLine: (value) => FlLine(
              color: Theme.of(context).dividerColor.withOpacity(0.3),
              strokeWidth: 1,
              dashArray: [5, 5],
            ),
          ),

          // Axis titles
          titlesData: FlTitlesData(
            topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
            rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
            
            leftTitles: AxisTitles(
              sideTitles: SideTitles(
                showTitles: true,
                reservedSize: 45,
                interval: gridInterval,
                getTitlesWidget: (value, meta) => Text(
                  value.round().toString(),
                  style: TextStyle(
                    fontSize: 11,
                    color: Theme.of(context).hintColor,
                  ),
                ),
              ),
            ),
            
            bottomTitles: AxisTitles(
              sideTitles: SideTitles(
                showTitles: true,
                reservedSize: 35,
                interval: 1,
                getTitlesWidget: (value, meta) {
                  final index = value.round();
                  if (index < 0 || index >= xLabels.length) return const Text('');
                  
                  final shouldShow = modeDays == 7 || index % (modeDays ~/ 6).clamp(1, 7) == 0;
                  return Padding(
                    padding: const EdgeInsets.only(top: 8),
                    child: Text(
                      shouldShow ? xLabels[index] : '',
                      style: const TextStyle(fontSize: 10),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  );
                },
              ),
            ),
          ),

          // Line configuration
          lineBarsData: [
            LineChartBarData(
              spots: spots,
              isCurved: true,
              curveSmoothness: 0.35,
              color: Theme.of(context).colorScheme.primary,
              barWidth: 3.5,
              isStrokeCapRound: true,
              
              // Gradient fill below line
              belowBarData: BarAreaData(
                show: true,
                color: Theme.of(context).colorScheme.primary.withOpacity(0.12),
              ),
              
              // Enhanced dots - consistent size for equal regions
              dotData: FlDotData(
                show: true,
                getDotPainter: (spot, percent, barData, index) {
                  final aqiValue = spot.y.round();
                  final dotColor = aqiColor(aqiValue, Theme.of(context).brightness);
                  
                  // Use consistent dot size since we have equal regions
                  return FlDotCirclePainter(
                    radius: 7.0,
                    color: dotColor,
                    strokeWidth: 3.0,
                    strokeColor: Theme.of(context).brightness == Brightness.dark 
                        ? Colors.black87 
                        : Colors.white,
                  );
                },
              ),
            ),
          ],

          // Border styling
          borderData: FlBorderData(
            show: true,
            border: Border(
              bottom: BorderSide(
                color: Theme.of(context).dividerColor.withOpacity(0.6),
                width: 1.5,
              ),
              left: BorderSide(
                color: Theme.of(context).dividerColor.withOpacity(0.6),
                width: 1.5,
              ),
            ),
          ),

          // Interactive tooltips
          lineTouchData: LineTouchData(
            enabled: true,
            touchSpotThreshold: 25,
            
            touchTooltipData: LineTouchTooltipData(
              getTooltipItems: (touchedSpots) {
                return touchedSpots.map((spot) {
                  final index = spot.x.round();
                  if (index < 0 || index >= windowDates.length) return null;
                  
                  final aqiValue = spot.y.round();
                  final category = aqiCategory(aqiValue);
                  final date = windowDates[index];
                  final isDark = Theme.of(context).brightness == Brightness.dark;
                  
                  final dateLabel = modeDays == 7 
                      ? DateFormat('EEE').format(date)
                      : '${date.day}/${date.month}';
                  
                  return LineTooltipItem(
                    '$dateLabel\nAQI: $aqiValue\n$category',
                    TextStyle(
                      color: isDark ? Colors.white : Colors.black87,
                      fontWeight: FontWeight.bold,
                      fontSize: 12,
                      height: 1.4,
                    ),
                  );
                }).where((item) => item != null).cast<LineTooltipItem>().toList();
              },
              
              tooltipBgColor: Theme.of(context).brightness == Brightness.dark 
                  ? const Color(0xFF2D2D2D).withOpacity(0.95)
                  : Colors.white.withOpacity(0.95),
                  
              tooltipBorder: BorderSide(
                color: Theme.of(context).brightness == Brightness.dark
                    ? const Color(0xFF4A7C59)
                    : const Color(0xFF2D552E),
                width: 2,
              ),
              
              tooltipRoundedRadius: 10,
              tooltipPadding: const EdgeInsets.all(12),
            ),
          ),
        ),
      ),
    );
  }
}
