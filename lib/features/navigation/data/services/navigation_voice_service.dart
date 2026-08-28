import 'package:flutter/foundation.dart';
import 'package:flutter_tts/flutter_tts.dart';

/// Copiloto por voz (flutter_tts).
class NavigationVoiceService {
  NavigationVoiceService() : _tts = FlutterTts();

  final FlutterTts _tts;
  var _ready = false;
  var _muted = false;

  bool get isMuted => _muted;

  Future<void> init() async {
    if (_ready) {
      return;
    }
    await _tts.setLanguage('es-ES');
    await _tts.setSpeechRate(0.48);
    await _tts.setVolume(1);
    if (defaultTargetPlatform == TargetPlatform.android) {
      await _tts.setAudioAttributesForNavigation();
      await _tts.setQueueMode(1);
    } else if (defaultTargetPlatform == TargetPlatform.iOS) {
      // Igual que Android: baja la música/radio solo mientras habla.
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

  Future<void> setMuted(bool muted) async {
    _muted = muted;
    if (muted) {
      await stop();
    }
  }

  Future<void> speak(String text) async {
    if (_muted || text.trim().isEmpty) {
      return;
    }
    await _speakNow(text);
  }

  /// Emergencias de grupo: habla aunque el copiloto de ruta esté silenciado.
  Future<void> speakUrgent(String text) async {
    if (text.trim().isEmpty) {
      return;
    }
    await _speakNow(text);
  }

  Future<void> _speakNow(String text) async {
    await init();
    await _tts.stop();
    if (defaultTargetPlatform == TargetPlatform.android) {
      await _tts.speak(text, focus: true);
    } else if (defaultTargetPlatform == TargetPlatform.iOS) {
      await _tts.setSharedInstance(true);
      await _tts.speak(text);
    } else {
      await _tts.speak(text);
    }
  }

  Future<void> stop() => _tts.stop();
}
