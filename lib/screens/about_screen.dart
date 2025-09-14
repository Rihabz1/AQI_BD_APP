import 'package:flutter/material.dart';

class AboutScreen extends StatelessWidget {
  const AboutScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text("About")),
      body: const Padding(
        padding: EdgeInsets.all(16.0),
        child: Text(
          "AQI BD App\n\n"
          "This app shows Air Quality Index (AQI) data for divisions of Bangladesh.\n"
          "Data source: World Air Quality Index (WAQI).\n\n"
          "Features:\n"
          "• Current AQI with categories\n"
          "• Trends and Forecast (to be implemented)\n"
          "• Alerts and Notifications\n",
        ),
      ),
    );
  }
}
