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
    this.map3dEnabled = false,
    this.showRouteSimulator = false,
  });

  static const defaults = HudSafetyPreferences();

  /// Evita que la pantalla se apague durante la navegación.
  final bool keepScreenOn;

  /// Sube el brillo al máximo al entrar en el HUD (se restaura al salir).
  final bool highBrightness;

  /// Controles grandes (silenciar / cancelar) fáciles con guantes.
  final bool helmetMode;

  /// Inclinación 3D del mapa al navegar (por defecto off = vista plana).
  final bool map3dEnabled;

  /// Botones compactos Volver / Simular en el HUD para probar la ruta sin moverte.
  final bool showRouteSimulator;

  HudSafetyPreferences copyWith({
    bool? keepScreenOn,
    bool? highBrightness,
    bool? helmetMode,
    bool? map3dEnabled,
    bool? showRouteSimulator,
  }) {
    return HudSafetyPreferences(
      keepScreenOn: keepScreenOn ?? this.keepScreenOn,
      highBrightness: highBrightness ?? this.highBrightness,
      helmetMode: helmetMode ?? this.helmetMode,
      map3dEnabled: map3dEnabled ?? this.map3dEnabled,
      showRouteSimulator: showRouteSimulator ?? this.showRouteSimulator,
    );
  }

  Map<String, dynamic> toJson() => {
        'keepScreenOn': keepScreenOn,
        'highBrightness': highBrightness,
        'helmetMode': helmetMode,
        'map3dEnabled': map3dEnabled,
        'showRouteSimulator': showRouteSimulator,
      };

  factory HudSafetyPreferences.fromJson(Map<String, dynamic> json) {
    return HudSafetyPreferences(
      keepScreenOn: json['keepScreenOn'] as bool? ?? true,
      highBrightness: json['highBrightness'] as bool? ?? false,
      helmetMode: json['helmetMode'] as bool? ?? false,
      map3dEnabled: json['map3dEnabled'] as bool? ?? false,
      showRouteSimulator: json['showRouteSimulator'] as bool? ?? false,
    );
  }

  @override
  List<Object?> get props => [
        keepScreenOn,
        highBrightness,
        helmetMode,
        map3dEnabled,
        showRouteSimulator,
      ];
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
