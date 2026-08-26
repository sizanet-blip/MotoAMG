import 'dart:convert';

import 'package:equatable/equatable.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:loc_motos/core/constants/navigation_constants.dart';

/// Preferencias de seguridad / usabilidad del HUD en navegación.
class HudSafetyPreferences extends Equatable {
  const HudSafetyPreferences({
    this.keepScreenOn = true,
    this.highBrightness = false,
    this.helmetMode = false,
  });

  static const defaults = HudSafetyPreferences();

  /// Evita que la pantalla se apague durante la navegación.
  final bool keepScreenOn;

  /// Sube el brillo al máximo al entrar en el HUD (se restaura al salir).
  final bool highBrightness;

  /// Controles grandes (silenciar / cancelar) fáciles con guantes.
  final bool helmetMode;

  HudSafetyPreferences copyWith({
    bool? keepScreenOn,
    bool? highBrightness,
    bool? helmetMode,
  }) {
    return HudSafetyPreferences(
      keepScreenOn: keepScreenOn ?? this.keepScreenOn,
      highBrightness: highBrightness ?? this.highBrightness,
      helmetMode: helmetMode ?? this.helmetMode,
    );
  }

  Map<String, dynamic> toJson() => {
        'keepScreenOn': keepScreenOn,
        'highBrightness': highBrightness,
        'helmetMode': helmetMode,
      };

  factory HudSafetyPreferences.fromJson(Map<String, dynamic> json) {
    return HudSafetyPreferences(
      keepScreenOn: json['keepScreenOn'] as bool? ?? true,
      highBrightness: json['highBrightness'] as bool? ?? false,
      helmetMode: json['helmetMode'] as bool? ?? false,
    );
  }

  @override
  List<Object?> get props => [keepScreenOn, highBrightness, helmetMode];
}

class HudSafetyRepository {
  Box<String>? _box;

  Future<Box<String>> _open() async {
    _box ??= await Hive.openBox<String>(NavigationConstants.hudSafetyBox);
    return _box!;
  }

  Future<HudSafetyPreferences> load() async {
    final box = await _open();
    final raw = box.get(NavigationConstants.hudSafetyKey);
    if (raw == null || raw.isEmpty) {
      return HudSafetyPreferences.defaults;
    }
    try {
      return HudSafetyPreferences.fromJson(
        jsonDecode(raw) as Map<String, dynamic>,
      );
    } catch (_) {
      return HudSafetyPreferences.defaults;
    }
  }

  Future<void> save(HudSafetyPreferences prefs) async {
    final box = await _open();
    await box.put(
      NavigationConstants.hudSafetyKey,
      jsonEncode(prefs.toJson()),
    );
  }
}
