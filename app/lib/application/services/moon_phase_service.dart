import 'dart:math';

/// Pure Dart moon phase calculation — no network required.
/// Uses the standard astronomical synodic period (29.53058770576 days).
class MoonPhaseService {
  static const double _synodicMonth = 29.53058770576;

  /// Known new moon reference: January 6, 2000 18:14 UTC.
  static final DateTime _referenceNewMoon = DateTime.utc(2000, 1, 6, 18, 14);

  /// Calculate moon phase for a given date.
  /// Returns one of: New, Waxing Crescent, First Quarter, Waxing Gibbous,
  /// Full, Waning Gibbous, Last Quarter, Waning Crescent.
  static String calculate(DateTime date) {
    final daysSinceRef =
        date.toUtc().difference(_referenceNewMoon).inSeconds / 86400.0;
    final cycles = daysSinceRef / _synodicMonth;
    final phase = (cycles - cycles.floor()); // 0.0 to 1.0
    return _phaseToName(phase);
  }

  /// Returns the moon illumination fraction (0.0 = new, 1.0 = full).
  static double illumination(DateTime date) {
    final daysSinceRef =
        date.toUtc().difference(_referenceNewMoon).inSeconds / 86400.0;
    final cycles = daysSinceRef / _synodicMonth;
    final phase = cycles - cycles.floor();
    // Illumination follows a cosine curve
    return (1 - cos(phase * 2 * pi)) / 2;
  }

  static String _phaseToName(double phase) {
    if (phase < 0.0625) return 'New';
    if (phase < 0.1875) return 'Waxing Crescent';
    if (phase < 0.3125) return 'First Quarter';
    if (phase < 0.4375) return 'Waxing Gibbous';
    if (phase < 0.5625) return 'Full';
    if (phase < 0.6875) return 'Waning Gibbous';
    if (phase < 0.8125) return 'Last Quarter';
    if (phase < 0.9375) return 'Waning Crescent';
    return 'New';
  }
}
