import 'package:flutter/foundation.dart';
import 'package:flutter_tts/flutter_tts.dart';

/// Copiloto por voz (flutter_tts).
class NavigationVoiceService {
  NavigationVoiceService() : _tts = FlutterTts();

  final FlutterTts _tts;
  var _ready = false;
  var _muted = false;

  /// Aviso de pelotón / emergencia en curso: las maniobras no lo interrumpen.
  var _urgentSpeaking = false;

  /// Evita que el [stop] previo a un speakUrgent limpie [_urgentSpeaking].
  var _ignoreTtsEnd = false;

  /// Alguien habla por intercom: bajamos volumen y no lanzamos maniobras.
  var _intercomDuck = false;

  bool get isMuted => _muted;

  bool get isUrgentSpeaking => _urgentSpeaking;

  bool get isIntercomDuck => _intercomDuck;

  Future<void> init() async {
    if (_ready) {
      return;
    }
    await _tts.setLanguage('es-ES');
    await _tts.setSpeechRate(0.48);
    await _tts.setVolume(1);
    _tts.setCompletionHandler(_onTtsFinished);
    _tts.setCancelHandler(_onTtsFinished);
    _tts.setErrorHandler((_) => _onTtsFinished());
    if (defaultTargetPlatform == TargetPlatform.android) {
      await _tts.setAudioAttributesForNavigation();
      await _tts.setQueueMode(1);
    } else if (defaultTargetPlatform == TargetPlatform.iOS) {
      await _tts.setIosAudioCategory(
        IosTextToSpeechAudioCategory.playback,
        [
          IosTextToSpeechAudioCategoryOptions.duckOthers,
          IosTextToSpeechAudioCategoryOptions
              .interruptSpokenAudioAndMixWithOthers,
          IosTextToSpeechAudioCategoryOptions.allowBluetooth,
          IosTextToSpeechAudioCategoryOptions.allowBluetoothA2DP,
        ],
        IosTextToSpeechAudioMode.voicePrompt,
      );
      await _tts.autoStopSharedSession(true);
    }
    _ready = true;
  }

  void _onTtsFinished() {
    if (_ignoreTtsEnd) {
      return;
    }
    _urgentSpeaking = false;
  }

  Future<void> setMuted(bool muted) async {
    _muted = muted;
    if (muted && !_urgentSpeaking) {
      await stop();
    }
  }

  /// Baja el copiloto mientras hay voz remota en el intercom.
  Future<void> setIntercomDuck(bool duck) async {
    if (_intercomDuck == duck) {
      return;
    }
    _intercomDuck = duck;
    await init();
    await _tts.setVolume(duck ? 0.18 : 1);
    if (duck && !_urgentSpeaking) {
      await stop();
    }
  }

  /// Maniobras / copiloto de ruta. No habla si hay mute, duck o aviso urgente.
  Future<void> speak(String text) async {
    if (_muted || _intercomDuck || text.trim().isEmpty || _urgentSpeaking) {
      return;
    }
    await _speakNow(text, urgent: false);
  }

  /// Pelotón / emergencias: ignora mute y no lo pisan las maniobras.
  Future<void> speakUrgent(String text) async {
    if (text.trim().isEmpty) {
      return;
    }
    await _speakNow(text, urgent: true);
  }

  Future<void> _speakNow(String text, {required bool urgent}) async {
    await init();
    if (!urgent && (_urgentSpeaking || _intercomDuck)) {
      return;
    }

    _ignoreTtsEnd = true;
    _urgentSpeaking = urgent;
    try {
      await _tts.stop();
    } finally {
      _ignoreTtsEnd = false;
    }
    _urgentSpeaking = urgent;
    await _tts.setVolume(_intercomDuck ? 0.35 : 1);

    if (defaultTargetPlatform == TargetPlatform.android) {
      await _tts.speak(text, focus: true);
    } else if (defaultTargetPlatform == TargetPlatform.iOS) {
      await _tts.setSharedInstance(true);
      await _tts.speak(text);
    } else {
      await _tts.speak(text);
    }
  }

  Future<void> stop() async {
    _ignoreTtsEnd = true;
    try {
      await _tts.stop();
    } finally {
      _ignoreTtsEnd = false;
      _urgentSpeaking = false;
    }
  }
}
