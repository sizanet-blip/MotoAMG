import 'dart:convert';

import 'package:http/http.dart' as http;
import 'package:loc_motos/core/constants/navigation_constants.dart';
import 'package:loc_motos/features/navigation/data/models/navigation_route_model.dart';
import 'package:loc_motos/features/navigation/domain/entities/geo_point.dart';
import 'package:loc_motos/features/navigation/domain/exceptions/navigation_exceptions.dart';

class ValhallaRemoteDataSource {
  ValhallaRemoteDataSource({http.Client? client}) : _client = client ?? http.Client();

  final http.Client _client;

  bool get isConfigured => NavigationConstants.valhallaBaseUrl.isNotEmpty;

  Future<NavigationRouteModel> fetchRoute({
    required GeoPoint origin,
    required GeoPoint destination,
  }) async {
    if (!isConfigured) {
      throw const NavigationException(
        'Servidor Valhalla no configurado. Usa modo demo o configura la URL.',
      );
    }
    final uri = Uri.parse('${NavigationConstants.valhallaBaseUrl}/route');
    final body = jsonEncode({
      'locations': [
        {'lat': origin.lat, 'lon': origin.lng, 'type': 'break'},
        {'lat': destination.lat, 'lon': destination.lng, 'type': 'break'},
      ],
      'costing': NavigationConstants.valhallaCosting,
      'costing_options': {
        NavigationConstants.valhallaCosting: {
          'use_highways': 0.3,
          'use_tracks': 0,
          'use_trails': 0,
          'avoid_bad_surfaces': true,
        },
      },
      'directions_options': {'language': 'es-ES', 'units': 'kilometers'},
      'shape_format': 'polyline6',
    });
    final response = await _client
        .post(
          uri,
          headers: {'Content-Type': 'application/json'},
          body: body,
        )
        .timeout(NavigationConstants.valhallaRequestTimeout);
    if (response.statusCode != 200) {
      final detail = _errorMessageFromBody(response.body);
      throw NavigationException(
        detail ??
            'Valhalla respondió ${response.statusCode}. '
            'Comprueba que el servidor esté accesible.',
      );
    }
    final json = jsonDecode(response.body) as Map<String, dynamic>;
    return NavigationRouteModel.fromValhalla(
      json,
      origin: origin,
      destination: destination,
    );
  }

  String? _errorMessageFromBody(String body) {
    try {
      final json = jsonDecode(body);
      if (json is Map<String, dynamic>) {
        final error = json['error'];
        if (error is String && error.isNotEmpty) {
          return 'Valhalla: $error';
        }
        final message = json['message'];
        if (message is String && message.isNotEmpty) {
          return 'Valhalla: $message';
        }
      }
    } catch (_) {
      // Respuesta no JSON; se usará el mensaje genérico.
    }
    return null;
  }
}
