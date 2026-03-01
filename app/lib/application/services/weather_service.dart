import 'dart:convert';

import 'package:http/http.dart' as http;

class WeatherData {
  final double? airPressureMb;
  final String? windDirection;
  final int? windSpeedMph;
  final double? airTempC;
  final String? cloudCover;
  final String? rain;

  const WeatherData({
    this.airPressureMb,
    this.windDirection,
    this.windSpeedMph,
    this.airTempC,
    this.cloudCover,
    this.rain,
  });
}

/// Fetches current weather from OpenWeatherMap.
/// Returns null gracefully if offline or API fails — catch still saves.
class WeatherService {
  static const String _baseUrl =
      'https://api.openweathermap.org/data/2.5/weather';

  /// Cache: venue key → (data, timestamp)
  static final Map<String, (WeatherData, DateTime)> _cache = {};
  static const _cacheDuration = Duration(minutes: 30);

  static String? _apiKey;

  static void configure({required String apiKey}) {
    _apiKey = apiKey;
  }

  /// Fetch weather for a venue location. Returns null if offline or fails.
  static Future<WeatherData?> fetch({
    required double lat,
    required double lng,
  }) async {
    if (_apiKey == null || _apiKey!.isEmpty) return null;

    // Check cache
    final cacheKey = '${lat.toStringAsFixed(4)},${lng.toStringAsFixed(4)}';
    final cached = _cache[cacheKey];
    if (cached != null &&
        DateTime.now().difference(cached.$2) < _cacheDuration) {
      return cached.$1;
    }

    try {
      final uri = Uri.parse(
        '$_baseUrl?lat=$lat&lon=$lng&appid=$_apiKey&units=metric',
      );
      final response = await http.get(uri).timeout(
            const Duration(seconds: 10),
          );

      if (response.statusCode != 200) return null;

      final json = jsonDecode(response.body) as Map<String, dynamic>;
      final main = json['main'] as Map<String, dynamic>?;
      final wind = json['wind'] as Map<String, dynamic>?;
      final weather = (json['weather'] as List?)?.firstOrNull
          as Map<String, dynamic>?;
      final clouds = json['clouds'] as Map<String, dynamic>?;
      final rainData = json['rain'] as Map<String, dynamic>?;

      final data = WeatherData(
        airPressureMb: (main?['pressure'] as num?)?.toDouble(),
        windDirection: wind?['deg'] != null
            ? _degreeToCompass((wind!['deg'] as num).toDouble())
            : null,
        windSpeedMph: wind?['speed'] != null
            ? ((wind!['speed'] as num).toDouble() * 2.237).round()
            : null,
        airTempC: (main?['temp'] as num?)?.toDouble(),
        cloudCover: clouds?['all'] != null ? '${clouds!['all']}%' : null,
        rain: rainData != null
            ? '${rainData['1h'] ?? rainData['3h'] ?? 0} mm'
            : (weather?['main'] == 'Rain' ? 'Light' : null),
      );

      _cache[cacheKey] = (data, DateTime.now());
      return data;
    } catch (_) {
      return null;
    }
  }

  static String _degreeToCompass(double deg) {
    const directions = [
      'N', 'NNE', 'NE', 'ENE', 'E', 'ESE', 'SE', 'SSE',
      'S', 'SSW', 'SW', 'WSW', 'W', 'WNW', 'NW', 'NNW',
    ];
    final index = ((deg / 22.5) + 0.5).floor() % 16;
    return directions[index];
  }
}
