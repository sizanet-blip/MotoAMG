import 'dart:convert';

import 'package:firebase_auth/firebase_auth.dart';
import 'package:http/http.dart' as http;
import 'package:loc_motos/core/constants/app_constants.dart';
import 'package:loc_motos/features/intercom/domain/entities/intercom_token_credentials.dart';

class IntercomTokenRemoteDataSource {
  IntercomTokenRemoteDataSource({
    FirebaseAuth? auth,
    http.Client? client,
    this.tokenUrl = AppConstants.liveKitTokenUrl,
  })  : _auth = auth ?? FirebaseAuth.instance,
        _client = client ?? http.Client();

  final FirebaseAuth _auth;
  final http.Client _client;
  final String tokenUrl;

  Future<IntercomTokenCredentials> fetchToken({required String groupId}) async {
    final user = _auth.currentUser;
    if (user == null) {
      throw IntercomTokenException('No hay sesión de Firebase.');
    }

    final idToken = await user.getIdToken();
    if (idToken == null || idToken.isEmpty) {
      throw IntercomTokenException('No se pudo obtener el token de Firebase.');
    }

    final response = await _client
        .post(
          Uri.parse(tokenUrl),
          headers: {
            'Authorization': 'Bearer $idToken',
            'Content-Type': 'application/json',
          },
          body: jsonEncode({'groupId': groupId}),
        )
        .timeout(const Duration(seconds: 15));

    if (response.statusCode == 401) {
      throw IntercomTokenException(
        'Sesión no válida para el intercom.',
        statusCode: 401,
      );
    }
    if (response.statusCode == 403) {
      final body = response.body.toLowerCase();
      if (body.contains('intercom_disabled')) {
        throw IntercomTokenException(
          'El intercom del grupo está apagado.',
          statusCode: 403,
        );
      }
      throw IntercomTokenException(
        'No eres miembro de este grupo.',
        statusCode: 403,
      );
    }
    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw IntercomTokenException(
        'Intercom no disponible (${response.statusCode}).',
        statusCode: response.statusCode,
      );
    }

    final map = jsonDecode(response.body) as Map<String, dynamic>;
    final url = map['url']?.toString() ?? AppConstants.liveKitUrl;
    final token = map['token']?.toString() ?? '';
    final room = map['room']?.toString() ?? groupId;
    if (token.isEmpty) {
      throw IntercomTokenException('Respuesta de token vacía.');
    }
    return IntercomTokenCredentials(url: url, token: token, room: room);
  }
}
