import 'dart:convert';
import 'dart:math' as math;

import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:moto_amg/core/api_usage/api_usage_tracker.dart';
import 'package:moto_amg/core/constants/navigation_constants.dart';
import 'package:moto_amg/features/navigation/data/models/navigation_route_model.dart';
import 'package:moto_amg/features/navigation/data/services/route_guidance_service.dart';
import 'package:moto_amg/features/navigation/domain/entities/geo_point.dart';
import 'package:moto_amg/features/navigation/domain/entities/speed_limit_segment.dart';

/// TomTom Snap to Roads: límites legales a lo largo de una polilínea de ruta.
///
/// Requiere `--dart-define=TOMTOM_API_KEY=...`. Sin key o si falla la red,
/// devuelve lista vacía (el caller sigue con Valhalla/DGT).
class TomTomSnapToRoadsDataSource {
  TomTomSnapToRoadsDataSource({
    http.Client? client,
    String? apiKey,
    ApiUsageTracker? usage,
  })  : _client = client ?? http.Client(),
        _apiKey = apiKey ?? NavigationConstants.tomtomApiKey,
        _usage = usage ?? ApiUsageTracker.instance;

  final http.Client _client;
  final String _apiKey;
  final ApiUsageTracker _usage;

  static const _fields =
      '{route{type,geometry{type,coordinates},properties{speedLimits{value,unit,type}}}}';

  bool get isConfigured => _apiKey.trim().isNotEmpty;

  Future<List<SpeedLimitSegment>> fetchSpeedLimitSegments(
    List<GeoPoint> routePolyline,
  ) async {
    if (!isConfigured) {
      debugPrint('TomTom: sin API key (falta --dart-define=TOMTOM_API_KEY)');
      _usage.record(
        api: MotoAmgApi.tomtomSnapToRoads,
        outcome: ApiCallOutcome.skipped,
        message: 'Sin API key',
      );
      return const [];
    }
    if (routePolyline.length < 2) {
      return const [];
    }

    try {
      final sample = samplePolylineForSnap(routePolyline);
      if (sample.length < 2) {
        return const [];
      }

      final chunks = chunkPolylineByMaxDistance(
        sample,
        maxMeters: NavigationConstants.tomtomSnapMaxPathMeters,
      );
      debugPrint(
        'TomTom: snapToRoads en ${chunks.length} tramo(s) '
        '(${sample.length} puntos)…',
      );

      final all = <SpeedLimitSegment>[];
      var okChunks = 0;
      var failChunks = 0;
      String? lastError;

      for (var i = 0; i < chunks.length; i++) {
        final chunk = chunks[i];
        final result = await _fetchChunk(
          chunkPoints: chunk,
          routePolyline: routePolyline,
          chunkIndex: i + 1,
          chunkTotal: chunks.length,
        );
        if (result.segments != null) {
          all.addAll(result.segments!);
          okChunks++;
          _usage.record(
            api: MotoAmgApi.tomtomSnapToRoads,
            outcome: ApiCallOutcome.success,
            httpStatus: 200,
            message:
                'Tramo ${i + 1}/${chunks.length}: ${result.segments!.length} límites',
          );
        } else {
          failChunks++;
          lastError = result.errorMessage;
          _usage.record(
            api: MotoAmgApi.tomtomSnapToRoads,
            outcome: ApiCallOutcome.failure,
            httpStatus: result.httpStatus,
            message: result.errorMessage ?? 'Error en tramo ${i + 1}',
            detail: result.errorDetail,
          );
        }
      }

      final merged = NavigationRouteModel.coalesceSpeedLimits(all);
      if (okChunks == 0) {
        debugPrint('TomTom: todos los tramos fallaron ($lastError)');
        return const [];
      }
      debugPrint(
        'TomTom: OK → ${merged.length} tramos de límite '
        '($okChunks OK, $failChunks fallos)',
      );
      return merged;
    } catch (e, st) {
      debugPrint('TomTom snapToRoads failed: $e\n$st');
      _usage.record(
        api: MotoAmgApi.tomtomSnapToRoads,
        outcome: ApiCallOutcome.failure,
        message: 'Error de red o timeout',
        detail: e.toString(),
      );
      return const [];
    }
  }

  Future<
      ({
        List<SpeedLimitSegment>? segments,
        int? httpStatus,
        String? errorMessage,
        String? errorDetail,
      })> _fetchChunk({
    required List<GeoPoint> chunkPoints,
    required List<GeoPoint> routePolyline,
    required int chunkIndex,
    required int chunkTotal,
  }) async {
    debugPrint(
      'TomTom: tramo $chunkIndex/$chunkTotal '
      '(${chunkPoints.length} puntos)…',
    );

    final uri = Uri.parse(NavigationConstants.tomtomSnapToRoadsUrl).replace(
      queryParameters: {
        'key': _apiKey,
        'fields': _fields,
        'vehicleType': 'PassengerCar',
        'measurementSystem': 'metric',
      },
    );

    final body = jsonEncode({
      'points': [
        for (final point in chunkPoints)
          {
            'type': 'Feature',
            'geometry': {
              'type': 'Point',
              'coordinates': [point.lng, point.lat],
            },
          },
      ],
    });

    final response = await _client
        .post(
          uri,
          headers: {'Content-Type': 'application/json'},
          body: body,
        )
        .timeout(NavigationConstants.tomtomRequestTimeout);

    if (response.statusCode != 200) {
      final shortBody = response.body.length > 200
          ? response.body.substring(0, 200)
          : response.body;
      debugPrint(
        'TomTom snapToRoads HTTP ${response.statusCode}: $shortBody',
      );
      return (
        segments: null,
        httpStatus: response.statusCode,
        errorMessage: _friendlyHttpMessage(response.statusCode, shortBody),
        errorDetail: shortBody,
      );
    }

    final decoded = jsonDecode(response.body);
    if (decoded is! Map<String, dynamic>) {
      return (
        segments: null,
        httpStatus: response.statusCode,
        errorMessage: 'Respuesta no válida',
        errorDetail: null,
      );
    }
    final segments = segmentsFromSnapResponse(
      decoded,
      routePolyline: routePolyline,
    );
    return (
      segments: segments,
      httpStatus: 200,
      errorMessage: null,
      errorDetail: null,
    );
  }

  static String _friendlyHttpMessage(int status, String body) {
    if (status == 403) {
      return 'Sin permiso (403). Activa Snap to Roads en esa API key.';
    }
    if (status == 401) {
      return 'Key inválida (401).';
    }
    if (status == 429) {
      return 'Cupo agotado o demasiadas peticiones (429).';
    }
    if (body.contains('Distance limit') || body.contains('INVALID_REQUEST')) {
      return 'Ruta demasiado larga para un solo tramo (límite ~100 km).';
    }
    if (body.contains('Forbidden')) {
      return 'Prohibido ($status). Revisa productos de la key.';
    }
    return 'Error HTTP $status';
  }

  /// Parte el trazado en trozos ≤ [maxMeters] (límite de distancia TomTom).
  static List<List<GeoPoint>> chunkPolylineByMaxDistance(
    List<GeoPoint> points, {
    double maxMeters = NavigationConstants.tomtomSnapMaxPathMeters,
  }) {
    if (points.length < 2) {
      return [List.unmodifiable(points)];
    }
    final chunks = <List<GeoPoint>>[];
    var current = <GeoPoint>[points.first];
    var length = 0.0;

    for (var i = 1; i < points.length; i++) {
      final next = points[i];
      final step = _haversineMeters(current.last, next);
      if (current.length >= 2 && length + step > maxMeters) {
        chunks.add(List.unmodifiable(current));
        current = [current.last, next];
        length = _haversineMeters(current.first, current.last);
      } else {
        current.add(next);
        length += step;
      }
    }
    if (current.length >= 2) {
      chunks.add(List.unmodifiable(current));
    }
    return chunks;
  }

  /// Muestreo compatible con límites Snap to Roads (≤5000 pts, gap ≤6 km).
  static List<GeoPoint> samplePolylineForSnap(
    List<GeoPoint> polyline, {
    int maxPoints = NavigationConstants.tomtomSnapMaxPoints,
    double maxGapMeters = NavigationConstants.tomtomSnapMaxGapMeters,
  }) {
    if (polyline.length < 2) {
      return List.unmodifiable(polyline);
    }

    final densified = <GeoPoint>[polyline.first];
    for (var i = 1; i < polyline.length; i++) {
      final prev = densified.last;
      final next = polyline[i];
      var gap = _haversineMeters(prev, next);
      if (gap <= maxGapMeters) {
        densified.add(next);
        continue;
      }
      final steps = (gap / maxGapMeters).ceil();
      for (var s = 1; s < steps; s++) {
        final t = s / steps;
        densified.add(
          GeoPoint(
            lat: prev.lat + (next.lat - prev.lat) * t,
            lng: prev.lng + (next.lng - prev.lng) * t,
          ),
        );
      }
      densified.add(next);
    }

    if (densified.length <= maxPoints) {
      return List.unmodifiable(densified);
    }

    final step = (densified.length - 1) / (maxPoints - 1);
    return List.unmodifiable([
      for (var i = 0; i < maxPoints; i++)
        densified[(i * step).round().clamp(0, densified.length - 1)],
    ]);
  }

  /// Parsea la respuesta Snap to Roads sobre la polilínea Valhalla.
  static List<SpeedLimitSegment> segmentsFromSnapResponse(
    Map<String, dynamic> json, {
    required List<GeoPoint> routePolyline,
    RouteGuidanceService? guidance,
  }) {
    if (routePolyline.length < 2) {
      return const [];
    }
    final route = json['route'];
    if (route is! List) {
      return const [];
    }

    final guide = guidance ?? RouteGuidanceService();
    final raw = <SpeedLimitSegment>[];

    for (final element in route) {
      if (element is! Map) {
        continue;
      }
      final map = Map<String, dynamic>.from(element);
      final props = map['properties'];
      if (props is! Map) {
        continue;
      }
      final limitKmh = _speedLimitKmh(Map<String, dynamic>.from(props));
      if (limitKmh == null) {
        continue;
      }

      final geometry = map['geometry'];
      if (geometry is! Map) {
        continue;
      }
      final coords = geometry['coordinates'];
      if (coords is! List || coords.isEmpty) {
        continue;
      }

      final points = <GeoPoint>[];
      for (final c in coords) {
        if (c is! List || c.length < 2) {
          continue;
        }
        final lon = (c[0] as num?)?.toDouble();
        final lat = (c[1] as num?)?.toDouble();
        if (lon == null || lat == null) {
          continue;
        }
        points.add(GeoPoint(lat: lat, lng: lon));
      }
      if (points.isEmpty) {
        continue;
      }

      final beginAlong =
          guide.distanceAlongRouteMeters(points.first, routePolyline);
      final endAlong =
          guide.distanceAlongRouteMeters(points.last, routePolyline);
      var begin = guide.shapeIndexAtDistance(routePolyline, beginAlong);
      var end = guide.shapeIndexAtDistance(routePolyline, endAlong);
      if (begin > end) {
        final tmp = begin;
        begin = end;
        end = tmp;
      }
      raw.add(
        SpeedLimitSegment(
          beginShapeIndex: begin,
          endShapeIndex: end,
          speedLimitKmh: limitKmh,
        ),
      );
    }

    raw.sort((a, b) => a.beginShapeIndex.compareTo(b.beginShapeIndex));
    return NavigationRouteModel.coalesceSpeedLimits(raw);
  }

  static int? _speedLimitKmh(Map<String, dynamic> properties) {
    final speedLimits = properties['speedLimits'];
    if (speedLimits is! Map) {
      return null;
    }
    final map = Map<String, dynamic>.from(speedLimits);
    final type = (map['type'] as String?)?.toLowerCase();
    // Solo límites máximos señalados / legales, no perfiles de flujo.
    if (type != null && type.isNotEmpty && type != 'maximum') {
      return null;
    }
    final value = (map['value'] as num?)?.toDouble();
    if (value == null || value <= 0) {
      return null;
    }
    final unit = (map['unit'] as String?)?.toLowerCase() ?? 'kmph';
    final kmh = switch (unit) {
      'mph' || 'mi/h' => value * 1.60934,
      _ => value,
    };
    final rounded = kmh.round();
    if (rounded <= 0 || rounded > 160) {
      return null;
    }
    return rounded;
  }

  static double _haversineMeters(GeoPoint a, GeoPoint b) {
    const earthRadius = 6371000.0;
    final dLat = _toRadians(b.lat - a.lat);
    final dLng = _toRadians(b.lng - a.lng);
    final lat1 = _toRadians(a.lat);
    final lat2 = _toRadians(b.lat);
    final h = math.sin(dLat / 2) * math.sin(dLat / 2) +
        math.cos(lat1) *
            math.cos(lat2) *
            math.sin(dLng / 2) *
            math.sin(dLng / 2);
    return 2 * earthRadius * math.asin(math.sqrt(h));
  }

  static double _toRadians(double deg) => deg * math.pi / 180;
}
