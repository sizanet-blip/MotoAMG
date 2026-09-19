import 'package:moto_amg/core/api/motoamg_api_client.dart';
import 'package:moto_amg/core/constants/app_constants.dart';
import 'package:moto_amg/features/intercom/domain/entities/intercom_token_credentials.dart';

/// Pide el JWT LiveKit al panel MySQL (sesión Bearer + membresía + intercom on).
class IntercomTokenRemoteDataSource {
  IntercomTokenRemoteDataSource({required MotoAmgApiClient api}) : _api = api;

  final MotoAmgApiClient _api;

  Future<IntercomTokenCredentials> fetchToken({required String groupId}) async {
    try {
      final map = await _api.post(
        '/motoamg/groups/$groupId/livekit-token',
        auth: true,
      );
      final url = map['url']?.toString() ?? AppConstants.liveKitUrl;
      final token = map['token']?.toString() ?? '';
      final room = map['room']?.toString() ?? groupId;
      if (token.isEmpty) {
        throw IntercomTokenException('Respuesta de token vacía.');
      }
      return IntercomTokenCredentials(url: url, token: token, room: room);
    } on MotoAmgApiException catch (e) {
      final code = e.statusCode;
      final msg = e.message.toLowerCase();
      if (code == 401) {
        throw IntercomTokenException(
          'Sesión no válida para el intercom.',
          statusCode: 401,
        );
      }
      if (code == 403) {
        if (msg.contains('apagado') || msg.contains('intercom')) {
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
      if (code == 503) {
        throw IntercomTokenException(
          'Intercom no configurado en el panel (falta secreto LiveKit).',
          statusCode: 503,
        );
      }
      throw IntercomTokenException(
        e.message.isNotEmpty
            ? e.message
            : 'Intercom no disponible (${code ?? '?'}).',
        statusCode: code,
      );
    }
  }
}
