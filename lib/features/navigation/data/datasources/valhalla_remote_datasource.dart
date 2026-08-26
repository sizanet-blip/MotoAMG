import 'dart:convert';
import 'dart:math' as math;

import 'package:http/http.dart' as http;
import 'package:loc_motos/core/constants/navigation_constants.dart';
import 'package:loc_motos/features/navigation/data/models/navigation_route_model.dart';
import 'package:loc_motos/features/navigation/domain/entities/geo_point.dart';
import 'package:loc_motos/features/navigation/domain/entities/route_preferences.dart';
import 'package:loc_motos/features/navigation/domain/entities/speed_limit_segment.dart';
import 'package:loc_motos/features/navigation/domain/exceptions/navigation_exceptions.dart';

class ValhallaRemoteDataSource {
  ValhallaRemoteDataSource({http.Client? client})
      : _client = client ?? http.Client();

  final http.Client _client;

  bool get isConfigured => NavigationConstants.valhallaBaseUrl.isNotEmpty;

  /// Una sola ruta (p. ej. recálculo en navegación).
  Future<NavigationRouteModel> fetchRoute({
    required GeoPoint origin,
    required GeoPoint destination,
    List<GeoPoint> waypoints = const [],
    RoutePreferences preferences = RoutePreferences.defaults,
    String costing = NavigationConstants.valhallaCosting,
  }) async {
    final routes = await fetchRoutes(
      origin: origin,
      destination: destination,
      waypoints: waypoints,
      preferences: preferences,
      costing: costing,
      maxAlternates: 0,
      attachSpeedLimits: true,
    );
    return routes.first;
  }

  /// Hasta 3 rutas distintas para elegir en la vista previa.
  Future<List<NavigationRouteModel>> fetchRoutes({
    required GeoPoint origin,
    required GeoPoint destination,
    List<GeoPoint> waypoints = const [],
    RoutePreferences preferences = RoutePreferences.defaults,
    String costing = NavigationConstants.valhallaCosting,
    int? maxAlternates,
    bool attachSpeedLimits = true,
  }) async {
    if (!isConfigured) {
      throw const NavigationException(
        'No se puede calcular la ruta ahora mismo.',
      );
    }
    final locations = <GeoPoint>[origin, ...waypoints, destination];
    if (locations.length < 2) {
      throw const NavigationException(
        'Hacen falta al menos origen y destino.',
      );
    }

    // Siempre pedimos alternativas en preview (estilo Sygic); en recálculo 0.
    final alternates = maxAlternates ??
        math.max(2, preferences.curvature.alternateCount);

    final uri = Uri.parse('${NavigationConstants.valhallaBaseUrl}/route');
    final requestBody = <String, dynamic>{
      'locations': [
        for (final point in locations)
          {'lat': point.lat, 'lon': point.lng},
      ],
      'costing': costing,
      'costing_options': {
        costing: preferences.toValhallaCostingOptions(costing),
      },
      'directions_options': {'language': 'es-ES', 'units': 'kilometers'},
      'shape_format': 'polyline6',
    };
    if (alternates > 0) {
      requestBody['alternates'] = alternates;
    }
    final body = jsonEncode(requestBody);
    final response = await _client
        .post(
          uri,
          headers: {'Content-Type': 'application/json'},
          body: body,
        )
        .timeout(NavigationConstants.valhallaRequestTimeout);
    if (response.statusCode != 200) {
      if (_looksLikeNoRoute(response.body)) {
        throw const RouteNotFoundException();
      }
      throw const NavigationException(
        'No se pudo calcular la ruta. Inténtalo de nuevo.',
      );
    }
    final json = jsonDecode(response.body) as Map<String, dynamic>;
    final trips = _rankedTripCandidates(
      json,
      preferTwistier: preferences.curvature.preferTwistierAlternate,
    );

    final baseId = DateTime.now().millisecondsSinceEpoch.toString();
    final routes = <NavigationRouteModel>[];
    for (var i = 0; i < trips.length; i++) {
      final route = NavigationRouteModel.fromValhalla(
        {'trip': trips[i]},
        origin: origin,
        destination: destination,
        waypoints: waypoints,
        id: '${baseId}_$i',
      );
      if (route.polyline.length < 2) {
        continue;
      }
      if (_isNearDuplicate(route, routes)) {
        continue;
      }
      routes.add(route);
      if (routes.length >= 3) {
        break;
      }
    }
    if (routes.isEmpty) {
      throw const RouteNotFoundException();
    }

    if (!attachSpeedLimits) {
      return routes;
    }
    final segments = await _fetchSpeedLimitSegments(routes.first.polyline);
    if (segments.isEmpty) {
      return routes;
    }
    return [
      routes.first.copyWithSpeedLimits(segments),
      ...routes.skip(1),
    ];
  }

  Future<List<SpeedLimitSegment>> _fetchSpeedLimitSegments(
    List<GeoPoint> polyline,
  ) async {
    final traced = await fetchTraceAttributes(
      polyline,
      attributes: const [
        'edge.speed_limit',
        'edge.begin_shape_index',
        'edge.end_shape_index',
      ],
    );
    if (traced == null) {
      return const [];
    }
    return NavigationRouteModel.speedLimitsFromTraceAttributes(traced);
  }

  /// Trace attributes genérico (límites, peajes, etc.).
  Future<Map<String, dynamic>?> fetchTraceAttributes(
    List<GeoPoint> polyline, {
    required List<String> attributes,
  }) async {
    if (polyline.length < 2 || !isConfigured) {
      return null;
    }
    try {
      final uri =
          Uri.parse('${NavigationConstants.valhallaBaseUrl}/trace_attributes');
      // Muestrear polilíneas muy largas para no saturar el body.
      final sampled = _samplePolyline(polyline, maxPoints: 800);
      final body = jsonEncode({
        'shape': [
          for (final point in sampled) {'lat': point.lat, 'lon': point.lng},
        ],
        'shape_match': 'map_snap',
        'costing': NavigationConstants.valhallaCosting,
        'units': 'kilometers',
        'filters': {
          'action': 'include',
          'attributes': attributes,
        },
      });
      final response = await _client
          .post(
            uri,
            headers: {'Content-Type': 'application/json'},
            body: body,
          )
          .timeout(NavigationConstants.valhallaRequestTimeout);
      if (response.statusCode != 200) {
        return null;
      }
      final json = jsonDecode(response.body);
      if (json is! Map<String, dynamic>) {
        return null;
      }
      return json;
    } catch (_) {
      return null;
    }
  }

  /// Inicios de peaje a lo largo de la ruta (metros desde origen).
  Future<List<({GeoPoint point, int beginShapeIndex})>> fetchTollEntries(
    List<GeoPoint> polyline,
  ) async {
    final traced = await fetchTraceAttributes(
      polyline,
      attributes: const [
        'edge.toll',
        'edge.begin_shape_index',
        'edge.end_shape_index',
      ],
    );
    if (traced == null) {
      return const [];
    }
    final edges = traced['edges'] as List<dynamic>? ?? const [];
    final entries = <({GeoPoint point, int beginShapeIndex})>[];
    var previousToll = false;
    for (final raw in edges) {
      if (raw is! Map<String, dynamic>) {
        continue;
      }
      final isToll = raw['toll'] == true;
      final begin = (raw['begin_shape_index'] as num?)?.toInt() ?? 0;
      if (isToll && !previousToll) {
        final idx = begin.clamp(0, polyline.length - 1);
        entries.add((point: polyline[idx], beginShapeIndex: idx));
      }
      previousToll = isToll;
    }
    return entries;
  }

  List<GeoPoint> _samplePolyline(List<GeoPoint> polyline, {required int maxPoints}) {
    if (polyline.length <= maxPoints) {
      return polyline;
    }
    final step = (polyline.length - 1) / (maxPoints - 1);
    return [
      for (var i = 0; i < maxPoints; i++)
        polyline[(i * step).round().clamp(0, polyline.length - 1)],
    ];
  }

  List<Map<String, dynamic>> _rankedTripCandidates(
    Map<String, dynamic> response, {
    required bool preferTwistier,
  }) {
    final candidates = <Map<String, dynamic>>[];
    final main = response['trip'];
    if (main is Map<String, dynamic>) {
      candidates.add(main);
    }
    final alts = response['alternates'];
    if (alts is List) {
      for (final raw in alts) {
        if (raw is! Map<String, dynamic>) {
          continue;
        }
        final trip = raw['trip'];
        if (trip is Map<String, dynamic>) {
          candidates.add(trip);
        } else if (raw['legs'] is List) {
          candidates.add(raw);
        }
      }
    }
    if (candidates.isEmpty) {
      throw const RouteNotFoundException();
    }
    if (candidates.length == 1) {
      return candidates;
    }

    if (preferTwistier) {
      candidates.sort((a, b) {
        final scoreCmp = _twistScore(b).compareTo(_twistScore(a));
        if (scoreCmp != 0) {
          return scoreCmp;
        }
        return _tripLengthKm(b).compareTo(_tripLengthKm(a));
      });
    } else {
      // Más rápida primero; el resto por tiempo.
      candidates.sort(
        (a, b) => _tripTimeSeconds(a).compareTo(_tripTimeSeconds(b)),
      );
    }
    return candidates;
  }

  bool _isNearDuplicate(
    NavigationRouteModel candidate,
    List<NavigationRouteModel> existing,
  ) {
    for (final route in existing) {
      final timeDelta =
          (candidate.durationSeconds - route.durationSeconds).abs();
      final distDelta =
          (candidate.distanceMeters - route.distanceMeters).abs();
      final timeSimilar = timeDelta <=
          math.max(90, route.durationSeconds * 0.03);
      final distSimilar = distDelta <=
          math.max(1500, route.distanceMeters * 0.03);
      if (timeSimilar && distSimilar) {
        return true;
      }
    }
    return false;
  }

  double _twistScore(Map<String, dynamic> trip) {
    final maneuvers = _tripManeuverCount(trip);
    final km = _tripLengthKm(trip);
    return maneuvers + km * 0.2;
  }

  int _tripManeuverCount(Map<String, dynamic> trip) {
    final legs = trip['legs'] as List<dynamic>? ?? const [];
    var count = 0;
    for (final legDyn in legs) {
      if (legDyn is! Map<String, dynamic>) {
        continue;
      }
      final maneuvers = legDyn['maneuvers'] as List<dynamic>? ?? const [];
      count += maneuvers.length;
    }
    return count;
  }

  double _tripLengthKm(Map<String, dynamic> trip) {
    final summary = trip['summary'] as Map<String, dynamic>?;
    return (summary?['length'] as num?)?.toDouble() ?? 0;
  }

  int _tripTimeSeconds(Map<String, dynamic> trip) {
    final summary = trip['summary'] as Map<String, dynamic>?;
    return (summary?['time'] as num?)?.round() ?? 1 << 30;
  }

  bool _looksLikeNoRoute(String body) {
    try {
      final json = jsonDecode(body);
      if (json is! Map<String, dynamic>) {
        return false;
      }
      final blob =
          '${json['error'] ?? ''} ${json['message'] ?? ''}'.toLowerCase();
      return blob.contains('no path') ||
          blob.contains('no route') ||
          blob.contains('could not find') ||
          blob.contains('impossible');
    } catch (_) {
      return false;
    }
  }
}
