import 'package:equatable/equatable.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:moto_amg/core/constants/navigation_constants.dart';
import 'package:moto_amg/core/utils/solar_daylight.dart';

/// Preferencia de aspecto del mapa en navegación.
enum MapAppearanceMode {
  /// Según amanecer/atardecer de la ubicación (cambia con la estación).
  auto,
  day,
  night,
}

extension MapAppearanceModeX on MapAppearanceMode {
  String get label => switch (this) {
        MapAppearanceMode.auto => 'Automático',
        MapAppearanceMode.day => 'Día',
        MapAppearanceMode.night => 'Noche',
      };

  String get subtitle => switch (this) {
        MapAppearanceMode.auto =>
          'Según amanecer y atardecer (verano/invierno)',
        MapAppearanceMode.day => 'Siempre mapa claro',
        MapAppearanceMode.night => 'Prefiere mapa nocturno suave',
      };

  /// `true` = conviene mapa oscuro ahora.
  bool prefersDarkNow({
    DateTime? now,
    double? latitude,
    double? longitude,
  }) {
    if (this == MapAppearanceMode.day) {
      return false;
    }
    if (this == MapAppearanceMode.night) {
      return true;
    }
    return SolarDaylight.isNight(
      now ?? DateTime.now(),
      latitude: latitude,
      longitude: longitude,
    );
  }
}

class MapAppearancePreferences extends Equatable {
  const MapAppearancePreferences({
    this.mode = MapAppearanceMode.auto,
  });

  static const defaults = MapAppearancePreferences();

  final MapAppearanceMode mode;

  MapAppearancePreferences copyWith({MapAppearanceMode? mode}) {
    return MapAppearancePreferences(mode: mode ?? this.mode);
  }

  Map<String, dynamic> toJson() => {'mode': mode.name};

  factory MapAppearancePreferences.fromJson(Map<String, dynamic> json) {
    final name = json['mode'] as String? ?? 'auto';
    final mode = MapAppearanceMode.values.firstWhere(
      (m) => m.name == name,
      orElse: () => MapAppearanceMode.auto,
    );
    return MapAppearancePreferences(mode: mode);
  }

  @override
  List<Object?> get props => [mode];
}

class MapAppearanceRepository {
  Box<String>? _box;

  Future<Box<String>> _open() async {
    _box ??= await Hive.openBox<String>(
      NavigationConstants.mapAppearanceBox,
    );
    return _box!;
  }

  Future<MapAppearancePreferences> load() async {
    final box = await _open();
    final raw = box.get(NavigationConstants.mapAppearanceKey);
    if (raw == null || raw.isEmpty) {
      return MapAppearancePreferences.defaults;
    }
    try {
      // Guardamos solo el nombre del modo (simple).
      final mode = MapAppearanceMode.values.firstWhere(
        (m) => m.name == raw,
        orElse: () => MapAppearanceMode.auto,
      );
      return MapAppearancePreferences(mode: mode);
    } catch (_) {
      return MapAppearancePreferences.defaults;
    }
  }

  Future<void> save(MapAppearancePreferences prefs) async {
    final box = await _open();
    await box.put(NavigationConstants.mapAppearanceKey, prefs.mode.name);
  }
}
