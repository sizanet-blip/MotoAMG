import 'dart:convert';

import 'package:hive_flutter/hive_flutter.dart';
import 'package:loc_motos/core/constants/navigation_constants.dart';
import 'package:loc_motos/features/navigation/data/models/navigation_route_model.dart';
import 'package:loc_motos/features/navigation/domain/entities/navigation_route.dart';

/// Caché local de rutas (ruta en mochila) con Hive.
class HiveRouteCacheDataSource {
  Box<String>? _box;

  Future<Box<String>> _open() async {
    _box ??= await Hive.openBox<String>(NavigationConstants.routeCacheBox);
    return _box!;
  }

  Future<void> saveRoute(NavigationRouteModel route) async {
    final box = await _open();
    await box.put(route.id, jsonEncode(route.toJson()));
    await box.put(NavigationConstants.activeRouteKey, route.id);
  }

  Future<NavigationRoute?> loadRoute(String routeId) async {
    final box = await _open();
    final raw = box.get(routeId);
    if (raw == null) {
      return null;
    }
    return NavigationRouteModel.fromJson(
      jsonDecode(raw) as Map<String, dynamic>,
    );
  }

  Future<NavigationRoute?> loadActiveRoute() async {
    final box = await _open();
    final activeId = box.get(NavigationConstants.activeRouteKey);
    if (activeId == null) {
      return null;
    }
    return loadRoute(activeId);
  }

  Future<void> clearActiveRoute() async {
    final box = await _open();
    final activeId = box.get(NavigationConstants.activeRouteKey);
    if (activeId != null) {
      await box.delete(activeId);
    }
    await box.delete(NavigationConstants.activeRouteKey);
  }
}
