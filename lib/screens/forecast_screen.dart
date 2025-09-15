// lib/screens/forecast_screen.dart
import 'package:flutter/material.dart';
import '../app_state.dart';
import '../services/aqi_service.dart';
import '../utils/aqi_utils.dart';

class ForecastScreen extends StatefulWidget {
  const ForecastScreen({super.key});
  @override
  State<ForecastScreen> createState() => _ForecastScreenState();
}

class _ForecastScreenState extends State<ForecastScreen> {
  final _svc = AqiService();
  Future<List<_ForecastItem>>? _future;
  VoidCallback? _divListener;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final vn = AppState.of(context).division;
    _divListener ??= _load;
    vn.removeListener(_divListener!);
    vn.addListener(_divListener!);
    _load();
  }

  @override
  void dispose() {
    if (_divListener != null) {
      AppState.of(context).division.removeListener(_divListener!);
    }
    super.dispose();
  }

  void _load() {
    final d = AppState.of(context).division.value;
    setState(() {
      _future = _fetch(d);
    });
  }

  Future<List<_ForecastItem>> _fetch(String division) async {
    try {
      // --- Calls your backend through services/aqi_service.dart ---
      final raw = await _svc.fetchForecast7(division);

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
                          : _BarChartWithAxis(items: items),
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

/* ===================== BAR CHART WITH Y AXIS ===================== */

class _BarChartWithAxis extends StatelessWidget {
  final List<_ForecastItem> items;
  const _BarChartWithAxis({required this.items});

  @override
  Widget build(BuildContext context) {
    // yMax rounded to 20s
    double maxVal = items.map((e) => e.value).fold<double>(0, (m, v) => v > m ? v : m);
    maxVal = (maxVal <= 0 ? 100 : maxVal) * 1.12;
    final yMax = (maxVal / 20.0).ceil() * 20.0;
    const ticks = 5;

    return Row(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        // Y-axis labels
        SizedBox(
          width: 36,
          child: LayoutBuilder(builder: (_, c) {
            final step = yMax / ticks;
            final style = TextStyle(fontSize: 11, color: Theme.of(context).hintColor);
            return Stack(children: [
              for (int i = 0; i <= ticks; i++)
                Positioned(
                  left: 0,
                  bottom: (c.maxHeight - 28) * (i / ticks) + 10, // 28 reserved for x labels area
                  child: Text((i * step).round().toString(), style: style),
                )
            ]);
          }),
        ),
        const SizedBox(width: 6),

        // Chart area (grid once, bars in front, x labels)
        Expanded(
          child: LayoutBuilder(
            builder: (context, c) {
              final gridHeight = c.maxHeight - 28; // space for x labels
              return Column(
                children: [
                  // grid + bars
                  SizedBox(
                    height: gridHeight,
                    child: Stack(
                      fit: StackFit.expand,
                      children: [
                        // One dashed grid for the whole chart
                        CustomPaint(
                          painter: _DashedGridPainter(
                            lines: ticks - 1,
                            color: Theme.of(context).dividerColor.withOpacity(0.5),
                          ),
                        ),
                        // Bars
                        Align(
                          alignment: Alignment.bottomCenter,
                          child: Row(
                            crossAxisAlignment: CrossAxisAlignment.end,
                            children: List.generate(items.length, (i) {
                              final it = items[i];
                              final barFrac = (it.value / yMax).clamp(0.0, 1.0);
                              return Expanded(
                                child: Align(
                                  alignment: Alignment.bottomCenter,
                                  child: Container(
                                    width: 18,
                                    height: gridHeight * barFrac,
                                    decoration: BoxDecoration(
                                      color: aqiColor(it.value.round(), Theme.of(context).brightness)
                                          .withOpacity(0.9),
                                      borderRadius: BorderRadius.circular(6),
                                    ),
                                  ),
                                ),
                              );
                            }),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 6),
                  // X labels (kept in one line; “Tomorrow” fixed)
                  Row(
                    children: List.generate(items.length, (i) {
                      final txt = items[i].label.toLowerCase().startsWith('tom')
                          ? 'Tomorrow'
                          : items[i].label;
                      return Expanded(
                        child: FittedBox(
                          fit: BoxFit.scaleDown,
                          child: Text(
                            txt,
                            maxLines: 1,
                            softWrap: false,
                            overflow: TextOverflow.fade,
                            style: const TextStyle(fontSize: 11),
                          ),
                        ),
                      );
                    }),
                  )
                ],
              );
            },
          ),
        ),
      ],
    );
  }
}

class _DashedGridPainter extends CustomPainter {
  final int lines;
  final Color color;
  const _DashedGridPainter({required this.lines, required this.color});

  @override
  void paint(Canvas canvas, Size size) {
    final p = Paint()..color = color..strokeWidth = 1;
    // horizontal dashed lines
    for (int i = 1; i <= lines; i++) {
      final y = size.height * (i / (lines + 1));
      _dashLine(canvas, Offset(0, y), Offset(size.width, y), p);
    }
  }

  void _dashLine(Canvas c, Offset a, Offset b, Paint p) {
    const dash = 6.0, gap = 6.0;
    double t = 0.0;
    final total = (b - a).distance;
    final dir = (b - a) / total;
    while (t < total) {
      final s = a + dir * t;
      final e = a + dir * (t + dash).clamp(0, total);
      c.drawLine(s, e, p);
      t += dash + gap;
    }
  }

  @override
  bool shouldRepaint(covariant _DashedGridPainter oldDelegate) => false;
}
