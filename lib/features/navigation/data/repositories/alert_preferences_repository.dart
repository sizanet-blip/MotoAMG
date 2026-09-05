import 'dart:convert';

import 'package:hive_flutter/hive_flutter.dart';
import 'package:moto_amg/core/constants/navigation_constants.dart';
import 'package:moto_amg/features/navigation/domain/entities/alert_preferences.dart';

/// Persistencia local de preferencias de avisos (HUD / mapa / voz).
class AlertPreferencesRepository {
  Box<String>? _box;

  Future<Box<String>> _open() async {
    _box ??=
        await Hive.openBox<String>(NavigationConstants.alertPreferencesBox);
    return _box!;
  }

  Future<AlertPreferences> load() async {
    final box = await _open();
    final raw = box.get(NavigationConstants.alertPreferencesKey);
    if (raw == null || raw.isEmpty) {
      return AlertPreferences.defaults;
    }
    try {
      final map = jsonDecode(raw) as Map<String, dynamic>;
      return AlertPreferences.fromJson(map);
    } catch (_) {
      return AlertPreferences.defaults;
    }
  }

  Future<void> save(AlertPreferences preferences) async {
    final box = await _open();
    await box.put(
      NavigationConstants.alertPreferencesKey,
      jsonEncode(preferences.toJson()),
    );
  }
}
