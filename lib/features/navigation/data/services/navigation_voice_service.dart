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
      await _tts.setSharedInstance(true);
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
    await init();
    await _tts.stop();
    if (defaultTargetPlatform == TargetPlatform.android) {
      await _tts.speak(text, focus: true);
    } else {
      await _tts.speak(text);
    }
  }

  Future<void> stop() => _tts.stop();
}
