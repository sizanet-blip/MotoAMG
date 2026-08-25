import 'dart:convert';

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

  Future<NavigationRouteModel> fetchRoute({
    required GeoPoint origin,
    required GeoPoint destination,
    List<GeoPoint> waypoints = const [],
    RoutePreferences preferences = RoutePreferences.defaults,
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
    final uri = Uri.parse('${NavigationConstants.valhallaBaseUrl}/route');
    final requestBody = <String, dynamic>{
      'locations': [
        for (final point in locations)
          {'lat': point.lat, 'lon': point.lng},
      ],
      'costing': NavigationConstants.valhallaCosting,
      'costing_options': {
        NavigationConstants.valhallaCosting:
            preferences.toValhallaCostingOptions(),
      },
      'directions_options': {'language': 'es-ES', 'units': 'kilometers'},
      'shape_format': 'polyline6',
    };
    final alternates = preferences.curvature.alternateCount;
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
    final selected = _selectTripJson(
      json,
      preferTwistier: preferences.curvature.preferTwistierAlternate,
    );
    final route = NavigationRouteModel.fromValhalla(
      {'trip': selected},
      origin: origin,
      destination: destination,
      waypoints: waypoints,
    );

    if (route.polyline.length < 2) {
      return route;
    }
    final segments = await _fetchSpeedLimitSegments(route.polyline);
    if (segments.isEmpty) {
      return route;
    }
    return route.copyWithSpeedLimits(segments);
  }

  Future<List<SpeedLimitSegment>> _fetchSpeedLimitSegments(
    List<GeoPoint> polyline,
  ) async {
    try {
      final uri =
          Uri.parse('${NavigationConstants.valhallaBaseUrl}/trace_attributes');
      final body = jsonEncode({
        'shape': [
          for (final point in polyline) {'lat': point.lat, 'lon': point.lng},
        ],
        'shape_match': 'map_snap',
        'costing': NavigationConstants.valhallaCosting,
        'units': 'kilometers',
        'filters': {
          'action': 'include',
          'attributes': [
            'edge.speed_limit',
            'edge.begin_shape_index',
            'edge.end_shape_index',
          ],
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
        return const [];
      }
      final json = jsonDecode(response.body);
      if (json is! Map<String, dynamic>) {
        return const [];
      }
      return NavigationRouteModel.speedLimitsFromTraceAttributes(json);
    } catch (_) {
      // Los límites son opcionales: la ruta sigue siendo usable.
      return const [];
    }
  }

  /// Elige el viaje principal o una alternativa según el estilo.
  Map<String, dynamic> _selectTripJson(
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
        } else {
          // Algunas builds devuelven el trip plano.
          if (raw['legs'] is List) {
            candidates.add(raw);
          }
        }
      }
    }
    if (candidates.isEmpty) {
      throw const RouteNotFoundException();
    }
    if (candidates.length == 1) {
      return candidates.first;
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
    return candidates.first;
  }

  /// Más maniobras y algo más de km = más “vueltas”.
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
