import 'dart:convert';
import 'package:csv/csv.dart';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:intl/intl.dart';
import '../app_state.dart';
import '../services/api_service.dart';
import '../utils/aqi_utils.dart';

/// CSV export URL - same as trends screen
const _csvUrl =
    'https://docs.google.com/spreadsheets/d/1aRyCU88momwOk_ONhXXzjbm0-9uoCQrRWVQlQOrTM48/export?format=csv';

/// Normalize city labels that appear in the sheet.
const Map<String, String> _cityFix = {
  'Chittagong': 'Chattogram',
  'Barisal': 'Barishal',
};

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});
  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  final _api = ApiService();

  final _divisions = const [
    'Dhaka','Chattogram','Rajshahi','Khulna',
    'Barishal','Sylhet','Rangpur','Mymensingh',
  ];

  Future<Map<String, dynamic>>? _future;
  String _selected = 'Dhaka';

  @override
  void initState() {
    super.initState();
    // Use global division value if available
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final globalDivision = AppState.of(context).division.value;
      setState(() {
        _selected = globalDivision;
        _future = _loadData(_selected);
      });
    });
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    // Always sync _selected with global division
    final globalDivision = AppState.of(context).division.value;
    if (_selected != globalDivision) {
      setState(() {
        _selected = globalDivision;
      });
    }
  }

  void _reload() {
    setState(() {
      _future = _loadData(_selected);
      AppState.of(context).division.value = _selected;
    });
  }

  /// Load both current API data and CSV historical data
  Future<Map<String, dynamic>> _loadData(String division) async {
    try {
      // Load current AQI from API
      final currentData = await _api.fetchCurrent(division);
      
      // Load CSV data for historical calculations
      final csvData = await _loadCsv();
      
      // Calculate weekly average and last dataset value
      final end = csvData.maxDate;
      final start = end.subtract(const Duration(days: 6)); // 7 days total
      
      // Get weekly average using same method as trends screen
      final weeklyValues = csvData.valuesForCityBetween(division, start, end);
      final weeklyAvg = weeklyValues.isEmpty ? null : 
          weeklyValues.reduce((a, b) => a + b) / weeklyValues.length;
      
      // Get last available dataset value for 24h change
      final lastDatasetValue = csvData.getLastValueForCity(division);
      
      return {
        ...currentData,
        'weekly_avg': weeklyAvg?.round(),
        'last_dataset_value': lastDatasetValue?.round(),
        'dataset_date': end,
      };
    } catch (e) {
      // Fallback to API-only data
      return await _api.fetchCurrent(division);
    }
  }

  /// Load CSV data - same logic as trends screen
  Future<_Dataset> _loadCsv() async {
    final resp = await http.get(Uri.parse(_csvUrl));
    if (resp.statusCode != 200) throw Exception('HTTP ${resp.statusCode}');
    final rows = const CsvToListConverter(eol: '\n').convert(utf8.decode(resp.bodyBytes));

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

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context);
    final isDark = t.brightness == Brightness.dark;

    // Dropdown styling that works in both themes
    final inputDecoration = InputDecoration(
      isDense: true,
      filled: true,
      fillColor: isDark ? const Color(0xFF232323) : Colors.white,
      border: const OutlineInputBorder(
        borderSide: BorderSide(color: Color(0xFFE6E8EC)),
        borderRadius: BorderRadius.all(Radius.circular(12)),
      ),
      enabledBorder: OutlineInputBorder(
        borderSide: BorderSide(color: isDark ? const Color(0xFF3A3A3A) : const Color(0xFFE6E8EC)),
        borderRadius: const BorderRadius.all(Radius.circular(12)),
      ),
      contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
    );

    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
      children: [
        // top row: selector + refresh
        Row(
          children: [
            Icon(Icons.location_on_outlined,
                size: 20, color: isDark ? Colors.white70 : const Color(0xFF2563EB)),
            const SizedBox(width: 8),
            Expanded(
              child: DropdownButtonFormField<String>(
                value: AppState.of(context).division.value,
                isExpanded: true,
                decoration: inputDecoration,
                dropdownColor: isDark ? const Color(0xFF2B2B2B) : Colors.white,
                iconEnabledColor: isDark ? Colors.white70 : Colors.black87,
                style: TextStyle(
                  color: isDark ? Colors.white : Colors.black87,
                  fontSize: 14,
                ),
                items: _divisions
                    .map((d) => DropdownMenuItem(
                          value: d,
                          child: Text(d, overflow: TextOverflow.ellipsis),
                        ))
                    .toList(),
                onChanged: (v) {
                  if (v == null) return;
                  setState(() {
                    _selected = v;
                    AppState.of(context).division.value = v;
                  });
                  _reload();
                },
              ),
            ),
            IconButton(
              onPressed: _reload,
              icon: const Icon(Icons.refresh_rounded),
              tooltip: 'Refresh',
            )
          ],
        ),

        const SizedBox(height: 16),

        // Current AQI card
        Card(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 18, 16, 16),
            child: FutureBuilder<Map<String, dynamic>>(
              future: _future,
              builder: (context, snap) {
                if (snap.connectionState == ConnectionState.waiting) {
                  return const SizedBox(
                    height: 160, child: Center(child: CircularProgressIndicator()),
                  );
                }
                if (!snap.hasData) {
                  return const Padding(
                    padding: EdgeInsets.all(16),
                    child: Text('No data available'),
                  );
                }

                final m = snap.data!;
                final int? aqi = m['aqi'] is num ? (m['aqi'] as num).toInt() : null;
                final station = (m['station'] ?? _selected).toString();
                final updated = (m['updated_at'] ?? '').toString();
                
                // Extract historical data from CSV
                final int? weeklyAvg = m['weekly_avg'];
                final int? lastDatasetValue = m['last_dataset_value'];

                final color = aqiColor(aqi, t.brightness);
                final tips = aqiHealthTips(aqi);

                // Calculate 24-hour change using current AQI vs last dataset value
                String change24h = '—';
                Color change24hColor = Colors.grey;
                if (aqi != null && lastDatasetValue != null) {
                  final diff = aqi - lastDatasetValue;
                  if (diff > 0) {
                    change24h = '+$diff';
                    change24hColor = Colors.red;
                  } else if (diff < 0) {
                    change24h = '$diff';
                    change24hColor = Colors.green;
                  } else {
                    change24h = '0';
                    change24hColor = Colors.grey;
                  }
                }

                // Format weekly average
                String weeklyAvgStr = weeklyAvg != null ? '$weeklyAvg' : '—';

                return Column(
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    const Text('Current Air Quality',
                        style: TextStyle(fontSize: 20, fontWeight: FontWeight.w700)),
                    const SizedBox(height: 4),
                    Text(station,
                        style: TextStyle(fontSize: 13, color: t.textTheme.bodySmall?.color)),
                    const SizedBox(height: 12),
                    Text(
                      aqi == null ? '—' : '$aqi',
                      style: TextStyle(
                        fontSize: 64, fontWeight: FontWeight.w800, color: color, height: 0.9),
                    ),
                    const SizedBox(height: 8),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                      decoration: BoxDecoration(
                        color: color.withOpacity(0.12),
                        borderRadius: BorderRadius.circular(24),
                        border: Border.all(color: color.withOpacity(0.35)),
                      ),
                      child: Text(aqiCategory(aqi),
                          style: TextStyle(color: color, fontWeight: FontWeight.w700)),
                    ),
                    const SizedBox(height: 12),
                    Text(
                      updated.isEmpty ? 'Last updated: —' : 'Last updated: $updated',
                      style: TextStyle(fontSize: 12, color: t.textTheme.bodySmall?.color),
                    ),

                    const SizedBox(height: 16),

                    // stat tiles
                    Row(
                      children: [
                        Expanded(child: _StatTile(
                          icon: Icons.trending_up, 
                          title: '24h Change', 
                          value: change24h,
                          valueColor: change24hColor,
                        )),
                        const SizedBox(width: 12),
                        Expanded(child: _StatTile(
                          icon: Icons.bar_chart_rounded, 
                          title: 'Weekly Avg', 
                          value: weeklyAvgStr,
                          valueColor: const Color(0xFF2563EB),
                        )),
                      ],
                    ),

                    const SizedBox(height: 16),

                    // Health Recommendations (dynamic)
                    Align(
                      alignment: Alignment.centerLeft,
                      child: Text('Health Recommendations',
                          style: TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.w700,
                              color: t.colorScheme.onSurface)),
                    ),
                    const SizedBox(height: 8),
                    _TipsCard(tips: tips, dark: isDark),
                  ],
                );
              },
            ),
          ),
        ),
      ],
    );
  }
}

class _StatTile extends StatelessWidget {
  final IconData icon;
  final String title;
  final String value;
  final Color valueColor;
  const _StatTile({
    required this.icon,
    required this.title,
    required this.value,
    required this.valueColor,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final border = Border.all(
      color: isDark ? const Color(0xFF333333) : const Color(0xFFE5E7EB),
    );
    return Container(
      height: 86,
      decoration: BoxDecoration(
        color: Theme.of(context).cardTheme.color,
        borderRadius: BorderRadius.circular(16),
        border: border,
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(icon, color: const Color(0xFF2563EB)),
          const SizedBox(width: 10),
          Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text(title,
                  style: TextStyle(
                    fontSize: 12,
                    color: Theme.of(context).textTheme.bodySmall?.color,
                  )),
              const SizedBox(height: 6),
              Text(value,
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700, color: valueColor)),
            ],
          ),
        ],
      ),
    );
  }
}

class _TipsCard extends StatelessWidget {
  final List<String> tips;
  final bool dark;
  const _TipsCard({required this.tips, required this.dark});

  @override
  Widget build(BuildContext context) {
    final bg = dark ? const Color(0xFF1F1F1F) : Colors.white;
    final border = dark ? const Color(0xFF333333) : const Color(0xFFE5E7EB);
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(16, 14, 16, 10),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: tips
            .map((t) => Padding(
                  padding: const EdgeInsets.only(bottom: 8),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Padding(
                        padding: EdgeInsets.only(top: 5),
                        child: Icon(Icons.circle, size: 6),
                      ),
                      const SizedBox(width: 8),
                      Expanded(child: Text(t)),
                    ],
                  ),
                ))
            .toList(),
      ),
    );
  }
}

// ---------------- Helper classes for CSV data ----------------

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

  /// Get the last available AQI value for a city
  double? getLastValueForCity(String city) {
    for (int i = rows.length - 1; i >= 0; i--) {
      final row = rows[i];
      if (row.city == city && row.aqi != null) {
        return row.aqi;
      }
    }
    return null;
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
