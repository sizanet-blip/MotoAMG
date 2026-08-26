import 'dart:convert';
import 'dart:math' as math;

import 'package:hive_flutter/hive_flutter.dart';
import 'package:http/http.dart' as http;
import 'package:loc_motos/core/constants/navigation_constants.dart';
import 'package:loc_motos/features/auth/domain/entities/user_vehicle.dart';
import 'package:loc_motos/features/navigation/domain/entities/geo_point.dart';
import 'package:loc_motos/features/navigation/domain/entities/route_alert.dart';

class SpainFuelCacheStatus {
  const SpainFuelCacheStatus({
    required this.count,
    required this.fetchedAt,
  });

  final int count;
  final DateTime? fetchedAt;

  bool get isReady => count > 0;
}

class SpainFuelDownloadProgress {
  const SpainFuelDownloadProgress({
    required this.label,
    this.fraction,
  });

  final String label;
  final double? fraction;
}

class SpainFuelDownloadResult {
  const SpainFuelDownloadResult({
    required this.count,
    this.cancelled = false,
  });

  final int count;
  final bool cancelled;
}

class _FuelStation {
  const _FuelStation({
    required this.id,
    required this.point,
    required this.name,
    required this.prices,
    this.brand,
  });

  final String id;
  final GeoPoint point;
  final String name;
  final Map<String, double> prices;
  final String? brand;

  Map<String, dynamic> toJson() => {
        'id': id,
        'lat': point.lat,
        'lng': point.lng,
        'name': name,
        'brand': brand,
        'prices': prices,
      };

  factory _FuelStation.fromJson(Map<String, dynamic> json) {
    final pricesRaw = json['prices'];
    final prices = <String, double>{};
    if (pricesRaw is Map) {
      for (final entry in pricesRaw.entries) {
        final value = (entry.value as num?)?.toDouble();
        if (value != null) {
          prices[entry.key.toString()] = value;
        }
      }
    }
    return _FuelStation(
      id: json['id']?.toString() ??
          '${json['lat']}_${json['lng']}',
      point: GeoPoint(
        lat: (json['lat'] as num).toDouble(),
        lng: (json['lng'] as num).toDouble(),
      ),
      name: json['name'] as String? ?? 'Gasolinera',
      brand: json['brand'] as String?,
      prices: prices,
    );
  }
}

/// Inventario MITECO de gasolineras (bundle del servidor LocMotos).
class SpainFuelDatasource {
  SpainFuelDatasource({http.Client? client})
      : _client = client ?? http.Client();

  final http.Client _client;
  List<_FuelStation>? _inventory;
  DateTime? _fetchedAt;
  bool _downloadCancelled = false;
  Box<String>? _box;

  Future<Box<String>> _openBox() async {
    _box ??= await Hive.openBox<String>(NavigationConstants.spainFuelBox);
    return _box!;
  }

  Future<SpainFuelCacheStatus> readCacheStatus() async {
    final disk = await _readDisk();
    return SpainFuelCacheStatus(
      count: disk?.stations.length ?? _inventory?.length ?? 0,
      fetchedAt: disk?.fetchedAt ?? _fetchedAt,
    );
  }

  void cancelDownload() {
    _downloadCancelled = true;
  }

  Future<SpainFuelDownloadResult> downloadToCache({
    void Function(SpainFuelDownloadProgress progress)? onProgress,
  }) async {
    _downloadCancelled = false;
    onProgress?.call(
      const SpainFuelDownloadProgress(
        label: 'Descargando gasolineras desde el servidor…',
        fraction: null,
      ),
    );
    final bundle = await _fetchBundle();
    if (_downloadCancelled) {
      return const SpainFuelDownloadResult(count: 0, cancelled: true);
    }
    if (bundle == null || bundle.stations.isEmpty) {
      onProgress?.call(
        const SpainFuelDownloadProgress(
          label: 'No se pudo descargar el inventario',
          fraction: 1,
        ),
      );
      return const SpainFuelDownloadResult(count: 0);
    }
    final at = bundle.updatedAt ?? DateTime.now();
    final immutable = List<_FuelStation>.unmodifiable(bundle.stations);
    _inventory = immutable;
    _fetchedAt = at;
    await _writeDisk(immutable, at);
    onProgress?.call(
      SpainFuelDownloadProgress(
        label: 'Listo: ${immutable.length} gasolineras',
        fraction: 1,
      ),
    );
    return SpainFuelDownloadResult(count: immutable.length);
  }

  Future<List<RouteAlert>> fetchFuelNearRoute(
    List<GeoPoint> polyline, {
    VehicleFuelType? preferredFuel,
  }) async {
    if (polyline.length < 2) {
      return const [];
    }
    final inventory = await _loadInventory();
    if (inventory.isEmpty) {
      return const [];
    }
    final buffer = NavigationConstants.routePoiBufferMeters;
    final routeBox = _routeBbox(polyline, buffer / 111320.0);
    final alerts = <RouteAlert>[];
    final seen = <String>{};

    for (final station in inventory) {
      if (station.point.lat < routeBox.south ||
          station.point.lat > routeBox.north ||
          station.point.lng < routeBox.west ||
          station.point.lng > routeBox.east) {
        continue;
      }
      final projected = _projectOntoRoute(station.point, polyline);
      if (projected == null || projected.distanceToRoute > buffer) {
        continue;
      }
      final key =
          'fuel_${projected.alongMeters.round()}_${station.point.lat.toStringAsFixed(4)}';
      if (!seen.add(key)) {
        continue;
      }
      alerts.add(
        RouteAlert(
          id: key,
          type: RouteAlertType.fuel,
          point: station.point,
          distanceAlongRouteMeters: projected.alongMeters,
          label: _labelFor(station, preferredFuel),
          meta: station.brand ?? station.name,
        ),
      );
    }
    alerts.sort(
      (a, b) =>
          a.distanceAlongRouteMeters.compareTo(b.distanceAlongRouteMeters),
    );
    return alerts;
  }

  String _labelFor(_FuelStation station, VehicleFuelType? preferredFuel) {
    final title = (station.brand ?? station.name).trim().toUpperCase();
    final prices = station.prices;
    final head = title.isEmpty ? 'GASOLINERA' : title;
    if (prices.isEmpty) {
      return head;
    }

    final preferredKey = preferredFuel?.priceKey;
    if (preferredKey != null && prices.containsKey(preferredKey)) {
      final price = prices[preferredKey]!;
      return '$head\n${_fuelShort(preferredKey)} ${_formatPrice(price)}';
    }

    // Sin preferencia / sin vehículo: todos los combustibles disponibles.
    final parts = <String>[];
    const order = [
      'gasolina95',
      'gasolina95e10',
      'gasolina98',
      'gasolina98e10',
      'gasoleoA',
      'gasoleoPremium',
      'gasoleoB',
    ];
    final seenShort = <String>{};
    for (final key in order) {
      final value = prices[key];
      if (value == null) {
        continue;
      }
      final short = _fuelShort(key);
      if (!seenShort.add(short)) {
        continue;
      }
      parts.add('$short ${_formatPrice(value)}');
    }
    for (final entry in prices.entries) {
      final short = _fuelShort(entry.key);
      if (!seenShort.add(short)) {
        continue;
      }
      parts.add('$short ${_formatPrice(entry.value)}');
    }
    if (parts.isEmpty) {
      return head;
    }
    return '$head\n${parts.join('\n')}';
  }

  String _fuelShort(String key) => switch (key) {
        'gasolina95' || 'gasolina95e10' => '95',
        'gasolina98' || 'gasolina98e10' => '98',
        'gasoleoA' => 'Gasóleo',
        'gasoleoPremium' => 'G.Prem',
        'gasoleoB' => 'G.B',
        _ => key,
      };

  String _formatPrice(double value) =>
      '${value.toStringAsFixed(3).replaceAll('.', ',')} €';

  Future<List<_FuelStation>> _loadInventory() async {
    if (_inventory != null && _inventory!.isNotEmpty) {
      return _inventory!;
    }
    final disk = await _readDisk();
    if (disk != null &&
        DateTime.now().difference(disk.fetchedAt) <=
            NavigationConstants.spainFuelDiskMaxAge) {
      _inventory = disk.stations;
      _fetchedAt = disk.fetchedAt;
      return disk.stations;
    }
    return const [];
  }

  Future<({List<_FuelStation> stations, DateTime? updatedAt})?>
      _fetchBundle() async {
    try {
      final response = await _client
          .get(
            Uri.parse(NavigationConstants.spainFuelBundleUrl),
            headers: {
              'User-Agent': 'LocMotos/1.0 (navigation; fuel bundle)',
              'Accept': 'application/json',
            },
          )
          .timeout(NavigationConstants.spainFuelBundleTimeout);
      if (_downloadCancelled ||
          response.statusCode != 200 ||
          response.body.isEmpty) {
        return null;
      }
      final decoded = jsonDecode(response.body);
      if (decoded is! Map<String, dynamic>) {
        return null;
      }
      final updatedAt =
          DateTime.tryParse(decoded['updatedAt']?.toString() ?? '');
      final raw = decoded['stations'];
      if (raw is! List) {
        return null;
      }
      final stations = <_FuelStation>[
        for (final item in raw)
          if (item is Map<String, dynamic>)
            _FuelStation.fromJson(item)
          else if (item is Map)
            _FuelStation.fromJson(Map<String, dynamic>.from(item)),
      ];
      if (stations.isEmpty) {
        return null;
      }
      return (stations: stations, updatedAt: updatedAt);
    } catch (_) {
      return null;
    }
  }

  Future<({List<_FuelStation> stations, DateTime fetchedAt})?> _readDisk() async {
    try {
      final box = await _openBox();
      final raw = box.get(NavigationConstants.spainFuelInventoryKey);
      final atRaw = box.get(NavigationConstants.spainFuelFetchedAtKey);
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
      final stations = <_FuelStation>[
        for (final item in decoded)
          if (item is Map<String, dynamic>)
            _FuelStation.fromJson(item)
          else if (item is Map)
            _FuelStation.fromJson(Map<String, dynamic>.from(item)),
      ];
      if (stations.isEmpty) {
        return null;
      }
      return (
        stations: List<_FuelStation>.unmodifiable(stations),
        fetchedAt: fetchedAt,
      );
    } catch (_) {
      return null;
    }
  }

  Future<void> _writeDisk(List<_FuelStation> stations, DateTime at) async {
    try {
      final box = await _openBox();
      await box.put(
        NavigationConstants.spainFuelInventoryKey,
        jsonEncode([for (final s in stations) s.toJson()]),
      );
      await box.put(
        NavigationConstants.spainFuelFetchedAtKey,
        at.toIso8601String(),
      );
    } catch (_) {}
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
    var traveled = 0.0;
    for (var i = 1; i < polyline.length; i++) {
      final a = polyline[i - 1];
      final b = polyline[i];
      final segLen = _haversineMeters(a, b);
      final projected = _projectOnSegment(point, a, b);
      final d = _haversineMeters(point, projected.point);
      if (d < bestDist) {
        bestDist = d;
        bestAlong = traveled + projected.t * segLen;
      }
      traveled += segLen;
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
    final abLat = b.lat - a.lat;
    final abLng = b.lng - a.lng;
    final apLat = p.lat - a.lat;
    final apLng = p.lng - a.lng;
    final ab2 = abLat * abLat + abLng * abLng;
    if (ab2 < 1e-18) {
      return (point: a, t: 0);
    }
    final t = ((apLat * abLat + apLng * abLng) / ab2).clamp(0.0, 1.0);
    return (
      point: GeoPoint(lat: a.lat + abLat * t, lng: a.lng + abLng * t),
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
