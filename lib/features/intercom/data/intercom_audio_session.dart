// LiveKit audio session APIs are marked @experimental; we use them on purpose.
// ignore_for_file: experimental_member_use

import 'package:livekit_client/livekit_client.dart';

/// Política de audio del intercom: música en paralelo; solo baja al hablar.
///
/// LiveKit por defecto usa [AudioSessionOptions.communication] (modo llamada),
/// que en Android/iOS suele pausar Spotify desde que se conecta. Aquí usamos
/// un perfil tipo navegación: mezcla en reposo y duck al hablar.
abstract final class IntercomAudioSession {
  static var _initialized = false;

  /// Conectado, nadie habla: no monopolizar el audio del sistema.
  static const idle = AudioSessionOptions.communication(
    apple: AppleAudioSessionConfiguration(
      category: AppleAudioCategory.playAndRecord,
      categoryOptions: {
        AppleAudioCategoryOption.allowBluetooth,
        AppleAudioCategoryOption.allowBluetoothA2DP,
        AppleAudioCategoryOption.allowAirPlay,
        AppleAudioCategoryOption.mixWithOthers,
      },
      mode: AppleAudioMode.default_,
    ),
    android: AndroidAudioSessionConfiguration(
      audioMode: AndroidAudioMode.normal,
      manageAudioFocus: false,
      focusMode: AndroidAudioFocusMode.gainTransientMayDuck,
      streamType: AndroidAudioStreamType.music,
      usageType: AndroidAudioAttributesUsageType.voiceCommunication,
      contentType: AndroidAudioAttributesContentType.speech,
      forceAudioRouting: true,
    ),
  );

  /// Alguien habla (o tú): baja la música como un aviso de GPS.
  static const speaking = AudioSessionOptions.communication(
    apple: AppleAudioSessionConfiguration(
      category: AppleAudioCategory.playAndRecord,
      categoryOptions: {
        AppleAudioCategoryOption.allowBluetooth,
        AppleAudioCategoryOption.allowBluetoothA2DP,
        AppleAudioCategoryOption.allowAirPlay,
        AppleAudioCategoryOption.duckOthers,
        AppleAudioCategoryOption.mixWithOthers,
      },
      mode: AppleAudioMode.voiceChat,
    ),
    android: AndroidAudioSessionConfiguration(
      audioMode: AndroidAudioMode.normal,
      manageAudioFocus: true,
      focusMode: AndroidAudioFocusMode.gainTransientMayDuck,
      streamType: AndroidAudioStreamType.music,
      usageType:
          AndroidAudioAttributesUsageType.assistanceNavigationGuidance,
      contentType: AndroidAudioAttributesContentType.speech,
      forceAudioRouting: true,
    ),
  );

  static Future<void> ensureConfigured() async {
    if (_initialized) {
      return;
    }
    await LiveKitClient.initialize(initialAudioSessionOptions: idle);
    await AudioManager.instance.setAudioSessionOptions(idle);
    _initialized = true;
  }

  static Future<void> applyIdle() async {
    await ensureConfigured();
    await AudioManager.instance.setAudioSessionOptions(idle);
  }

  /// Activa duck de música mientras hay voz en el canal.
  static Future<void> applySpeaking() async {
    await ensureConfigured();
    await AudioManager.instance.setAudioSessionOptions(speaking);
  }

  /// Al desconectar: suelta el foco para que la música vuelva al normal.
  static Future<void> releaseOnDisconnect() async {
    if (!_initialized) {
      return;
    }
    try {
      await AudioManager.instance.deactivateAudioSession();
    } catch (_) {}
  }
}
