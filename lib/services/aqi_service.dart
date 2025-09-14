// lib/services/aqi_service.dart
class AqiService {
  Future<List<Map<String, dynamic>>> fetchForecast7(String division) async {
    await Future.delayed(const Duration(milliseconds: 300));
    return [
      {'label': 'Today', 'aqi_pred': 156},
      {'label': 'Tomorrow', 'aqi_pred': 142},
      {'label': 'Day 3', 'aqi_pred': 134},
      {'label': 'Day 4', 'aqi_pred': 128},
      {'label': 'Day 5', 'aqi_pred': 145},
      {'label': 'Day 6', 'aqi_pred': 167},
      {'label': 'Day 7', 'aqi_pred': 178},
    ];
  }
}
