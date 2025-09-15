import 'dart:convert';
import 'package:http/http.dart' as http;

class AqiService {
  static const String _base = 'https://aqi-bd-backend.onrender.com';

  Future<List<Map<String, dynamic>>> fetchForecast7(String division) async {
    final uri = Uri.parse('$_base/predict?division=$division');
    final res = await http.get(uri, headers: {'Accept': 'application/json'});
    if (res.statusCode != 200) {
      throw Exception('Forecast API ${res.statusCode}: ${res.body}');
    }
    final body = jsonDecode(res.body) as Map<String, dynamic>;
    final List<dynamic> preds = body['predictions'] ?? [];

    final out = <Map<String, dynamic>>[];
    for (int i = 0; i < preds.length; i++) {
      final p = preds[i] as Map<String, dynamic>;
      final v = (p['predicted_aqi'] is num) ? (p['predicted_aqi'] as num).toDouble() : 0.0;
      final label = i == 0 ? 'Today' : (i == 1 ? 'Tomorrow' : 'Day ${i + 1}');
      out.add({'label': label, 'date': p['date'] ?? '', 'aqi_pred': v});
    }
    return out;
  }
}
