import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../app_state.dart';
import '../services/data_cache_service.dart';
import '../utils/aqi_utils.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});
  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
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
        _future = _loadData(_selected);
      });
    }
  }

  void _reload() {
    setState(() {
      _future = _forceReload(_selected);
      AppState.of(context).division.value = _selected;
    });
  }

  /// Load data using cache service (fast for subsequent calls)
  Future<Map<String, dynamic>> _loadData(String division) async {
    final cacheService = Provider.of<DataCacheService>(context, listen: false);
    return await cacheService.getEnhancedData(division);
  }

  /// Force reload data (bypasses cache)
  Future<Map<String, dynamic>> _forceReload(String division) async {
    final cacheService = Provider.of<DataCacheService>(context, listen: false);
    await cacheService.refreshData(division);
    await cacheService.refreshCSVData();
    return await cacheService.getEnhancedData(division);
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
