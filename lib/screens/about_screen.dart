import 'package:flutter/material.dart';

class AboutScreen extends StatelessWidget {
  const AboutScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          // Header
          Row(
            children: [
              Icon(
                Icons.info_outline,
                color: Theme.of(context).colorScheme.primary,
              ),
              const SizedBox(width: 8),
              Text(
                "About AQI",
                style: Theme.of(
                  context,
                ).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold),
              ),
            ],
          ),
          const SizedBox(height: 16),

          // AQI explanation card
          _Card(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  "What is Air Quality Index (AQI)?",
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  "The Air Quality Index (AQI) is a standardized way to measure and communicate air pollution levels to the public. It translates complex air quality data into simple numbers and colors that everyone can understand.",
                  style: Theme.of(context).textTheme.bodyMedium,
                ),
                const SizedBox(height: 16),

                _aqiLevel(
                  "Good (0-50)",
                  "Air quality is satisfactory",
                  Colors.green,
                ),
                _aqiLevel(
                  "Moderate (51-100)",
                  "Acceptable for most people",
                  Colors.yellow[700]!,
                ),
                _aqiLevel(
                  "Unhealthy for Sensitive Groups (101-150)",
                  "May affect sensitive individuals",
                  Colors.orange,
                ),
                _aqiLevel(
                  "Unhealthy (151-200)",
                  "Everyone may experience health effects",
                  Colors.deepOrange,
                ),
                _aqiLevel(
                  "Very Unhealthy (201-300)",
                  "Health alert for everyone",
                  Colors.red,
                ),
                _aqiLevel(
                  "Hazardous (301+)",
                  "Emergency conditions",
                  Colors.purple,
                ),
              ],
            ),
          ),

          const SizedBox(height: 16),

          // Predictions card
          _Card(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  "How Our Predictions Work",
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  "Our AQI predictions use advanced machine learning algorithms that analyze:",
                  style: Theme.of(context).textTheme.bodyMedium,
                ),
                const SizedBox(height: 12),

                _bullet("Historical air quality data from monitoring stations"),
                _bullet("Weather patterns and meteorological conditions"),
                _bullet("Seasonal trends and pollution sources"),
                _bullet("Traffic patterns and industrial activities"),
                _bullet("Satellite imagery and atmospheric data"),
                const SizedBox(height: 12),

                Text(
                  "The model is continuously updated with real-time data to improve accuracy. Confidence levels indicate the reliability of each prediction.",
                  style: Theme.of(context).textTheme.bodyMedium,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _aqiLevel(String title, String subtitle, Color color) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        children: [
          Icon(Icons.circle, color: color, size: 14),
          const SizedBox(width: 8),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: const TextStyle(fontWeight: FontWeight.bold),
                ),
                Text(subtitle, style: const TextStyle(fontSize: 12)),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _bullet(String text) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [const Text("•  "), Expanded(child: Text(text))],
      ),
    );
  }
}

class _Card extends StatelessWidget {
  final Widget child;
  const _Card({required this.child});

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF1E1E1E) : Colors.white,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          if (!isDark)
            BoxShadow(
              color: Colors.black.withOpacity(0.05),
              blurRadius: 8,
              offset: const Offset(0, 3),
            ),
        ],
      ),
      child: child,
    );
  }
}
