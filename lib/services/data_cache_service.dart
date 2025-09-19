import 'dart:async';
import 'dart:convert';
import 'package:csv/csv.dart';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:intl/intl.dart';
import 'api_service.dart';
import 'aqi_service.dart';

/// Centralized data cache service to avoid repeated network calls
class DataCacheService extends ChangeNotifier {
  static final DataCacheService _instance = DataCacheService._internal();
  factory DataCacheService() => _instance;
  DataCacheService._internal() {
    _startCleanupTimer();
  }

  final ApiService _api = ApiService();
  final AqiService _aqiService = AqiService();
  
  // Cache duration - 10 minutes
  static const Duration _cacheDuration = Duration(minutes: 10);
  
  // Cleanup timer - runs every 10 minutes to clean expired cache
  static const Duration _cleanupInterval = Duration(minutes: 10);
  Timer? _cleanupTimer;
  
  // CSV URL
  static const String _csvUrl =
      'https://docs.google.com/spreadsheets/d/1aRyCU88momwOk_ONhXXzjbm0-9uoCQrRWVQlQOrTM48/export?format=csv';
  
  // City name fixes
  static const Map<String, String> _cityFix = {
    'Chittagong': 'Chattogram',
    'Barisal': 'Barishal',
  };

  // Cache storage
  final Map<String, _CachedData> _currentDataCache = {};
  final Map<String, _CachedForecastData> _forecastDataCache = {};
  _CachedCSVData? _csvDataCache;
  
  /// Start periodic cleanup timer
  void _startCleanupTimer() {
    _cleanupTimer?.cancel(); // Cancel any existing timer
    _cleanupTimer = Timer.periodic(_cleanupInterval, (_) {
      _cleanupExpiredCache();
    });
  }
  
  /// Clean up expired cache entries
  void _cleanupExpiredCache() {
    bool hasChanges = false;
    
    // Remove expired current data cache entries
    final expiredKeys = _currentDataCache.entries
        .where((entry) => entry.value.isExpired)
        .map((entry) => entry.key)
        .toList();
    
    for (final key in expiredKeys) {
      _currentDataCache.remove(key);
      hasChanges = true;
    }
    
    // Remove expired forecast data cache entries
    final expiredForecastKeys = _forecastDataCache.entries
        .where((entry) => entry.value.isExpired)
        .map((entry) => entry.key)
        .toList();
    
    for (final key in expiredForecastKeys) {
      _forecastDataCache.remove(key);
      hasChanges = true;
    }
    
    // Remove expired CSV cache
    if (_csvDataCache?.isExpired == true) {
      _csvDataCache = null;
      hasChanges = true;
    }
    
    // Notify listeners if cache was cleaned
    if (hasChanges) {
      if (kDebugMode) {
        print('DataCache: Cleaned up ${expiredKeys.length} current + ${expiredForecastKeys.length} forecast expired entries');
      }
      notifyListeners();
    }
  }
  
  /// Dispose method to cancel timer
  @override
  void dispose() {
    _cleanupTimer?.cancel();
    super.dispose();
  }
  
  /// Get current AQI data for a division (cached)
  Future<Map<String, dynamic>> getCurrentData(String division) async {
    // Clean expired entries on access
    _cleanupExpiredCache();
    
    final cached = _currentDataCache[division];
    
    // Return cached data if still valid
    if (cached != null && !cached.isExpired) {
      return cached.data;
    }
    
    // Fetch fresh data
    try {
      final data = await _api.fetchCurrent(division);
      _currentDataCache[division] = _CachedData(data, DateTime.now());
      notifyListeners();
      return data;
    } catch (e) {
      // If we have expired cache, return it as fallback
      if (cached != null) {
        return cached.data;
      }
      rethrow;
    }
  }
  
  /// Get CSV dataset (cached)
  Future<_Dataset> getCSVData() async {
    // Clean expired entries on access
    _cleanupExpiredCache();
    
    // Return cached CSV data if still valid
    if (_csvDataCache != null && !_csvDataCache!.isExpired) {
      return _csvDataCache!.dataset;
    }
    
    // Fetch fresh CSV data
    try {
      final dataset = await _loadCsv();
      _csvDataCache = _CachedCSVData(dataset, DateTime.now());
      notifyListeners();
      return dataset;
    } catch (e) {
      // If we have expired cache, return it as fallback
      if (_csvDataCache != null) {
        return _csvDataCache!.dataset;
      }
      rethrow;
    }
  }
  
  /// Get forecast data for a division (cached)
  Future<List<Map<String, dynamic>>> getForecastData(String division) async {
    // Clean expired entries on access
    _cleanupExpiredCache();
    
    final cached = _forecastDataCache[division];
    
    // Return cached data if still valid
    if (cached != null && !cached.isExpired) {
      return cached.data;
    }
    
    // Fetch fresh forecast data
    try {
      final data = await _aqiService.fetchForecast7(division);
      _forecastDataCache[division] = _CachedForecastData(data, DateTime.now());
      notifyListeners();
      return data;
    } catch (e) {
      // If we have expired cache, return it as fallback
      if (cached != null) {
        return cached.data;
      }
      rethrow;
    }
  }
  
  /// Get enhanced data with historical calculations
  Future<Map<String, dynamic>> getEnhancedData(String division) async {
    try {
      // Get both current and CSV data (both cached)
      final currentData = await getCurrentData(division);
      final csvData = await getCSVData();
      
      // Calculate weekly average and last dataset value
      final end = csvData.maxDate;
      final start = end.subtract(const Duration(days: 6)); // 7 days total
      
      // Get weekly average
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
      // Fallback to current data only
      return await getCurrentData(division);
    }
  }
  
  /// Force refresh data for a specific division
  Future<Map<String, dynamic>> refreshData(String division) async {
    _currentDataCache.remove(division);
    return await getCurrentData(division);
  }
  
  /// Force refresh CSV data
  Future<_Dataset> refreshCSVData() async {
    _csvDataCache = null;
    return await getCSVData();
  }
  
  /// Force refresh forecast data for a specific division
  Future<List<Map<String, dynamic>>> refreshForecastData(String division) async {
    _forecastDataCache.remove(division);
    return await getForecastData(division);
  }
  
  /// Clear all cache
  void clearCache() {
    _currentDataCache.clear();
    _forecastDataCache.clear();
    _csvDataCache = null;
    _startCleanupTimer(); // Restart cleanup timer
    notifyListeners();
  }
  
  /// Get cache statistics for debugging
  Map<String, dynamic> getCacheStats() {
    final now = DateTime.now();
    final validEntries = _currentDataCache.entries
        .where((entry) => !entry.value.isExpired)
        .length;
    final expiredEntries = _currentDataCache.length - validEntries;
    
    final validForecastEntries = _forecastDataCache.entries
        .where((entry) => !entry.value.isExpired)
        .length;
    final expiredForecastEntries = _forecastDataCache.length - validForecastEntries;
    
    return {
      'total_current_entries': _currentDataCache.length,
      'valid_current_entries': validEntries,
      'expired_current_entries': expiredEntries,
      'total_forecast_entries': _forecastDataCache.length,
      'valid_forecast_entries': validForecastEntries,
      'expired_forecast_entries': expiredForecastEntries,
      'csv_cached': _csvDataCache != null,
      'csv_expired': _csvDataCache?.isExpired ?? false,
      'last_cleanup': now.toIso8601String(),
    };
  }
  
  /// Check if data is loading for the first time
  bool hasDataFor(String division) {
    return _currentDataCache.containsKey(division);
  }
  
  /// Check if CSV data is available
  bool hasCSVData() {
    return _csvDataCache != null;
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
      final d = DateTime(date.year, date.month, date.day);
      data.add(_Row(date: d, city: normCity, aqi: aqi));
    }

    if (data.isEmpty) return _Dataset(const [], DateTime.now());
    data.sort((a, b) => a.date.compareTo(b.date));
    final maxDate = data.last.date;
    return _Dataset(data, maxDate);
  }
}

/// Cached data wrapper
class _CachedData {
  final Map<String, dynamic> data;
  final DateTime timestamp;
  
  _CachedData(this.data, this.timestamp);
  
  bool get isExpired => DateTime.now().difference(timestamp) > DataCacheService._cacheDuration;
}

/// Cached CSV data wrapper
class _CachedCSVData {
  final _Dataset dataset;
  final DateTime timestamp;
  
  _CachedCSVData(this.dataset, this.timestamp);
  
  bool get isExpired => DateTime.now().difference(timestamp) > DataCacheService._cacheDuration;
}

/// Cached forecast data wrapper
class _CachedForecastData {
  final List<Map<String, dynamic>> data;
  final DateTime timestamp;
  
  _CachedForecastData(this.data, this.timestamp);
  
  bool get isExpired => DateTime.now().difference(timestamp) > DataCacheService._cacheDuration;
}

/// CSV Data Models
class _Row {
  final DateTime date;
  final String city;
  final double? aqi;
  const _Row({required this.date, required this.city, required this.aqi});
}

class _Dataset {
  final List<_Row> rows;
  final DateTime maxDate;
  const _Dataset(this.rows, this.maxDate);

  Map<DateTime, double> mapForCity(String city, DateTime start, DateTime end) {
    final out = <DateTime, double>{};
    for (final r in rows) {
      if (r.city != city) continue;
      if (r.date.isBefore(start) || r.date.isAfter(end)) continue;
      if (r.aqi == null) continue;
      out[r.date] = r.aqi!;
    }
    return out;
  }

  List<double> valuesForCityBetween(String city, DateTime start, DateTime end) {
    final seen = <DateTime>{};
    final vals = <double>[];
    for (final r in rows) {
      if (r.city != city) continue;
      if (r.date.isBefore(start) || r.date.isAfter(end)) continue;
      if (r.aqi == null) continue;
      if (seen.add(r.date)) vals.add(r.aqi!);
    }
    return vals;
  }

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

DateTime? _parseDate(String? s) {
  if (s == null || s.isEmpty) return null;
  final fmts = [
    DateFormat('MM/dd/yyyy'),
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