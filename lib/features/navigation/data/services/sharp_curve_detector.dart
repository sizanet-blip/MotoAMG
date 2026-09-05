import 'dart:collection';
import 'dart:math' as math;

import 'package:moto_amg/core/constants/navigation_constants.dart';
import 'package:moto_amg/features/navigation/domain/entities/geo_point.dart';
import 'package:moto_amg/features/navigation/domain/entities/route_alert.dart';

/// Detecta curvas a partir de la geometría de la polilínea (estilo GPS moto).
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
    final window = Queue<_TurnSample>();
    var windowSigned = 0.0;
    var windowAbs = 0.0;
    var along = 0.0;
    var lastBearing = _bearingDeg(polyline[0], polyline[1]);
    var lastAlertAlong = -minSeparationMeters;
    var pendingPeakAbs = 0.0;
    double? pendingSigned;
    GeoPoint? pendingPoint;
    var pendingAlong = 0.0;
    var armed = false;

    void flushPending() {
      if (!armed || pendingPoint == null || pendingSigned == null) {
        armed = false;
        pendingPeakAbs = 0;
        pendingSigned = null;
        pendingPoint = null;
        return;
      }
      if (pendingAlong - lastAlertAlong < minSeparationMeters) {
        armed = false;
        pendingPeakAbs = 0;
        pendingSigned = null;
        pendingPoint = null;
        return;
      }
      final signed = pendingSigned!;
      final absDeg = pendingPeakAbs;
      final severity = CurveSeverity.fromTurnDegrees(absDeg);
      final turn = signed >= 0 ? CurveTurn.right : CurveTurn.left;
      final side = turn.shortLabel.toLowerCase();
      alerts.add(
        RouteAlert(
          id: 'curve_${pendingAlong.round()}_${severity.name}',
          type: RouteAlertType.sharpCurve,
          point: pendingPoint!,
          distanceAlongRouteMeters: pendingAlong,
          label: '${severity.shortLabel} $side',
          meta: '${absDeg.round()}°',
          curveSeverity: severity,
          curveTurn: turn,
          curveDegrees: absDeg,
        ),
      );
      lastAlertAlong = pendingAlong;
      armed = false;
      pendingPeakAbs = 0;
      pendingSigned = null;
      pendingPoint = null;
    }

    for (var i = 1; i < polyline.length - 1; i++) {
      final a = polyline[i];
      final b = polyline[i + 1];
      final seg = _haversineMeters(a, b);
      if (seg < 0.5) {
        continue;
      }
      along += seg;
      final bearing = _bearingDeg(a, b);
      final delta = _bearingDeltaSigned(lastBearing, bearing);
      lastBearing = bearing;

      window.add(_TurnSample(along: along, signedDelta: delta));
      windowSigned += delta;
      windowAbs += delta.abs();

      while (window.isNotEmpty &&
          along - window.first.along > windowMeters) {
        final old = window.removeFirst();
        windowSigned -= old.signedDelta;
        windowAbs -= old.signedDelta.abs();
      }

      final netAbs = windowSigned.abs();
      final score = math.max(netAbs, windowAbs * 0.65);

      if (score >= minBearingDeltaDeg) {
        if (!armed || score >= pendingPeakAbs) {
          armed = true;
          pendingPeakAbs = score;
          pendingSigned = windowSigned;
          pendingPoint = a;
          pendingAlong = along;
        }
      } else if (armed) {
        flushPending();
      }
    }
    flushPending();
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

  static double _bearingDeltaSigned(double from, double to) {
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

class _TurnSample {
  const _TurnSample({required this.along, required this.signedDelta});

  final double along;
  final double signedDelta;
}
