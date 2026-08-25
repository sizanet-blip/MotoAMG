import 'dart:math' as math;

import 'package:loc_motos/core/constants/navigation_constants.dart';
import 'package:loc_motos/features/navigation/domain/entities/geo_point.dart';
import 'package:loc_motos/features/navigation/domain/entities/route_alert.dart';

/// Detecta curvas fuertes a partir de la geometría de la polilínea.
abstract final class SharpCurveDetector {
  static List<RouteAlert> detect(
    List<GeoPoint> polyline, {
    double windowMeters = NavigationConstants.sharpCurveWindowMeters,
    double minBearingDeltaDeg =
        NavigationConstants.sharpCurveMinBearingDeltaDeg,
    double minSeparationMeters =
        NavigationConstants.sharpCurveMinSeparationMeters,
  }) {
    if (polyline.length < 3) {
      return const [];
    }

    final alerts = <RouteAlert>[];
    var along = 0.0;
    var windowStartAlong = 0.0;
    var windowStartBearing = _bearingDeg(polyline[0], polyline[1]);
    var cumDelta = 0.0;
    var lastBearing = windowStartBearing;
    var lastAlertAlong = -minSeparationMeters;

    for (var i = 1; i < polyline.length - 1; i++) {
      final a = polyline[i];
      final b = polyline[i + 1];
      final seg = _haversineMeters(a, b);
      if (seg < 0.5) {
        continue;
      }
      along += seg;
      final bearing = _bearingDeg(a, b);
      cumDelta += _bearingDeltaAbs(lastBearing, bearing).abs();
      lastBearing = bearing;

      while (along - windowStartAlong > windowMeters &&
          windowStartAlong < along) {
        // Avance de ventana aproximado: reinicia al punto actual.
        windowStartAlong = along - windowMeters;
        windowStartBearing = bearing;
        cumDelta = 0;
      }

      if (cumDelta >= minBearingDeltaDeg &&
          along - lastAlertAlong >= minSeparationMeters) {
        alerts.add(
          RouteAlert(
            id: 'curve_${along.round()}',
            type: RouteAlertType.sharpCurve,
            point: a,
            distanceAlongRouteMeters: along,
            label: 'Curva pronunciada',
          ),
        );
        lastAlertAlong = along;
        cumDelta = 0;
        windowStartAlong = along;
        windowStartBearing = bearing;
      }
    }
    return alerts;
  }

  static double _haversineMeters(GeoPoint a, GeoPoint b) {
    const r = 6371000.0;
    final dLat = _rad(b.lat - a.lat);
    final dLng = _rad(b.lng - a.lng);
    final lat1 = _rad(a.lat);
    final lat2 = _rad(b.lat);
    final h = math.sin(dLat / 2) * math.sin(dLat / 2) +
        math.cos(lat1) * math.cos(lat2) * math.sin(dLng / 2) * math.sin(dLng / 2);
    return 2 * r * math.asin(math.sqrt(h));
  }

  static double _bearingDeg(GeoPoint a, GeoPoint b) {
    final lat1 = _rad(a.lat);
    final lat2 = _rad(b.lat);
    final dLng = _rad(b.lng - a.lng);
    final y = math.sin(dLng) * math.cos(lat2);
    final x = math.cos(lat1) * math.sin(lat2) -
        math.sin(lat1) * math.cos(lat2) * math.cos(dLng);
    return (_deg(math.atan2(y, x)) + 360) % 360;
  }

  static double _bearingDeltaAbs(double from, double to) {
    var d = to - from;
    while (d > 180) {
      d -= 360;
    }
    while (d < -180) {
      d += 360;
    }
    return d;
  }

  static double _rad(double deg) => deg * math.pi / 180;
  static double _deg(double rad) => rad * 180 / math.pi;
}
