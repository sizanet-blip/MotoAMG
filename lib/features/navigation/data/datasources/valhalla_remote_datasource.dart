import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:loc_motos/core/constants/navigation_constants.dart';
import 'package:loc_motos/features/navigation/data/models/navigation_route_model.dart';
import 'package:loc_motos/features/navigation/data/services/route_guidance_service.dart';
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

    // Alternativas solo con origen+destino (Valhalla no las soporta en multipunto).
    final alternates = locations.length > 2
        ? 0
        : (maxAlternates ?? 3);
    if (locations.length > 2) {
      debugPrint(
        'Valhalla: sin alternativas (ruta con paradas intermedias)',
      );
    }

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
      'turn_lanes': true,
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
      final friendly = _valhallaErrorMessage(response.body);
      if (friendly != null) {
        throw NavigationException(friendly);
      }
      if (_looksLikeNoRoute(response.body)) {
        throw const RouteNotFoundException();
      }
      throw const NavigationException(
        'No se pudo calcular la ruta. Inténtalo de nuevo.',
      );
    }
    final json = jsonDecode(response.body) as Map<String, dynamic>;
    var trips = _rankedTripCandidates(
      json,
      preferTwistier: preferences.curvature.preferTwistierAlternate,
    );
    debugPrint(
      'Valhalla: respuesta con ${trips.length} candidata(s) '
      '(alternates pedidas: $alternates)',
    );

    // Si Valhalla solo da una, segunda petición con otro perfil para ofrecer elección.
    if (trips.length < 2 &&
        locations.length == 2 &&
        (maxAlternates == null || maxAlternates > 0)) {
      final extra = await _fetchAlternateProfileTrips(
        locations: locations,
        costing: costing,
        preferences: preferences,
      );
      if (extra.isNotEmpty) {
        trips = [...trips, ...extra];
        debugPrint(
          'Valhalla: +${extra.length} ruta(s) de perfil alternativo',
        );
      }
    }

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
      // No filtrar agresivo: las alternativas de Valhalla suelen ser válidas
      // aunque tiempo/distancia se parezcan. Solo quitar clones casi idénticos.
      if (_isNearClone(route, routes)) {
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
    debugPrint('Valhalla: ${routes.length} ruta(s) en preview');

    if (!attachSpeedLimits) {
      return routes;
    }
    return Future.wait([
      for (final route in routes) _withAttachedSpeedLimits(route),
    ]);
  }

  Future<NavigationRouteModel> _withAttachedSpeedLimits(
    NavigationRouteModel route,
  ) async {
    final segments = await _fetchSpeedLimitSegments(route.polyline);
    if (segments.isEmpty) {
      return route;
    }
    return route.copyWithSpeedLimits(segments);
  }

  /// Recalcula límites sobre una ruta ya planificada (p. ej. al abrir el HUD).
  Future<NavigationRouteModel> attachSpeedLimitsToRoute(
    NavigationRouteModel route,
  ) {
    return _withAttachedSpeedLimits(route);
  }

  Future<List<SpeedLimitSegment>> _fetchSpeedLimitSegments(
    List<GeoPoint> polyline,
  ) async {
    final traced = await _fetchTraceAttributesJson(
      polyline,
      attributes: const [
        'shape',
        'edge.speed_limit',
        'edge.road_class',
        'edge.use',
        'edge.density',
        'edge.unpaved',
        'edge.begin_shape_index',
        'edge.end_shape_index',
      ],
    );
    if (traced == null) {
      return const [];
    }

    // Índices Valhalla → shape emparejada del response (no la muestra enviada).
    final matchedShape = NavigationRouteModel.decodePolyline6(
      traced['shape'] as String? ?? '',
    );
    if (matchedShape.length < 2) {
      return const [];
    }

    final guidance = RouteGuidanceService();
    int toRouteIndex(int matchedIndex) {
      final idx = matchedIndex.clamp(0, matchedShape.length - 1);
      final along = guidance.distanceAlongRouteMeters(
        matchedShape[idx],
        polyline,
      );
      return guidance.shapeIndexAtDistance(polyline, along);
    }

    return NavigationRouteModel.speedLimitsFromTraceAttributes(
      traced,
      toRouteShapeIndex: toRouteIndex,
    );
  }

  /// Trace attributes genérico (límites, peajes, etc.).
  Future<Map<String, dynamic>?> fetchTraceAttributes(
    List<GeoPoint> polyline, {
    required List<String> attributes,
  }) {
    return _fetchTraceAttributesJson(polyline, attributes: attributes);
  }

  Future<Map<String, dynamic>?> _fetchTraceAttributesJson(
    List<GeoPoint> polyline, {
    required List<String> attributes,
  }) async {
    if (polyline.length < 2 || !isConfigured) {
      return null;
    }
    try {
      final uri =
          Uri.parse('${NavigationConstants.valhallaBaseUrl}/trace_attributes');
      final sample = _samplePolyline(polyline, maxPoints: 800);
      final body = jsonEncode({
        'shape': [
          for (final point in sample) {'lat': point.lat, 'lon': point.lng},
        ],
        'shape_match': 'map_snap',
        'costing': NavigationConstants.valhallaCosting,
        'units': 'kilometers',
        'shape_format': 'polyline6',
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
    final traced = await _fetchTraceAttributesJson(
      polyline,
      attributes: const [
        'shape',
        'edge.toll',
        'edge.begin_shape_index',
        'edge.end_shape_index',
      ],
    );
    if (traced == null) {
      return const [];
    }
    final matchedShape = NavigationRouteModel.decodePolyline6(
      traced['shape'] as String? ?? '',
    );
    final guidance = RouteGuidanceService();
    final edges = traced['edges'] as List<dynamic>? ?? const [];
    final entries = <({GeoPoint point, int beginShapeIndex})>[];
    var previousToll = false;
    for (final raw in edges) {
      if (raw is! Map<String, dynamic>) {
        continue;
      }
      final isToll = raw['toll'] == true;
      final beginMatched = (raw['begin_shape_index'] as num?)?.toInt() ?? 0;
      if (isToll && !previousToll) {
        late final int idx;
        if (matchedShape.length >= 2) {
          final mi = beginMatched.clamp(0, matchedShape.length - 1);
          final along = guidance.distanceAlongRouteMeters(
            matchedShape[mi],
            polyline,
          );
          idx = guidance.shapeIndexAtDistance(polyline, along);
        } else {
          idx = beginMatched.clamp(0, polyline.length - 1);
        }
        entries.add((point: polyline[idx], beginShapeIndex: idx));
      }
      previousToll = isToll;
    }
    return entries;
  }

  List<GeoPoint> _samplePolyline(
    List<GeoPoint> polyline, {
    required int maxPoints,
  }) {
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
    if (main is Map) {
      candidates.add(Map<String, dynamic>.from(main));
    }
    final alts = response['alternates'];
    if (alts is List) {
      for (final raw in alts) {
        if (raw is! Map) {
          continue;
        }
        final map = Map<String, dynamic>.from(raw);
        final trip = map['trip'];
        if (trip is Map) {
          candidates.add(Map<String, dynamic>.from(trip));
        } else if (map['legs'] is List) {
          candidates.add(map);
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
      candidates.sort(
        (a, b) => _tripTimeSeconds(a).compareTo(_tripTimeSeconds(b)),
      );
    }
    return candidates;
  }

  /// Segunda petición con perfil distinto (más/menos autovía) para tener elección.
  Future<List<Map<String, dynamic>>> _fetchAlternateProfileTrips({
    required List<GeoPoint> locations,
    required String costing,
    required RoutePreferences preferences,
  }) async {
    try {
      final flipped = preferences.copyWith(
        avoidHighways: !preferences.avoidHighways,
        curvature: preferences.curvature == RouteCurvatureLevel.fast
            ? RouteCurvatureLevel.moreCurves
            : RouteCurvatureLevel.fast,
      );
      final uri = Uri.parse('${NavigationConstants.valhallaBaseUrl}/route');
      final body = jsonEncode({
        'locations': [
          for (final point in locations)
            {'lat': point.lat, 'lon': point.lng},
        ],
        'costing': costing,
        'costing_options': {
          costing: flipped.toValhallaCostingOptions(costing),
        },
        'directions_options': {'language': 'es-ES', 'units': 'kilometers'},
        'shape_format': 'polyline6',
        'alternates': 2,
      });
      final response = await _client
          .post(
            uri,
            headers: {'Content-Type': 'application/json'},
            body: body,
          )
          .timeout(NavigationConstants.valhallaRequestTimeout);
      if (response.statusCode != 200) {
        return const [];
      }
      final json = jsonDecode(response.body);
      if (json is! Map<String, dynamic>) {
        return const [];
      }
      return _rankedTripCandidates(
        json,
        preferTwistier: flipped.curvature.preferTwistierAlternate,
      );
    } catch (e) {
      debugPrint('Valhalla perfil alternativo falló: $e');
      return const [];
    }
  }

  /// Solo descarta clones casi calcados (misma distancia y tiempo).
  bool _isNearClone(
    NavigationRouteModel candidate,
    List<NavigationRouteModel> existing,
  ) {
    for (final route in existing) {
      final timeDelta =
          (candidate.durationSeconds - route.durationSeconds).abs();
      final distDelta =
          (candidate.distanceMeters - route.distanceMeters).abs();
      final timeSame = timeDelta <= 30;
      final distSame = distDelta <= 400;
      if (timeSame && distSame) {
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

  String? _valhallaErrorMessage(String body) {
    try {
      final json = jsonDecode(body);
      if (json is! Map<String, dynamic>) {
        return null;
      }
      final code = json['error_code'];
      final error = '${json['error'] ?? ''}'.toLowerCase();
      if (code == 154 || error.contains('max distance limit')) {
        return 'El itinerario es demasiado largo o las paradas están muy '
            'separadas. Prueba con menos paradas o un recorrido más corto.';
      }
      if (error.contains('Exceeded max') && error.contains('location')) {
        return 'Hay demasiadas paradas en el itinerario. Reduce el número '
            'de paradas e inténtalo de nuevo.';
      }
      return null;
    } catch (_) {
      return null;
    }
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
