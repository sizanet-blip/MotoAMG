import 'dart:convert';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:http/io_client.dart';
import 'package:moto_amg/core/constants/app_constants.dart';
import 'package:moto_amg/features/tracking/domain/exceptions/location_exceptions.dart';

class GpsTokenClient {
  GpsTokenClient({
    http.Client? httpClient,
    String? Function()? accessTokenLookup,
  })  : _http = httpClient ?? _defaultClient(),
        _accessTokenLookup = accessTokenLookup;

  final http.Client _http;
  final String? Function()? _accessTokenLookup;

  static http.Client _defaultClient() {
    if (!kIsWeb && Platform.isAndroid) {
      final io = HttpClient()
        ..badCertificateCallback = (cert, host, port) => true;
      return IOClient(io);
    }
    return http.Client();
  }

  Future<String> fetchToken({
    required String uid,
    required String groupId,
    required String displayName,
  }) async {
    final uri = Uri.parse(AppConstants.gpsTokenUrl);
    final bearer = _accessTokenLookup?.call();
    final headers = <String, String>{
      'Content-Type': 'application/json',
      'Accept': 'application/json',
      'Host': AppConstants.apiHostHeader,
    };
    final body = <String, dynamic>{
      'uid': uid,
      'groupId': groupId,
      'displayName': displayName,
    };

    if (bearer != null && bearer.isNotEmpty) {
      headers['Authorization'] = 'Bearer $bearer';
    } else {
      headers['X-MotoAmg-Api-Key'] = AppConstants.gpsApiKey;
      body['apiKey'] = AppConstants.gpsApiKey;
    }

    late final http.Response response;
    try {
      response = await _http.post(
        uri,
        headers: headers,
        body: jsonEncode(body),
      );
    } catch (error) {
      throw LocationException('No se pudo pedir el token GPS. $error');
    }

    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw LocationException(
        'Token GPS HTTP ${response.statusCode}: ${response.body}',
      );
    }

    final decoded = jsonDecode(response.body);
    if (decoded is! Map<String, dynamic>) {
      throw const LocationException('Respuesta de token GPS inválida');
    }
    if (decoded['ok'] != true) {
      throw LocationException(
        'Token GPS: ${decoded['message'] ?? 'error desconocido'}',
      );
    }
    final token = decoded['token'];
    if (token is! String || token.isEmpty) {
      throw const LocationException('Token GPS vacío');
    }
    return token;
  }
}
