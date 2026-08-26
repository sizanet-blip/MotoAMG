import 'dart:math' as math;

/// Amanecer / atardecer locales según lat/lng y fecha (ecuación solar estándar).
///
/// Tiene en cuenta la estación: en verano anochece más tarde, en invierno antes.
abstract final class SolarDaylight {
  /// Centro peninsular por si aún no hay GPS.
  static const defaultLatitude = 40.4168;
  static const defaultLongitude = -3.7038;

  /// `true` = de noche (antes del amanecer o después del atardecer).
  static bool isNight(
    DateTime localTime, {
    double? latitude,
    double? longitude,
  }) {
    final lat = latitude ?? defaultLatitude;
    final lng = longitude ?? defaultLongitude;
    final window = riseAndSet(localTime, latitude: lat, longitude: lng);
    if (window == null) {
      // Polos / error: heurística suave.
      final hour = localTime.hour;
      return hour >= 20 || hour < 7;
    }
    final nowMinutes = localTime.hour * 60 + localTime.minute;
    final riseMinutes =
        window.sunrise.hour * 60 + window.sunrise.minute;
    final setMinutes = window.sunset.hour * 60 + window.sunset.minute;
    return nowMinutes < riseMinutes || nowMinutes >= setMinutes;
  }

  /// Amanecer y atardecer del día civil en hora local del dispositivo.
  static ({DateTime sunrise, DateTime sunset})? riseAndSet(
    DateTime localTime, {
    required double latitude,
    required double longitude,
  }) {
    if (latitude.abs() > 66.5) {
      return null;
    }

    final localMidnight = DateTime(
      localTime.year,
      localTime.month,
      localTime.day,
    );
    final offsetHours = localTime.timeZoneOffset.inMinutes / 60.0;
    final dayOfYear = _dayOfYear(localMidnight);

    final riseUtcHours = _utcSolarEventHours(
      dayOfYear: dayOfYear,
      latitude: latitude,
      longitude: longitude,
      rising: true,
    );
    final setUtcHours = _utcSolarEventHours(
      dayOfYear: dayOfYear,
      latitude: latitude,
      longitude: longitude,
      rising: false,
    );
    if (riseUtcHours == null || setUtcHours == null) {
      return null;
    }

    DateTime fromUtcHours(double utcHours) {
      final localHours = utcHours + offsetHours;
      var minutesTotal = (localHours * 60).round();
      // Normalizar al día local.
      minutesTotal %= 24 * 60;
      if (minutesTotal < 0) {
        minutesTotal += 24 * 60;
      }
      return localMidnight.add(Duration(minutes: minutesTotal));
    }

    return (
      sunrise: fromUtcHours(riseUtcHours),
      sunset: fromUtcHours(setUtcHours),
    );
  }

  static int _dayOfYear(DateTime date) {
    final start = DateTime(date.year);
    return date.difference(start).inDays + 1;
  }

  /// Horas UTC fraccionarias del evento (amanecer/atardecer).
  static double? _utcSolarEventHours({
    required int dayOfYear,
    required double latitude,
    required double longitude,
    required bool rising,
  }) {
    // Algoritmo clásico (NOAA / zenith oficial 90°50').
    const zenith = 90.833;
    final lngHour = longitude / 15.0;
    final t = rising
        ? dayOfYear + ((6 - lngHour) / 24)
        : dayOfYear + ((18 - lngHour) / 24);

    final m = (0.9856 * t) - 3.289;
    var l = m +
        (1.916 * math.sin(_degToRad(m))) +
        (0.020 * math.sin(_degToRad(2 * m))) +
        282.634;
    l = _normalizeDegrees(l);

    var ra = _radToDeg(math.atan(0.91764 * math.tan(_degToRad(l))));
    ra = _normalizeDegrees(ra);
    final lQuadrant = (l / 90).floor() * 90;
    final raQuadrant = (ra / 90).floor() * 90;
    ra = ra + (lQuadrant - raQuadrant);
    ra /= 15;

    final sinDec = 0.39782 * math.sin(_degToRad(l));
    final cosDec = math.cos(math.asin(sinDec));
    final cosH = (math.cos(_degToRad(zenith)) -
            (sinDec * math.sin(_degToRad(latitude)))) /
        (cosDec * math.cos(_degToRad(latitude)));
    if (cosH > 1 || cosH < -1) {
      return null;
    }

    var h = rising
        ? 360 - _radToDeg(math.acos(cosH))
        : _radToDeg(math.acos(cosH));
    h /= 15;

    final tEvent = h + ra - (0.06571 * t) - 6.622;
    var utc = tEvent - lngHour;
    utc %= 24;
    if (utc < 0) {
      utc += 24;
    }
    return utc;
  }

  static double _degToRad(double deg) => deg * math.pi / 180;
  static double _radToDeg(double rad) => rad * 180 / math.pi;

  static double _normalizeDegrees(double value) {
    var v = value % 360;
    if (v < 0) {
      v += 360;
    }
    return v;
  }
}
