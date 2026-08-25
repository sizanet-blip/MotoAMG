import 'dart:convert';
import 'dart:math' as math;

import 'package:http/http.dart' as http;
import 'package:loc_motos/core/constants/navigation_constants.dart';
import 'package:loc_motos/features/navigation/domain/entities/geo_point.dart';
import 'package:loc_motos/features/navigation/domain/entities/route_alert.dart';

/// Inventario de radares: DGT NAP + SCT + OSM (huecos urbanos / Euskadi).
///
/// - DGT DATEX II: red estatal excepto Cataluña y País Vasco.
/// - SCT: ficheros UTM ETRS89 zona 31N publicados por Trànsit.
/// - OSM Overpass: complemento en la ruta (municipales, Euskadi, etc.);
///   se omiten si ya hay un oficial a < [NavigationConstants.radarDedupeMeters].
class SpainRadarDatasource {
  SpainRadarDatasource({http.Client? client})
      : _client = client ?? http.Client();

  final http.Client _client;

  List<_RadarPoi>? _inventory;
  DateTime? _inventoryFetchedAt;

  Future<List<RouteAlert>> fetchCamerasNearRoute(
    List<GeoPoint> polyline,
  ) async {
    if (polyline.length < 2) {
      return const [];
    }
    final results = await Future.wait([
      _officialNearRoute(polyline),
      _fetchOsmNearRoute(polyline),
    ]);
    return _mergePreferOfficial(results[0], results[1]);
  }

  Future<List<RouteAlert>> _officialNearRoute(List<GeoPoint> polyline) async {
    final inventory = await _loadOfficialInventory();
    if (inventory.isEmpty) {
      return const [];
    }

    final buffer = NavigationConstants.routePoiBufferMeters;
    final routeBox = _routeBbox(polyline, buffer / 111320.0);
    final alerts = <RouteAlert>[];
    final seen = <String>{};

    for (final poi in inventory) {
      if (poi.point.lat < routeBox.south ||
          poi.point.lat > routeBox.north ||
          poi.point.lng < routeBox.west ||
          poi.point.lng > routeBox.east) {
        continue;
      }
      final projected = _projectOntoRoute(poi.point, polyline);
      if (projected == null || projected.distanceToRoute > buffer) {
        continue;
      }
      final key =
          '${poi.source}_${projected.alongMeters.round()}_${poi.point.lat.toStringAsFixed(4)}';
      if (!seen.add(key)) {
        continue;
      }
      alerts.add(
        RouteAlert(
          id: key,
          type: RouteAlertType.speedCamera,
          point: poi.point,
          distanceAlongRouteMeters: projected.alongMeters,
          label: poi.label,
          meta: poi.road,
          speedLimitKmh: poi.speedLimitKmh,
          radarKind: poi.kind,
        ),
      );
    }
    return alerts;
  }

  List<RouteAlert> _mergePreferOfficial(
    List<RouteAlert> official,
    List<RouteAlert> osm,
  ) {
    final merged = [...official];
    final dedupe = NavigationConstants.radarDedupeMeters;
    for (final candidate in osm) {
      final duplicate = official.any(
        (o) => _haversineMeters(o.point, candidate.point) <= dedupe,
      );
      if (duplicate) {
        continue;
      }
      merged.add(candidate);
    }
    merged.sort(
      (a, b) =>
          a.distanceAlongRouteMeters.compareTo(b.distanceAlongRouteMeters),
    );
    return merged;
  }

  Future<List<_RadarPoi>> _loadOfficialInventory() async {
    final cached = _inventory;
    final at = _inventoryFetchedAt;
    if (cached != null &&
        at != null &&
        DateTime.now().difference(at) < NavigationConstants.spainRadarCacheTtl) {
      return cached;
    }

    final results = await Future.wait([
      _fetchDgt(),
      _fetchSct(NavigationConstants.sctRadaresFijosUrl, trailer: false),
      _fetchSct(NavigationConstants.sctRadaresRemolcUrl, trailer: true),
    ]);

    final merged = <_RadarPoi>[
      ...results[0],
      ...results[1],
      ...results[2],
    ];
    _inventory = List.unmodifiable(merged);
    _inventoryFetchedAt = DateTime.now();
    return _inventory!;
  }

  Future<List<_RadarPoi>> _fetchDgt() async {
    try {
      final response = await _client
          .get(
            Uri.parse(NavigationConstants.dgtRadaresDatexUrl),
            headers: {
              'User-Agent': 'LocMotos/1.0 (navigation; radars; nap.dgt.es)',
              'Accept': 'application/xml,text/xml,*/*',
            },
          )
          .timeout(NavigationConstants.spainRadarRequestTimeout);
      if (response.statusCode != 200 || response.body.isEmpty) {
        return const [];
      }
      return _parseDgtDatex(response.body);
    } catch (_) {
      return const [];
    }
  }

  /// Extrae puntos de cada `predefinedLocation` DATEX (fijos + extremos de tramo).
  List<_RadarPoi> _parseDgtDatex(String xml) {
    final out = <_RadarPoi>[];
    final latRe = RegExp(r'latitude>([-0-9.]+)<');
    final lngRe = RegExp(r'longitude>([-0-9.]+)<');
    final roadRe = RegExp(r'roadNumber>([^<]+)<');

    // Cada bloque con id= (el anidado Point/Linear no trae id).
    final parts = xml.split(RegExp(r'predefinedLocation\s+id="'));
    for (final part in parts.skip(1)) {
      final quote = part.indexOf('"');
      if (quote <= 0) {
        continue;
      }
      final id = part.substring(0, quote);
      final body = part.substring(quote + 1);
      final lats = latRe
          .allMatches(body)
          .map((m) => double.tryParse(m.group(1)!))
          .whereType<double>()
          .toList();
      final lngs = lngRe
          .allMatches(body)
          .map((m) => double.tryParse(m.group(1)!))
          .whereType<double>()
          .toList();
      if (lats.isEmpty || lngs.isEmpty || lats.length != lngs.length) {
        continue;
      }
      final road = roadRe.firstMatch(body)?.group(1)?.trim();
      final isSection = id.contains('CVM') ||
          id.toUpperCase().contains('VELOCIDADMEDIA') ||
          lats.length > 1;
      final kind = isSection ? RadarKind.section : RadarKind.fixed;
      final label = isSection
          ? (road != null && road.isNotEmpty
              ? 'Radar de tramo · $road'
              : 'Radar de tramo')
          : (road != null && road.isNotEmpty ? 'Radar fijo · $road' : 'Radar fijo');

      for (var i = 0; i < lats.length; i++) {
        final lat = lats[i];
        final lng = lngs[i];
        if (lat < 27 || lat > 44 || lng < -19 || lng > 5) {
          continue;
        }
        out.add(
          _RadarPoi(
            point: GeoPoint(lat: lat, lng: lng),
            source: 'dgt',
            kind: kind,
            label: isSection && i > 0 ? '$label (fin)' : label,
            road: road,
          ),
        );
      }
    }
    return out;
  }

  Future<List<_RadarPoi>> _fetchSct(String url, {required bool trailer}) async {
    try {
      final response = await _client
          .get(
            Uri.parse(url),
            headers: {
              'User-Agent': 'LocMotos/1.0 (navigation; radars; transit.gencat.cat)',
              'Accept': 'text/plain,*/*',
            },
          )
          .timeout(NavigationConstants.spainRadarRequestTimeout);
      if (response.statusCode != 200 || response.body.isEmpty) {
        return const [];
      }
      return _parseSctUtm(response.body, trailer: trailer);
    } catch (_) {
      return const [];
    }
  }

  /// Formato SCT: Via / PK / Velocitat / X / Y (UTM ETRS89 zona 31N).
  List<_RadarPoi> _parseSctUtm(String text, {required bool trailer}) {
    final out = <_RadarPoi>[];
    final lines = text.split(RegExp(r'\r?\n'));
    for (final rawLine in lines) {
      final line = rawLine.trim();
      if (line.isEmpty ||
          line.startsWith('(') ||
          line.toLowerCase().startsWith('via')) {
        continue;
      }
      final parts = line.split(RegExp(r'\s+'));
      if (parts.length < 5) {
        continue;
      }
      final x = _parseEuNumber(parts[parts.length - 2]);
      final y = _parseEuNumber(parts[parts.length - 1]);
      final speed = int.tryParse(
        parts[parts.length - 3].replaceAll(',', '.').split('.').first,
      );
      if (x == null || y == null) {
        continue;
      }
      // UTM 31N Cataluña: X ~250–550 km, Y ~4.45–4.75 M.
      if (x < 200000 || x > 600000 || y < 4400000 || y > 4800000) {
        continue;
      }
      final road = parts.first;
      final pk = parts.length >= 5 ? parts[1] : '';
      final isSection = pk.contains('-');
      final kind = trailer
          ? RadarKind.trailer
          : (isSection ? RadarKind.section : RadarKind.fixed);
      final limit =
          (speed != null && speed >= 20 && speed <= 140) ? speed : null;
      final point = _utm31NToWgs84(easting: x, northing: y);
      final speedLabel = limit != null ? ' · $limit km/h' : '';
      final kindLabel = kind.shortLabel.toLowerCase();
      out.add(
        _RadarPoi(
          point: point,
          source: 'sct',
          kind: kind,
          label: road.isNotEmpty
              ? 'Radar $kindLabel · $road$speedLabel'
              : 'Radar $kindLabel$speedLabel',
          road: road,
          speedLimitKmh: limit,
        ),
      );
    }
    return out;
  }

  /// OSM cerca de la polilínea (urbanos / huecos que DGT no publica).
  Future<List<RouteAlert>> _fetchOsmNearRoute(List<GeoPoint> polyline) async {
    final boxes = _sampleBboxes(polyline);
    if (boxes.isEmpty) {
      return const [];
    }
    final parts = <String>[
      for (final b in boxes) ...[
        'node["highway"="speed_camera"](${b.south},${b.west},${b.north},${b.east});',
        'node["enforcement"="maxspeed"](${b.south},${b.west},${b.north},${b.east});',
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
              'User-Agent': 'LocMotos/1.0 (navigation; osm radars)',
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
      final buffer = NavigationConstants.routePoiBufferMeters;

      for (final raw in elements) {
        if (raw is! Map<String, dynamic>) {
          continue;
        }
        final lat = (raw['lat'] as num?)?.toDouble();
        final lon = (raw['lon'] as num?)?.toDouble();
        if (lat == null || lon == null) {
          continue;
        }
        final tags = raw['tags'];
        final tagMap = tags is Map
            ? Map<String, dynamic>.from(tags)
            : const <String, dynamic>{};
        final limit = _parseMaxspeedKmh(tagMap['maxspeed']?.toString());
        final kind = _osmRadarKind(tagMap);
        final point = GeoPoint(lat: lat, lng: lon);
        final projected = _projectOntoRoute(point, polyline);
        if (projected == null || projected.distanceToRoute > buffer) {
          continue;
        }
        final key =
            'osm_${projected.alongMeters.round()}_${lat.toStringAsFixed(4)}';
        if (!seen.add(key)) {
          continue;
        }
        final speedLabel = limit != null ? ' · $limit km/h' : '';
        alerts.add(
          RouteAlert(
            id: key,
            type: RouteAlertType.speedCamera,
            point: point,
            distanceAlongRouteMeters: projected.alongMeters,
            label: '${kind.voiceNoun}$speedLabel',
            speedLimitKmh: limit,
            radarKind: kind,
          ),
        );
      }
      return alerts;
    } catch (_) {
      return const [];
    }
  }

  int? _parseMaxspeedKmh(String? raw) {
    if (raw == null || raw.trim().isEmpty) {
      return null;
    }
    final match = RegExp(r'(\d{2,3})').firstMatch(raw);
    if (match == null) {
      return null;
    }
    final value = int.tryParse(match.group(1)!);
    if (value == null || value < 20 || value > 140) {
      return null;
    }
    return value;
  }

  RadarKind _osmRadarKind(Map<String, dynamic> tags) {
    final joined = [
      tags['speed_camera']?.toString(),
      tags['enforcement']?.toString(),
      tags['camera:type']?.toString(),
      tags['highway']?.toString(),
    ].whereType<String>().join(' ').toLowerCase();
    if (joined.contains('section') ||
        joined.contains('average') ||
        joined.contains('tram') ||
        joined.contains('stretch')) {
      return RadarKind.section;
    }
    if (joined.contains('mobile') || joined.contains('trailer')) {
      return RadarKind.trailer;
    }
    if (tags['highway'] == 'speed_camera' ||
        tags['enforcement'] == 'maxspeed') {
      return RadarKind.fixed;
    }
    return RadarKind.unknown;
  }

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
    if (boxes.isEmpty && polyline.length >= 2) {
      boxes.add(_routeBbox(polyline, bufferDeg));
    }
    return boxes;
  }

  double? _parseEuNumber(String raw) {
    return double.tryParse(raw.trim().replaceAll(',', '.'));
  }

  /// UTM zona 31N → WGS84 (suficiente para avisos; ETRS89 ≈ WGS84 a metros).
  GeoPoint _utm31NToWgs84({required double easting, required double northing}) {
    const a = 6378137.0;
    const f = 1 / 298.257223563;
    const k0 = 0.9996;
    const e0 = 500000.0;
    const n0 = 0.0;
    const lon0 = 3.0 * math.pi / 180; // zona 31 → 3°E

    final e2 = f * (2 - f);
    final ep2 = e2 / (1 - e2);
    final x = easting - e0;
    final y = northing - n0;
    final m = y / k0;
    final mu = m /
        (a *
            (1 -
                e2 / 4 -
                3 * e2 * e2 / 64 -
                5 * e2 * e2 * e2 / 256));

    final e1 = (1 - math.sqrt(1 - e2)) / (1 + math.sqrt(1 - e2));
    final phi1 = mu +
        (3 * e1 / 2 - 27 * e1 * e1 * e1 / 32) * math.sin(2 * mu) +
        (21 * e1 * e1 / 16 - 55 * e1 * e1 * e1 * e1 / 32) * math.sin(4 * mu) +
        (151 * e1 * e1 * e1 / 96) * math.sin(6 * mu);

    final sin1 = math.sin(phi1);
    final cos1 = math.cos(phi1);
    final tan1 = math.tan(phi1);
    final n1 = a / math.sqrt(1 - e2 * sin1 * sin1);
    final t1 = tan1 * tan1;
    final c1 = ep2 * cos1 * cos1;
    final r1 = a * (1 - e2) / math.pow(1 - e2 * sin1 * sin1, 1.5);
    final d = x / (n1 * k0);

    final lat = phi1 -
        (n1 * tan1 / r1) *
            (d * d / 2 -
                (5 + 3 * t1 + 10 * c1 - 4 * c1 * c1 - 9 * ep2) *
                    d *
                    d *
                    d *
                    d /
                    24 +
                (61 + 90 * t1 + 298 * c1 + 45 * t1 * t1 - 252 * ep2 - 3 * c1 * c1) *
                    math.pow(d, 6) /
                    720);
    final lon = lon0 +
        (d -
                (1 + 2 * t1 + c1) * d * d * d / 6 +
                (5 -
                        2 * c1 +
                        28 * t1 -
                        3 * c1 * c1 +
                        8 * ep2 +
                        24 * t1 * t1) *
                    math.pow(d, 5) /
                    120) /
            cos1;

    return GeoPoint(lat: lat * 180 / math.pi, lng: lon * 180 / math.pi);
  }

  ({double south, double west, double north, double east}) _routeBbox(
    List<GeoPoint> polyline,
    double padDeg,
  ) {
    var south = polyline.first.lat;
    var north = polyline.first.lat;
    var west = polyline.first.lng;
    var east = polyline.first.lng;
    for (final p in polyline) {
      south = math.min(south, p.lat);
      north = math.max(north, p.lat);
      west = math.min(west, p.lng);
      east = math.max(east, p.lng);
    }
    return (
      south: south - padDeg,
      west: west - padDeg,
      north: north + padDeg,
      east: east + padDeg,
    );
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
    final dx = b.lng - a.lng;
    final dy = b.lat - a.lat;
    final len2 = dx * dx + dy * dy;
    if (len2 < 1e-18) {
      return (point: a, t: 0);
    }
    final t =
        (((p.lng - a.lng) * dx + (p.lat - a.lat) * dy) / len2).clamp(0.0, 1.0);
    return (
      point: GeoPoint(lat: a.lat + t * dy, lng: a.lng + t * dx),
      t: t,
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

class _RadarPoi {
  const _RadarPoi({
    required this.point,
    required this.source,
    required this.kind,
    required this.label,
    this.road,
    this.speedLimitKmh,
  });

  final GeoPoint point;
  final String source;
  final RadarKind kind;
  final String label;
  final String? road;
  final int? speedLimitKmh;
}
