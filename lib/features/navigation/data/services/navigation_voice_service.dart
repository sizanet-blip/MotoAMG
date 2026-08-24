import 'package:flutter_tts/flutter_tts.dart';

/// Copiloto por voz (flutter_tts).
class NavigationVoiceService {
  NavigationVoiceService() : _tts = FlutterTts();

  final FlutterTts _tts;
  var _ready = false;

  Future<void> init() async {
    if (_ready) {
      return;
    }
    await _tts.setLanguage('es-ES');
    await _tts.setSpeechRate(0.48);
    await _tts.setVolume(1);
    _ready = true;
  }

  Future<void> speak(String text) async {
    await init();
    await _tts.stop();
    await _tts.speak(text);
  }

  Future<void> stop() => _tts.stop();
}
