import 'dart:convert';
import 'package:http/http.dart' as http;

/// WAQI API service: fetch current AQI for the selected division.
///
/// Uses your provided station IDs (stable) instead of fuzzy city names.
class AqiService {
  static const _token =
      'eabe0cef3a89047677497c4dd4a057ce12d338b5';

  // Division → WAQI station ID
  static const Map<String, String> _stationId = {
    'Dhaka': 'A538609',
    'Chattogram': 'A538645',
    'Rajshahi': 'A538648',
    'Khulna': 'A562729',
    'Barishal': 'A538651',
    'Sylhet': 'A538636',
    'Rangpur': 'A538642',
    'Mymensingh': 'A538624',
  };

  /// Returns:
  /// {
  ///   'aqi': int?,
  ///   'station': String,
  ///   'updated_at': String
  /// }
  Future<Map<String, dynamic>> fetchCurrent(String division) async {
    final id = _stationId[division];
    if (id == null) {
      throw Exception('Unknown division/station id for $division');
    }

    final uri = Uri.parse('https://api.waqi.info/feed/$id/?token=$_token');
    final resp = await http.get(uri);
    if (resp.statusCode != 200) {
      throw Exception('HTTP ${resp.statusCode}');
    }

    final map = json.decode(utf8.decode(resp.bodyBytes));
    if (map['status'] != 'ok') {
      throw Exception('WAQI error: ${map['message'] ?? 'unknown'}');
    }

    final data = map['data'] ?? {};
    final aqi = data['aqi'];
    final time = (data['time']?['s'] ?? '').toString();
    final name = (data['city']?['name'] ?? division).toString();

    return {
      'aqi': (aqi is num) ? aqi.toInt() : null,
      'station': name,
      'updated_at': time,
    };
  }
}
