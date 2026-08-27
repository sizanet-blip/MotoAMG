import 'dart:math' as math;

import 'package:loc_motos/features/navigation/domain/entities/geo_point.dart';

/// Avanza una posición ficticia a lo largo de la polilínea de la ruta.
class RouteProgressSimulator {
  RouteProgressSimulator({
    required List<GeoPoint> polyline,
    this.speedMps = 16.7, // ~60 km/h
    double initialDistanceAlongMeters = 0,
  }) : _polyline = List<GeoPoint>.unmodifiable(polyline) {
    _segmentLengths = _computeSegmentLengths(_polyline);
    _totalLength = _segmentLengths.fold<double>(0, (sum, length) => sum + length);
    _distanceAlongMeters = initialDistanceAlongMeters.clamp(0, _totalLength);
  }

  final List<GeoPoint> _polyline;

  /// Se puede cambiar en marcha (deslizador del HUD).
  double speedMps;

  late final List<double> _segmentLengths;
  late final double _totalLength;
  var _distanceAlongMeters = 0.0;

  double get totalLengthMeters => _totalLength;
  double get distanceAlongMeters => _distanceAlongMeters;
  double get progressRatio =>
      _totalLength <= 0 ? 1 : (_distanceAlongMeters / _totalLength).clamp(0, 1);
  bool get isFinished =>
      _polyline.length < 2 || _distanceAlongMeters >= _totalLength;

  RouteSimulationSample sample() => _sampleAt(_distanceAlongMeters);

  /// Coloca el progreso en el punto de la ruta más cercano a [point].
  void seekToNearest(GeoPoint point) {
    _distanceAlongMeters =
        distanceAlongNearest(point, _polyline, _segmentLengths)
            .clamp(0.0, _totalLength);
  }

  /// Metros desde el inicio de la polilínea hasta la proyección de [point].
  static double distanceAlongNearest(
    GeoPoint point,
    List<GeoPoint> polyline, [
    List<double>? segmentLengths,
  ]) {
    if (polyline.length < 2) {
      return 0;
    }
    final lengths = segmentLengths ?? _computeSegmentLengths(polyline);
    var bestAlong = 0.0;
    var bestDist = double.infinity;
    var traveled = 0.0;
    for (var i = 0; i < lengths.length; i++) {
      final a = polyline[i];
      final b = polyline[i + 1];
      final projected = _projectOnSegment(point, a, b);
      final d = _haversineMeters(point, projected.point);
      if (d < bestDist) {
        bestDist = d;
        bestAlong = traveled + projected.t * lengths[i];
      }
      traveled += lengths[i];
    }
    return bestAlong;
  }

  /// Avanza [dt] a la velocidad configurada. Devuelve la nueva muestra.
  RouteSimulationSample advance(Duration dt) {
    if (_polyline.length < 2 || _totalLength <= 0) {
      final point = _polyline.isEmpty
          ? const GeoPoint(lat: 0, lng: 0)
          : _polyline.first;
      return RouteSimulationSample(
        position: point,
        bearingDegrees: 0,
        speedMps: 0,
        finished: true,
      );
    }

    final step = speedMps * (dt.inMilliseconds / 1000);
    _distanceAlongMeters =
        (_distanceAlongMeters + step).clamp(0, _totalLength);
    return _sampleAt(_distanceAlongMeters);
  }

  void reset() {
    _distanceAlongMeters = 0;
  }

  RouteSimulationSample _sampleAt(double distanceMeters) {
    if (_polyline.length == 1) {
      return RouteSimulationSample(
        position: _polyline.first,
        bearingDegrees: 0,
        speedMps: 0,
        finished: true,
      );
    }

    var remaining = distanceMeters;
    for (var i = 0; i < _segmentLengths.length; i++) {
      final segmentLength = _segmentLengths[i];
      final from = _polyline[i];
      final to = _polyline[i + 1];
      if (remaining <= segmentLength || i == _segmentLengths.length - 1) {
        final t = segmentLength <= 0
            ? 1.0
            : (remaining / segmentLength).clamp(0.0, 1.0);
        final position = GeoPoint(
          lat: from.lat + (to.lat - from.lat) * t,
          lng: from.lng + (to.lng - from.lng) * t,
        );
        final bearing = _bearingDegrees(from, to);
        final finished = distanceMeters >= _totalLength;
        return RouteSimulationSample(
          position: position,
          bearingDegrees: bearing,
          speedMps: finished ? 0 : speedMps,
          finished: finished,
        );
      }
      remaining -= segmentLength;
    }

    return RouteSimulationSample(
      position: _polyline.last,
      bearingDegrees: 0,
      speedMps: 0,
      finished: true,
    );
  }

  static List<double> _computeSegmentLengths(List<GeoPoint> polyline) {
    if (polyline.length < 2) {
      return const [];
    }
    final lengths = <double>[];
    for (var i = 0; i < polyline.length - 1; i++) {
      lengths.add(_haversineMeters(polyline[i], polyline[i + 1]));
    }
    return lengths;
  }

  static ({GeoPoint point, double t}) _projectOnSegment(
    GeoPoint p,
    GeoPoint a,
    GeoPoint b,
  ) {
    final abLat = b.lat - a.lat;
    final abLng = b.lng - a.lng;
    final ab2 = abLat * abLat + abLng * abLng;
    if (ab2 <= 0) {
      return (point: a, t: 0);
    }
    final apLat = p.lat - a.lat;
    final apLng = p.lng - a.lng;
    final t = ((apLat * abLat + apLng * abLng) / ab2).clamp(0.0, 1.0);
    return (
      point: GeoPoint(lat: a.lat + abLat * t, lng: a.lng + abLng * t),
      t: t,
    );
  }

  static double _haversineMeters(GeoPoint a, GeoPoint b) {
    const earthRadius = 6371000.0;
    final dLat = _toRadians(b.lat - a.lat);
    final dLng = _toRadians(b.lng - a.lng);
    final lat1 = _toRadians(a.lat);
    final lat2 = _toRadians(b.lat);
    final h = math.sin(dLat / 2) * math.sin(dLat / 2) +
        math.cos(lat1) * math.cos(lat2) * math.sin(dLng / 2) * math.sin(dLng / 2);
    return 2 * earthRadius * math.asin(math.sqrt(h));
  }

  static double _bearingDegrees(GeoPoint from, GeoPoint to) {
    final lat1 = _toRadians(from.lat);
    final lat2 = _toRadians(to.lat);
    final dLng = _toRadians(to.lng - from.lng);
    final y = math.sin(dLng) * math.cos(lat2);
    final x = math.cos(lat1) * math.sin(lat2) -
        math.sin(lat1) * math.cos(lat2) * math.cos(dLng);
    final bearing = math.atan2(y, x) * 180 / math.pi;
    return (bearing + 360) % 360;
  }

  static double _toRadians(double degrees) => degrees * math.pi / 180;
}

class RouteSimulationSample {
  const RouteSimulationSample({
    required this.position,
    required this.bearingDegrees,
    required this.speedMps,
    required this.finished,
  });

  final GeoPoint position;
  final double bearingDegrees;
  final double speedMps;
  final bool finished;
}
