import 'dart:convert';

import 'package:equatable/equatable.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:moto_amg/core/constants/navigation_constants.dart';

/// Preferencias de TomTom Snap to Roads (límites de velocidad).
class TomTomPreferences extends Equatable {
  const TomTomPreferences({
    this.enabled = false,
  });

  /// Por defecto desactivado: límites solo OSM/DGT hasta que el usuario active.
  static const defaults = TomTomPreferences();

  final bool enabled;

  TomTomPreferences copyWith({bool? enabled}) {
    return TomTomPreferences(enabled: enabled ?? this.enabled);
  }

  Map<String, dynamic> toJson() => {'enabled': enabled};

  factory TomTomPreferences.fromJson(Map<String, dynamic> json) {
    return TomTomPreferences(
      enabled: json['enabled'] as bool? ?? false,
    );
  }

  @override
  List<Object?> get props => [enabled];
}

class TomTomPreferencesRepository {
  Box<String>? _box;

  Future<Box<String>> _open() async {
    _box ??= await Hive.openBox<String>(
      NavigationConstants.tomtomPreferencesBox,
    );
    return _box!;
  }

  Future<TomTomPreferences> load() async {
    final box = await _open();
    final raw = box.get(NavigationConstants.tomtomPreferencesKey);
    if (raw == null || raw.isEmpty) {
      return TomTomPreferences.defaults;
    }
    try {
      final map = jsonDecode(raw) as Map<String, dynamic>;
      return TomTomPreferences.fromJson(map);
    } catch (_) {
      return TomTomPreferences.defaults;
    }
  }

  Future<void> save(TomTomPreferences preferences) async {
    final box = await _open();
    await box.put(
      NavigationConstants.tomtomPreferencesKey,
      jsonEncode(preferences.toJson()),
    );
  }
}
