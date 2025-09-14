import 'package:dio/dio.dart';

class ApiService {
  static const String _token = "eabe0cef3a89047677497c4dd4a057ce12d338b5";
  final Dio _dio = Dio();

  static const Map<String, String> _stationIds = {
    "Dhaka": "A538609",
    "Chattogram": "A538645",
    "Rajshahi": "A538648",
    "Khulna": "A562729",
    "Barishal": "A538651",
    "Sylhet": "A538636",
    "Rangpur": "A538642",
    "Mymensingh": "A538624",
  };

  Future<Map<String, dynamic>> fetchCurrent(String division) async {
    final id = _stationIds[division];
    if (id == null) throw Exception("Unknown division $division");

    final url = "https://api.waqi.info/feed/$id/?token=$_token";
    final res = await _dio.get(url);

    if (res.statusCode == 200 && res.data["status"] == "ok") {
      final d = res.data["data"];
      return {
        "division": division,
        "aqi": d["aqi"],
        "updated_at": d["time"]?["s"] ?? "",
        "station": d["city"]?["name"] ?? division,
        "forecast": d["forecast"]?["daily"]?["pm25"] ?? [],
      };
    }
    throw Exception("Failed to fetch AQI for $division");
  }
}
