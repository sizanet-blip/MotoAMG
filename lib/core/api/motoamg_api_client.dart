import 'dart:convert';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:http/io_client.dart';
import 'package:moto_amg/core/constants/app_constants.dart';

class MotoAmgApiException implements Exception {
  const MotoAmgApiException(this.message, {this.statusCode});

  final String message;
  final int? statusCode;

  @override
  String toString() => message;
}

/// Cliente HTTP hacia el panel MySQL (`/motoamg/...`).
class MotoAmgApiClient {
  MotoAmgApiClient({
    http.Client? httpClient,
    Future<String?> Function()? tokenResolver,
  })  : _http = httpClient ?? _defaultClient(),
        _tokenResolver = tokenResolver;

  final http.Client _http;
  final Future<String?> Function()? _tokenResolver;
  String? _accessToken;

  static http.Client _defaultClient() {
    // Emulador → https://10.0.2.2 con cert del vhost local.
    if (!kIsWeb && Platform.isAndroid) {
      final io = HttpClient()
        ..badCertificateCallback = (cert, host, port) => true;
      return IOClient(io);
    }
    return http.Client();
  }

  String? get accessToken => _accessToken;

  void setAccessToken(String? token) {
    _accessToken = token;
  }

  Uri _uri(String path) {
    final base = AppConstants.apiBaseUrl.replaceAll(RegExp(r'/$'), '');
    final p = path.startsWith('/') ? path : '/$path';
    return Uri.parse('$base$p');
  }

  Future<Map<String, dynamic>> post(
    String path, {
    Map<String, dynamic>? body,
    bool auth = false,
  }) async {
    return _send('POST', path, body: body, auth: auth);
  }

  Future<Map<String, dynamic>> get(String path, {bool auth = true}) async {
    return _send('GET', path, auth: auth);
  }

  Future<Map<String, dynamic>> delete(String path, {bool auth = true}) async {
    return _send('DELETE', path, auth: auth);
  }

  Future<Map<String, dynamic>> _send(
    String method,
    String path, {
    Map<String, dynamic>? body,
    bool auth = false,
  }) async {
    final headers = <String, String>{
      'Content-Type': 'application/json',
      'Accept': 'application/json',
      'Host': AppConstants.apiHostHeader,
    };
    if (auth) {
      var token = _accessToken;
      if (token == null || token.isEmpty) {
        token = await _tokenResolver?.call();
        if (token != null && token.isNotEmpty) {
          _accessToken = token;
        }
      }
      // Segundo intento: a veces el resolver aún no ha abierto Hive.
      if (token == null || token.isEmpty) {
        await Future<void>.delayed(const Duration(milliseconds: 50));
        token = await _tokenResolver?.call();
        if (token != null && token.isNotEmpty) {
          _accessToken = token;
        }
      }
      if (token == null || token.isEmpty) {
        throw const MotoAmgApiException(
          'No hay sesión. Cierra la app y vuelve a entrar con tu cuenta.',
        );
      }
      headers['Authorization'] = 'Bearer $token';
    }

    late final http.Response response;
    try {
      final uri = _uri(path);
      if (method == 'GET') {
        response = await _http.get(uri, headers: headers);
      } else if (method == 'DELETE') {
        response = await _http.delete(uri, headers: headers);
      } else {
        response = await _http.post(
          uri,
          headers: headers,
          body: jsonEncode(body ?? const <String, dynamic>{}),
        );
      }
    } catch (e) {
      throw MotoAmgApiException('Sin conexión con el panel. $e');
    }

    Map<String, dynamic> decoded;
    try {
      final raw = jsonDecode(response.body);
      decoded = raw is Map<String, dynamic>
          ? raw
          : <String, dynamic>{'ok': false, 'message': response.body};
    } catch (_) {
      throw MotoAmgApiException(
        'Respuesta inválida (${response.statusCode})',
        statusCode: response.statusCode,
      );
    }

    if (response.statusCode < 200 ||
        response.statusCode >= 300 ||
        decoded['ok'] == false) {
      throw MotoAmgApiException(
        '${decoded['message'] ?? 'Error ${response.statusCode}'}',
        statusCode: response.statusCode,
      );
    }
    return decoded;
  }
}
