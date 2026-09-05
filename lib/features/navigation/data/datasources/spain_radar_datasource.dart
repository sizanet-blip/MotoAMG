import 'dart:convert';
import 'dart:math' as math;

import 'package:hive_flutter/hive_flutter.dart';
import 'package:http/http.dart' as http;
import 'package:moto_amg/core/constants/navigation_constants.dart';
import 'package:moto_amg/features/navigation/domain/entities/geo_point.dart';
import 'package:moto_amg/features/navigation/domain/entities/route_alert.dart';

/// Estado de la caché local de radares (oficial + OSM).
class SpainRadarCacheStatus {
  const SpainRadarCacheStatus({
    required this.officialCount,
    required this.officialFetchedAt,
    required this.osmCount,
    required this.osmFetchedAt,
  });

  final int officialCount;
  final DateTime? officialFetchedAt;
  final int osmCount;
  final DateTime? osmFetchedAt;

  bool get hasOfficial => officialCount > 0;
  bool get hasOsm => osmCount > 0;
  bool get isReady => hasOfficial && hasOsm;
}

/// Progreso de descarga manual (Configuración).
class SpainRadarDownloadProgress {
  const SpainRadarDownloadProgress({
    required this.phase,
    required this.completed,
    required this.total,
    required this.label,
  });

  /// `official` o `osm`.
  final String phase;
  final int completed;
  final int total;
  final String label;

  double? get fraction {
    if (total <= 0) {
      return null;
    }
    return (completed / total).clamp(0.0, 1.0);
  }
}

class SpainRadarDownloadResult {
  const SpainRadarDownloadResult({
    required this.officialCount,
    required this.osmCount,
    this.cancelled = false,
  });

  final int officialCount;
  final int osmCount;
  final bool cancelled;
}

/// Inventario de radares: bundle del servidor MotoAMG + fallback DGT/SCT.
///
/// - Descarga manual (Configuración): `…/radares/es.json` (DGT+SCT+OSM).
/// - En ruta: oficiales desde caché (fallback DGT/SCT si falta); OSM solo caché.
class SpainRadarDatasource {
  SpainRadarDatasource({http.Client? client})
      : _client = client ?? http.Client();

  final http.Client _client;

  List<_RadarPoi>? _inventory;
  DateTime? _inventoryFetchedAt;
  List<_RadarPoi>? _osmInventory;
  DateTime? _osmInventoryFetchedAt;
  bool _downloadCancelled = false;
  Box<String>? _box;

  Future<Box<String>> _openBox() async {
    _box ??= await Hive.openBox<String>(NavigationConstants.spainRadarBox);
    return _box!;
  }

  Future<SpainRadarCacheStatus> readCacheStatus() async {
    final official = await _readDiskInventory(
      NavigationConstants.spainRadarInventoryKey,
      NavigationConstants.spainRadarFetchedAtKey,
    );
    final osm = await _readDiskInventory(
      NavigationConstants.spainOsmRadarInventoryKey,
      NavigationConstants.spainOsmRadarFetchedAtKey,
    );
    return SpainRadarCacheStatus(
      officialCount: official?.pois.length ?? _inventory?.length ?? 0,
      officialFetchedAt: official?.fetchedAt ?? _inventoryFetchedAt,
      osmCount: osm?.pois.length ?? _osmInventory?.length ?? 0,
      osmFetchedAt: osm?.fetchedAt ?? _osmInventoryFetchedAt,
    );
  }

  void cancelDownload() {
    _downloadCancelled = true;
  }

  /// Descarga el bundle `es.json` del servidor y lo guarda en Hive.
  Future<SpainRadarDownloadResult> downloadToCache({
    void Function(SpainRadarDownloadProgress progress)? onProgress,
  }) async {
    _downloadCancelled = false;
    onProgress?.call(
      const SpainRadarDownloadProgress(
        phase: 'bundle',
        completed: 0,
        total: 1,
        label: 'Descargando inventario desde el servidor…',
      ),
    );

    final bundle = await _fetchServerBundle();
    if (_downloadCancelled) {
      return const SpainRadarDownloadResult(
        officialCount: 0,
        osmCount: 0,
        cancelled: true,
      );
    }
    if (bundle == null) {
      onProgress?.call(
        const SpainRadarDownloadProgress(
          phase: 'bundle',
          completed: 1,
          total: 1,
          label: 'No se pudo descargar el inventario',
        ),
      );
      return const SpainRadarDownloadResult(officialCount: 0, osmCount: 0);
    }

    final fetchedAt = bundle.updatedAt ?? DateTime.now();
    if (bundle.official.isNotEmpty) {
      final immutable = List<_RadarPoi>.unmodifiable(bundle.official);
      _inventory = immutable;
      _inventoryFetchedAt = fetchedAt;
      await _writeDiskInventory(
        NavigationConstants.spainRadarInventoryKey,
        NavigationConstants.spainRadarFetchedAtKey,
        immutable,
        fetchedAt,
      );
    }
    if (bundle.osm.isNotEmpty) {
      final immutable = List<_RadarPoi>.unmodifiable(bundle.osm);
      _osmInventory = immutable;
      _osmInventoryFetchedAt = fetchedAt;
      await _writeDiskInventory(
        NavigationConstants.spainOsmRadarInventoryKey,
        NavigationConstants.spainOsmRadarFetchedAtKey,
        immutable,
        fetchedAt,
      );
    }

    onProgress?.call(
      SpainRadarDownloadProgress(
        phase: 'bundle',
        completed: 1,
        total: 1,
        label:
            'Listo: ${bundle.official.length} oficiales · ${bundle.osm.length} OSM',
      ),
    );

    return SpainRadarDownloadResult(
      officialCount: bundle.official.length,
      osmCount: bundle.osm.length,
    );
  }

  Future<({List<_RadarPoi> official, List<_RadarPoi> osm, DateTime? updatedAt})?>
      _fetchServerBundle() async {
    try {
      final response = await _client
          .get(
            Uri.parse(NavigationConstants.spainRadarBundleUrl),
            headers: {
              'User-Agent': 'MotoAMG/1.0 (navigation; radar bundle)',
              'Accept': 'application/json',
            },
          )
          .timeout(NavigationConstants.spainRadarBundleTimeout);
      if (_downloadCancelled) {
        return null;
      }
      if (response.statusCode != 200 || response.body.isEmpty) {
        return null;
      }
      return _parseServerBundle(response.body);
    } catch (_) {
      return null;
    }
  }

  ({List<_RadarPoi> official, List<_RadarPoi> osm, DateTime? updatedAt})?
      _parseServerBundle(String body) {
    try {
      final decoded = jsonDecode(body);
      if (decoded is! Map<String, dynamic>) {
        return null;
      }
      final updatedAt = DateTime.tryParse(
        decoded['updatedAt']?.toString() ?? '',
      );
      final official = _parsePoiList(decoded['official']);
      final osm = _parsePoiList(decoded['osm']);
      if (official.isEmpty && osm.isEmpty) {
        return null;
      }
      return (official: official, osm: osm, updatedAt: updatedAt);
    } catch (_) {
      return null;
    }
  }

  List<_RadarPoi> _parsePoiList(Object? raw) {
    if (raw is! List) {
      return const [];
    }
    return [
      for (final item in raw)
        if (item is Map<String, dynamic>)
          _RadarPoi.fromJson(item)
        else if (item is Map)
          _RadarPoi.fromJson(Map<String, dynamic>.from(item)),
    ];
  }

  Future<List<RouteAlert>> fetchCamerasNearRoute(
    List<GeoPoint> polyline,
  ) async {
    if (polyline.length < 2) {
      return const [];
    }
    final results = await Future.wait([
      _loadOfficialInventory(),
      _loadOsmInventory(),
    ]);
    final official = _alertsNearRoute(results[0], polyline, idPrefix: null);
    final osm = _alertsNearRoute(results[1], polyline, idPrefix: 'osm');
    return _mergePreferOfficial(official, osm);
  }

  List<RouteAlert> _alertsNearRoute(
    List<_RadarPoi> inventory,
    List<GeoPoint> polyline, {
    required String? idPrefix,
  }) {
    if (inventory.isEmpty) {
      return const [];
    }
    final buffer = NavigationConstants.radarRouteBufferMeters;
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
      final prefix = idPrefix ?? poi.source;
      final key =
          '${prefix}_${projected.alongMeters.round()}_${poi.point.lat.toStringAsFixed(4)}';
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
    return _loadCachedInventory(
      memory: () => (_inventory, _inventoryFetchedAt),
      setMemory: (pois, at) {
        _inventory = pois;
        _inventoryFetchedAt = at;
      },
      diskKey: NavigationConstants.spainRadarInventoryKey,
      diskAtKey: NavigationConstants.spainRadarFetchedAtKey,
      fetchRemote: _fetchOfficialFromNetwork,
    );
  }

  /// OSM solo desde memoria/disco (bundle del servidor vía Configuración).
  Future<List<_RadarPoi>> _loadOsmInventory() async {
    final mem = _osmInventory;
    if (mem != null && mem.isNotEmpty) {
      return mem;
    }

    final disk = await _readDiskInventory(
      NavigationConstants.spainOsmRadarInventoryKey,
      NavigationConstants.spainOsmRadarFetchedAtKey,
    );

    if (disk != null &&
        DateTime.now().difference(disk.fetchedAt) <=
            NavigationConstants.spainRadarDiskMaxAge) {
      _osmInventory = disk.pois;
      _osmInventoryFetchedAt = disk.fetchedAt;
      return disk.pois;
    }

    return const [];
  }

  Future<List<_RadarPoi>> _loadCachedInventory({
    required (List<_RadarPoi>?, DateTime?) Function() memory,
    required void Function(List<_RadarPoi> pois, DateTime at) setMemory,
    required String diskKey,
    required String diskAtKey,
    required Future<List<_RadarPoi>> Function() fetchRemote,
  }) async {
    final (mem, memAt) = memory();
    if (mem != null &&
        memAt != null &&
        DateTime.now().difference(memAt) <
            NavigationConstants.spainRadarCacheTtl) {
      return mem;
    }

    final disk = await _readDiskInventory(diskKey, diskAtKey);
    final diskFresh = disk != null &&
        DateTime.now().difference(disk.fetchedAt) <
            NavigationConstants.spainRadarCacheTtl;

    if (diskFresh) {
      setMemory(disk.pois, disk.fetchedAt);
      return disk.pois;
    }

    final remote = await fetchRemote();
    if (remote.isNotEmpty) {
      final now = DateTime.now();
      final immutable = List<_RadarPoi>.unmodifiable(remote);
      setMemory(immutable, now);
      await _writeDiskInventory(diskKey, diskAtKey, immutable, now);
      return immutable;
    }

    if (disk != null &&
        DateTime.now().difference(disk.fetchedAt) <=
            NavigationConstants.spainRadarDiskMaxAge) {
      setMemory(disk.pois, disk.fetchedAt);
      return disk.pois;
    }

    setMemory(const [], DateTime.now());
    return const [];
  }

  Future<List<_RadarPoi>> _fetchOfficialFromNetwork() async {
    try {
      final results = await Future.wait([
        _fetchDgt(),
        _fetchSct(NavigationConstants.sctRadaresFijosUrl, trailer: false),
        _fetchSct(NavigationConstants.sctRadaresRemolcUrl, trailer: true),
      ]);
      return [
        ...results[0],
        ...results[1],
        ...results[2],
      ];
    } catch (_) {
      return const [];
    }
  }

  Future<({List<_RadarPoi> pois, DateTime fetchedAt})?> _readDiskInventory(
    String inventoryKey,
    String fetchedAtKey,
  ) async {
    try {
      final box = await _openBox();
      final raw = box.get(inventoryKey);
      final atRaw = box.get(fetchedAtKey);
      if (raw == null || atRaw == null) {
        return null;
      }
      final fetchedAt = DateTime.tryParse(atRaw);
      if (fetchedAt == null) {
        return null;
      }
      final decoded = jsonDecode(raw);
      if (decoded is! List) {
        return null;
      }
      final pois = <_RadarPoi>[
        for (final item in decoded)
          if (item is Map<String, dynamic>)
            _RadarPoi.fromJson(item)
          else if (item is Map)
            _RadarPoi.fromJson(Map<String, dynamic>.from(item)),
      ];
      if (pois.isEmpty) {
        return null;
      }
      return (
        pois: List<_RadarPoi>.unmodifiable(pois),
        fetchedAt: fetchedAt,
      );
    } catch (_) {
      return null;
    }
  }

  Future<void> _writeDiskInventory(
    String inventoryKey,
    String fetchedAtKey,
    List<_RadarPoi> pois,
    DateTime fetchedAt,
  ) async {
    try {
      final box = await _openBox();
      await box.put(
        inventoryKey,
        jsonEncode([for (final p in pois) p.toJson()]),
      );
      await box.put(fetchedAtKey, fetchedAt.toIso8601String());
    } catch (_) {
      // Caché opcional: si falla el disco, seguimos en memoria.
    }
  }

  Future<List<_RadarPoi>> _fetchDgt() async {
    try {
      final response = await _client
          .get(
            Uri.parse(NavigationConstants.dgtRadaresDatexUrl),
            headers: {
              'User-Agent': 'MotoAMG/1.0 (navigation; radars; nap.dgt.es)',
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
              'User-Agent': 'MotoAMG/1.0 (navigation; radars; transit.gencat.cat)',
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

  Map<String, dynamic> toJson() => {
        'lat': point.lat,
        'lng': point.lng,
        'source': source,
        'kind': kind.name,
        'label': label,
        'road': road,
        'speedLimitKmh': speedLimitKmh,
      };

  factory _RadarPoi.fromJson(Map<String, dynamic> json) {
    final kindName = json['kind'] as String? ?? 'unknown';
    final kind = RadarKind.values.firstWhere(
      (k) => k.name == kindName,
      orElse: () => RadarKind.unknown,
    );
    return _RadarPoi(
      point: GeoPoint(
        lat: (json['lat'] as num).toDouble(),
        lng: (json['lng'] as num).toDouble(),
      ),
      source: json['source'] as String? ?? 'unknown',
      kind: kind,
      label: json['label'] as String? ?? 'Radar',
      road: json['road'] as String?,
      speedLimitKmh: (json['speedLimitKmh'] as num?)?.toInt(),
    );
  }
}
