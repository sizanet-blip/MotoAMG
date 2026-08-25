import 'dart:convert';
import 'dart:math' as math;

import 'package:http/http.dart' as http;
import 'package:loc_motos/core/constants/navigation_constants.dart';
import 'package:loc_motos/features/navigation/domain/entities/geo_point.dart';
import 'package:loc_motos/features/navigation/domain/entities/route_alert.dart';

/// POI OpenStreetMap vía Overpass (gasolineras cerca de la ruta).
class OverpassPoiDatasource {
  OverpassPoiDatasource({http.Client? client})
      : _client = client ?? http.Client();

  final http.Client _client;

  Future<List<RouteAlert>> fetchFuelNearRoute(
    List<GeoPoint> polyline,
  ) async {
    if (polyline.length < 2) {
      return const [];
    }
    final boxes = _sampleBboxes(polyline);
    if (boxes.isEmpty) {
      return const [];
    }

    final parts = <String>[
      for (final b in boxes)
        'node["amenity"="fuel"](${b.south},${b.west},${b.north},${b.east});',
    ];
    final query = '[out:json][timeout:20];'
        '(${parts.join()});'
        'out body;';

    try {
      final response = await _client
          .post(
            Uri.parse(NavigationConstants.overpassInterpreterUrl),
            headers: {
              'Content-Type': 'application/x-www-form-urlencoded',
              'User-Agent': 'LocMotos/1.0 (navigation; contact@locmotos.local)',
            },
            body: {'data': query},
          )
          .timeout(NavigationConstants.overpassRequestTimeout);
      if (response.statusCode != 200) {
        return const [];
      }
      final decoded = jsonDecode(response.body);
      if (decoded is! Map<String, dynamic>) {
        return const [];
      }
      final elements = decoded['elements'] as List<dynamic>? ?? const [];
      final alerts = <RouteAlert>[];
      final seen = <String>{};

      for (final raw in elements) {
        if (raw is! Map<String, dynamic>) {
          continue;
        }
        final lat = (raw['lat'] as num?)?.toDouble();
        final lng = (raw['lon'] as num?)?.toDouble();
        if (lat == null || lng == null) {
          continue;
        }
        final tags = raw['tags'];
        final tagMap = tags is Map
            ? Map<String, dynamic>.from(tags)
            : const <String, dynamic>{};
        if (tagMap['amenity'] != 'fuel') {
          continue;
        }
        final point = GeoPoint(lat: lat, lng: lng);
        final projected = _projectOntoRoute(point, polyline);
        if (projected == null) {
          continue;
        }
        if (projected.distanceToRoute >
            NavigationConstants.routePoiBufferMeters) {
          continue;
        }
        final key =
            'fuel_${projected.alongMeters.round()}_${lat.toStringAsFixed(4)}';
        if (!seen.add(key)) {
          continue;
        }
        final name = (tagMap['name'] as String?)?.trim();
        alerts.add(
          RouteAlert(
            id: key,
            type: RouteAlertType.fuel,
            point: point,
            distanceAlongRouteMeters: projected.alongMeters,
            label: name?.isNotEmpty == true ? name! : 'Gasolinera',
            meta: name,
          ),
        );
      }
      return alerts;
    } catch (_) {
      return const [];
    }
  }

  @Deprecated('Usar fetchFuelNearRoute; radares pasan por SpainRadarDatasource')
  Future<List<RouteAlert>> fetchFuelAndCamerasNearRoute(
    List<GeoPoint> polyline,
  ) =>
      fetchFuelNearRoute(polyline);

  List<({double south, double west, double north, double east})> _sampleBboxes(
    List<GeoPoint> polyline,
  ) {
    final every = NavigationConstants.overpassSampleEveryMeters;
    final bufferDeg = NavigationConstants.routePoiBufferMeters / 111320.0;
    final anchors = <GeoPoint>[polyline.first];
    var traveled = 0.0;
    for (var i = 1; i < polyline.length; i++) {
      traveled += _haversineMeters(polyline[i - 1], polyline[i]);
      if (traveled >= every) {
        anchors.add(polyline[i]);
        traveled = 0;
      }
    }
    if (anchors.last != polyline.last) {
      anchors.add(polyline.last);
    }

    final boxes =
        <({double south, double west, double north, double east})>[];
    for (var i = 0; i < anchors.length - 1; i++) {
      final a = anchors[i];
      final b = anchors[i + 1];
      boxes.add((
        south: math.min(a.lat, b.lat) - bufferDeg,
        west: math.min(a.lng, b.lng) - bufferDeg,
        north: math.max(a.lat, b.lat) + bufferDeg,
        east: math.max(a.lng, b.lng) + bufferDeg,
      ));
    }
    return boxes;
  }

  ({double alongMeters, double distanceToRoute})? _projectOntoRoute(
    GeoPoint point,
    List<GeoPoint> polyline,
  ) {
    var bestDist = double.infinity;
    var bestAlong = 0.0;
    var cumulative = 0.0;
    for (var i = 0; i < polyline.length - 1; i++) {
      final a = polyline[i];
      final b = polyline[i + 1];
      final segLen = _haversineMeters(a, b);
      final projected = _projectOnSegment(point, a, b);
      final d = _haversineMeters(point, projected.point);
      if (d < bestDist) {
        bestDist = d;
        bestAlong = cumulative + projected.t * segLen;
      }
      cumulative += segLen;
    }
    if (bestDist.isInfinite) {
      return null;
    }
    return (alongMeters: bestAlong, distanceToRoute: bestDist);
  }

  ({GeoPoint point, double t}) _projectOnSegment(
    GeoPoint p,
    GeoPoint a,
    GeoPoint b,
  ) {
    final ax = a.lng;
    final ay = a.lat;
    final bx = b.lng;
    final by = b.lat;
    final px = p.lng;
    final py = p.lat;
    final dx = bx - ax;
    final dy = by - ay;
    final len2 = dx * dx + dy * dy;
    if (len2 < 1e-18) {
      return (point: a, t: 0);
    }
    final t = ((px - ax) * dx + (py - ay) * dy) / len2;
    final clamped = t.clamp(0.0, 1.0);
    return (
      point: GeoPoint(lat: ay + clamped * dy, lng: ax + clamped * dx),
      t: clamped,
    );
  }

  double _haversineMeters(GeoPoint a, GeoPoint b) {
    const r = 6371000.0;
    final dLat = _rad(b.lat - a.lat);
    final dLng = _rad(b.lng - a.lng);
    final lat1 = _rad(a.lat);
    final lat2 = _rad(b.lat);
    final h = math.sin(dLat / 2) * math.sin(dLat / 2) +
        math.cos(lat1) *
            math.cos(lat2) *
            math.sin(dLng / 2) *
            math.sin(dLng / 2);
    return 2 * r * math.asin(math.sqrt(h));
  }

  double _rad(double deg) => deg * math.pi / 180;
}
