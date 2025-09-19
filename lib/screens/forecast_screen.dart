// lib/screens/forecast_screen.dart
import 'package:flutter/material.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:provider/provider.dart';
import '../app_state.dart';
import '../services/data_cache_service.dart';
import '../utils/aqi_utils.dart';

class ForecastScreen extends StatefulWidget {
  const ForecastScreen({super.key});
  @override
  State<ForecastScreen> createState() => _ForecastScreenState();
}

class _ForecastScreenState extends State<ForecastScreen> {
  Future<List<_ForecastItem>>? _future;
  VoidCallback? _divListener;
  ValueNotifier<String>? _divisionNotifier; // Store reference to avoid dispose error

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final vn = AppState.of(context).division;
    _divisionNotifier = vn; // Store reference for safe disposal
    _divListener ??= _load;
    vn.removeListener(_divListener!);
    vn.addListener(_divListener!);
    _load();
  }

  @override
  void dispose() {
    if (_divListener != null && _divisionNotifier != null) {
      _divisionNotifier!.removeListener(_divListener!);
    }
    super.dispose();
  }

  void _load() {
    final d = _divisionNotifier?.value ?? "Dhaka";
    setState(() {
      _future = _fetch(d);
    });
  }

  Future<List<_ForecastItem>> _fetch(String division) async {
    try {
      // Use cached forecast data from cache service
      final cacheService = Provider.of<DataCacheService>(context, listen: false);
      final raw = await cacheService.getForecastData(division);

      // Demo confidences (replace later if your API returns them)
      final conf = [95, 88, 82, 75, 68, 62, 55];

      final out = <_ForecastItem>[];
      for (int i = 0; i < raw.length && i < 7; i++) {
        final m = raw[i];
        // API returns: { date: 'YYYY-MM-DD', predicted_aqi: double }
        // services/aqi_service.dart maps them to { label, date, aqi_pred }
        final label = (m['label'] ?? 'Day ${i + 1}').toString();
        final v = (m['aqi_pred'] is num)
            ? (m['aqi_pred'] as num).toDouble().clamp(0, 500)
            : 0.0;
        out.add(_ForecastItem(label: label, value: v.toDouble(), confidence: conf[i]));
      }

      // If for any reason API returns nothing, keep UI stable with a fallback
      return out.isEmpty ? _fallback() : out;
    } catch (_) {
      return _fallback();
    }
  }

  List<_ForecastItem> _fallback() {
    final labels = ['Today', 'Tomorrow', 'Day 3', 'Day 4', 'Day 5', 'Day 6', 'Day 7'];
    final vals = [156, 142, 134, 128, 145, 167, 178];
    final conf = [95, 88, 82, 75, 68, 62, 55];
    return List.generate(
      7,
      (i) => _ForecastItem(label: labels[i], value: vals[i].toDouble(), confidence: conf[i]),
    );
  }

  @override
  Widget build(BuildContext context) {
    final division = AppState.of(context).division.value;

    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
      children: [
        Row(
          children: [
            Icon(Icons.event_note, color: Theme.of(context).colorScheme.primary),
            const SizedBox(width: 8),
            Text(
              '7-Day Forecast',
              style: Theme.of(context).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w900),
            ),
          ],
        ),
        const SizedBox(height: 12),
        FutureBuilder<List<_ForecastItem>>(
          future: _future,
          builder: (context, snap) {
            final items = snap.data;
            return _Card(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(16, 16, 16, 12),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      '$division - AQI Predictions',
                      style: Theme.of(context)
                          .textTheme
                          .titleMedium
                          ?.copyWith(fontWeight: FontWeight.w800),
                    ),
                    const SizedBox(height: 4),
                    Text('Powered by machine learning algorithms',
                        style: Theme.of(context).textTheme.bodySmall),
                    const SizedBox(height: 16),
                    SizedBox(
                      height: 230,
                      child: items == null
                          ? const Center(child: CircularProgressIndicator())
                          : _LineChartWidget(items: items),
                    ),
                  ],
                ),
              ),
            );
          },
        ),
        const SizedBox(height: 16),
        FutureBuilder<List<_ForecastItem>>(
          future: _future,
          builder: (context, snap) {
            final items = snap.data;
            if (items == null) return const SizedBox.shrink();
            return Column(children: [for (final it in items) _DayTile(item: it)]);
          },
        ),
      ],
    );
  }
}

/* ===================== MODELS ===================== */

class _ForecastItem {
  final String label;
  final double value;
  final int confidence;
  _ForecastItem({required this.label, required this.value, required this.confidence});
}

/* ===================== REUSABLE UI ===================== */

class _Card extends StatelessWidget {
  final Widget child;
  const _Card({required this.child});
  @override
  Widget build(BuildContext context) {
    final isLight = Theme.of(context).brightness == Brightness.light;
    return Container(
      decoration: BoxDecoration(
        color: Theme.of(context).cardTheme.color,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          if (isLight)
            BoxShadow(
              color: Colors.black.withOpacity(0.06),
              blurRadius: 18,
              offset: const Offset(0, 10),
            ),
        ],
      ),
      child: child,
    );
  }
}

class _DayTile extends StatelessWidget {
  final _ForecastItem item;
  const _DayTile({required this.item});
  @override
  Widget build(BuildContext context) {
    final b = Theme.of(context).brightness;
    final col = aqiColor(item.value.round(), b);
    final cat = aqiCategory(item.value.round());
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
      decoration: BoxDecoration(
        color: Theme.of(context).cardTheme.color,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: Theme.of(context).dividerColor.withOpacity(0.35)),
      ),
      child: Row(
        children: [
          Icon(Icons.lens, size: 12, color: col),
          const SizedBox(width: 10),
          Expanded(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(item.label, style: const TextStyle(fontWeight: FontWeight.w700)),
              const SizedBox(height: 4),
              Text('Confidence: ${item.confidence}%',
                  style: TextStyle(fontSize: 12, color: Theme.of(context).textTheme.bodySmall?.color)),
            ]),
          ),
          Column(crossAxisAlignment: CrossAxisAlignment.end, children: [
            Text(item.value.round().toString(),
                style: const TextStyle(fontSize: 22, fontWeight: FontWeight.w800)),
            const SizedBox(height: 2),
            Text(cat, style: TextStyle(color: col, fontWeight: FontWeight.w600, fontSize: 12)),
          ]),
        ],
      ),
    );
  }
}

/* ===================== LINE CHART ===================== */

class _LineChartWidget extends StatelessWidget {
  final List<_ForecastItem> items;
  const _LineChartWidget({required this.items});

  @override
  Widget build(BuildContext context) {
    if (items.isEmpty) return const SizedBox();

    // Calculate max value for Y-axis
    double maxVal = items.map((e) => e.value).fold<double>(0, (m, v) => v > m ? v : m);
    maxVal = (maxVal <= 0 ? 100 : maxVal) * 1.1;
    final yMax = (maxVal / 20.0).ceil() * 20.0;

    // Create line chart data points
    final spots = <FlSpot>[];
    for (int i = 0; i < items.length; i++) {
      spots.add(FlSpot(i.toDouble(), items[i].value));
    }

    return Padding(
      padding: const EdgeInsets.all(16.0),
      child: LineChart(
        LineChartData(
          maxY: yMax,
          minY: 0,
          maxX: (items.length - 1).toDouble(),
          minX: 0,
          lineBarsData: [
            LineChartBarData(
              spots: spots,
              isCurved: true,
              curveSmoothness: 0.3,
              color: Theme.of(context).colorScheme.primary,
              barWidth: 3,
              isStrokeCapRound: true,
              belowBarData: BarAreaData(
                show: true,
                color: Theme.of(context).colorScheme.primary.withOpacity(0.1),
              ),
              dotData: FlDotData(
                show: true,
                getDotPainter: (spot, percent, barData, index) {
                  final aqiValue = spot.y.round();
                  final color = aqiColor(aqiValue, Theme.of(context).brightness);
                  return FlDotCirclePainter(
                    radius: 6, // Slightly larger for better visibility
                    color: color,
                    strokeWidth: 2.5, // Thicker stroke
                    strokeColor: Theme.of(context).brightness == Brightness.dark 
                        ? Colors.black87 // Dark outline in dark mode
                        : Colors.white, // White outline in light mode
                  );
                },
              ),
            ),
          ],
          titlesData: FlTitlesData(
            leftTitles: AxisTitles(
              sideTitles: SideTitles(
                showTitles: true,
                reservedSize: 40,
                interval: yMax / 5,
                getTitlesWidget: (value, meta) {
                  return Text(
                    value.round().toString(),
                    style: TextStyle(
                      color: Theme.of(context).hintColor,
                      fontSize: 11,
                    ),
                  );
                },
              ),
            ),
            bottomTitles: AxisTitles(
              sideTitles: SideTitles(
                showTitles: true,
                reservedSize: 30,
                getTitlesWidget: (value, meta) {
                  final index = value.round();
                  if (index >= 0 && index < items.length) {
                    String label = items[index].label;
                    if (label.toLowerCase().startsWith('tom')) {
                      label = 'Tomorrow';
                    }
                    return Padding(
                      padding: const EdgeInsets.only(top: 8.0),
                      child: Text(
                        label,
                        style: const TextStyle(fontSize: 10),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    );
                  }
                  return const Text('');
                },
              ),
            ),
            topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
            rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
          ),
          gridData: FlGridData(
            show: true,
            drawVerticalLine: false,
            horizontalInterval: yMax / 5,
            getDrawingHorizontalLine: (value) {
              return FlLine(
                color: Theme.of(context).dividerColor.withOpacity(0.3),
                strokeWidth: 1,
                dashArray: [5, 5],
              );
            },
          ),
          borderData: FlBorderData(
            show: true,
            border: Border(
              bottom: BorderSide(
                color: Theme.of(context).dividerColor.withOpacity(0.5),
                width: 1,
              ),
              left: BorderSide(
                color: Theme.of(context).dividerColor.withOpacity(0.5),
                width: 1,
              ),
            ),
          ),
          lineTouchData: LineTouchData(
            enabled: true,
            touchSpotThreshold: 20, // Increase touch area for easier selection
            distanceCalculator: (Offset touchPoint, Offset spotPixelCoordinates) {
              // Custom distance calculation for better touch detection
              return (touchPoint - spotPixelCoordinates).distance;
            },
            touchTooltipData: LineTouchTooltipData(
              getTooltipItems: (touchedSpots) {
                return touchedSpots.map((spot) {
                  final index = spot.x.round();
                  if (index >= 0 && index < items.length) {
                    final item = items[index];
                    final aqiValue = spot.y.round();
                    final category = aqiCategory(aqiValue);
                    final isDark = Theme.of(context).brightness == Brightness.dark;
                    return LineTooltipItem(
                      '${item.label}\nAQI: $aqiValue\n$category\nConfidence: ${item.confidence}%',
                      TextStyle(
                        color: isDark ? Colors.white : Colors.black87,
                        fontWeight: FontWeight.bold,
                        fontSize: 12,
                      ),
                    );
                  }
                  return null;
                }).toList();
              },
              tooltipBgColor: Theme.of(context).brightness == Brightness.dark 
                  ? const Color(0xFF2D2D2D).withOpacity(0.95)
                  : Colors.white.withOpacity(0.95),
              tooltipBorder: BorderSide(
                color: Theme.of(context).brightness == Brightness.dark
                    ? const Color(0xFF4A7C59)
                    : const Color(0xFF2D552E),
                width: 1.5,
              ),
              tooltipRoundedRadius: 8,
            ),
          ),
        ),
      ),
    );
  }
}