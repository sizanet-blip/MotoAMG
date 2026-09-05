import 'dart:convert';
import 'dart:math' as math;

import 'package:http/http.dart' as http;
import 'package:moto_amg/core/constants/navigation_constants.dart';
import 'package:moto_amg/features/navigation/domain/entities/geo_point.dart';
import 'package:moto_amg/features/navigation/domain/entities/route_alert.dart';
import 'package:moto_amg/features/navigation/domain/entities/route_map_poi.dart';

/// POI OpenStreetMap vía Overpass (controles de tráfico; gasolineras legacy).
class OverpassPoiDatasource {
  OverpassPoiDatasource({http.Client? client})
      : _client = client ?? http.Client();

  final http.Client _client;

  /// Semáforos, STOP y ceda a lo largo de la ruta (solo mapa).
  Future<List<RouteMapPoi>> fetchTrafficControlsNearRoute(
    List<GeoPoint> polyline,
  ) async {
    if (polyline.length < 2) {
      return const [];
    }
    final boxes = _sampleBboxes(
      polyline,
      everyMeters: NavigationConstants.overpassTrafficSampleEveryMeters,
      bufferMeters: NavigationConstants.trafficControlRouteBufferMeters,
    );
    if (boxes.isEmpty) {
      return const [];
    }

    final parts = <String>[
      for (final b in boxes) ...[
        'node["highway"="traffic_signals"](${b.south},${b.west},${b.north},${b.east});',
        'node["highway"="stop"](${b.south},${b.west},${b.north},${b.east});',
        'node["highway"="give_way"](${b.south},${b.west},${b.north},${b.east});',
      ],
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
              'User-Agent': 'MotoAMG/1.0 (navigation; contact@MotoAMG.local)',
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
      final rawPois = <({RouteMapPoi poi, double distToRoute})>[];
      final seen = <String>{};
      final buffer = NavigationConstants.trafficControlRouteBufferMeters;

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
        final highway = tagMap['highway'] as String?;
        final kind = switch (highway) {
          'traffic_signals' => RouteMapPoiKind.trafficSignal,
          'stop' => RouteMapPoiKind.stop,
          'give_way' => RouteMapPoiKind.giveWay,
          _ => null,
        };
        if (kind == null) {
          continue;
        }
        final point = GeoPoint(lat: lat, lng: lng);
        final projected = _projectOntoRoute(point, polyline);
        if (projected == null || projected.distanceToRoute > buffer) {
          continue;
        }
        final key =
            '${kind.name}_${projected.alongMeters.round()}_${lat.toStringAsFixed(5)}';
        if (!seen.add(key)) {
          continue;
        }
        rawPois.add((
          poi: RouteMapPoi(
            id: key,
            kind: kind,
            point: point,
            distanceAlongRouteMeters: projected.alongMeters,
            label: kind.shortLabel,
          ),
          distToRoute: projected.distanceToRoute,
        ));
      }
      rawPois.sort((a, b) {
        final along = a.poi.distanceAlongRouteMeters
            .compareTo(b.poi.distanceAlongRouteMeters);
        if (along != 0) {
          return along;
        }
        return a.distToRoute.compareTo(b.distToRoute);
      });
      return List.unmodifiable(_thinTrafficControls(rawPois));
    } catch (_) {
      return const [];
    }
  }

  /// Un icono por cruce: prioriza semáforo; evita STOP/ceda de calles laterales.
  List<RouteMapPoi> _thinTrafficControls(
    List<({RouteMapPoi poi, double distToRoute})> sorted,
  ) {
    final clusterM = NavigationConstants.trafficControlDedupeAlongMeters;
    final kept = <({RouteMapPoi poi, double distToRoute})>[];

    bool near(RouteMapPoi a, RouteMapPoi b) =>
        (a.distanceAlongRouteMeters - b.distanceAlongRouteMeters).abs() <
        clusterM;

    for (final candidate in sorted) {
      final poi = candidate.poi;
      final cluster = kept.where((k) => near(k.poi, poi)).toList();
      if (cluster.isEmpty) {
        kept.add(candidate);
        continue;
      }

      if (poi.kind == RouteMapPoiKind.trafficSignal) {
        final existingSignal = cluster
            .where((k) => k.poi.kind == RouteMapPoiKind.trafficSignal)
            .toList();
        if (existingSignal.isNotEmpty) {
          // Conserva el más cercano al eje de la ruta.
          final best = existingSignal.first;
          if (candidate.distToRoute + 0.5 < best.distToRoute) {
            kept.remove(best);
            kept.removeWhere(
              (k) =>
                  near(k.poi, poi) &&
                  k.poi.kind != RouteMapPoiKind.trafficSignal,
            );
            kept.add(candidate);
          }
          continue;
        }
        kept.removeWhere(
          (k) =>
              near(k.poi, poi) && k.poi.kind != RouteMapPoiKind.trafficSignal,
        );
        kept.add(candidate);
        continue;
      }

      // STOP / ceda: solo si no hay semáforo en el cruce y no hay otro igual.
      if (cluster.any((k) => k.poi.kind == RouteMapPoiKind.trafficSignal)) {
        continue;
      }
      if (cluster.any((k) => k.poi.kind == poi.kind)) {
        continue;
      }
      kept.add(candidate);
    }

    kept.sort(
      (a, b) => a.poi.distanceAlongRouteMeters
          .compareTo(b.poi.distanceAlongRouteMeters),
    );
    return [for (final k in kept) k.poi];
  }

  /// Legacy Overpass. Prefer [SpainFuelDatasource.fetchFuelNearRoute].
  @Deprecated('Usar SpainFuelDatasource (caché MITECO)')
  Future<List<RouteAlert>> fetchFuelNearRoute(
    List<GeoPoint> polyline,
  ) async {
    if (polyline.length < 2) {
      return const [];
    }
    final boxes = _sampleBboxes(
      polyline,
      everyMeters: NavigationConstants.overpassSampleEveryMeters,
      bufferMeters: NavigationConstants.routePoiBufferMeters,
    );
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
              'User-Agent': 'MotoAMG/1.0 (navigation; contact@MotoAMG.local)',
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
    List<GeoPoint> polyline, {
    required double everyMeters,
    required double bufferMeters,
  }) {
    final bufferDeg = bufferMeters / 111320.0;
    final anchors = <GeoPoint>[polyline.first];
    var traveled = 0.0;
    for (var i = 1; i < polyline.length; i++) {
      traveled += _haversineMeters(polyline[i - 1], polyline[i]);
      if (traveled >= everyMeters) {
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
