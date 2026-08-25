import 'dart:convert';

import 'package:hive_flutter/hive_flutter.dart';
import 'package:loc_motos/core/constants/navigation_constants.dart';
import 'package:loc_motos/features/navigation/domain/entities/route_preferences.dart';

/// Persistencia local de preferencias de routing (curvatura / evitaciones).
class RoutePreferencesRepository {
  Box<String>? _box;

  Future<Box<String>> _open() async {
    _box ??=
        await Hive.openBox<String>(NavigationConstants.routePreferencesBox);
    return _box!;
  }

  Future<RoutePreferences> load() async {
    final box = await _open();
    final raw = box.get(NavigationConstants.routePreferencesKey);
    if (raw == null || raw.isEmpty) {
      return RoutePreferences.defaults;
    }
    try {
      final map = jsonDecode(raw) as Map<String, dynamic>;
      return RoutePreferences.fromJson(map);
    } catch (_) {
      return RoutePreferences.defaults;
    }
  }

  Future<void> save(RoutePreferences preferences) async {
    final box = await _open();
    await box.put(
      NavigationConstants.routePreferencesKey,
      jsonEncode(preferences.toJson()),
    );
  }
}
