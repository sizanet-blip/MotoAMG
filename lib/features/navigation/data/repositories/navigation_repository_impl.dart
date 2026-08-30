import 'package:loc_motos/features/navigation/data/datasources/hive_route_cache_datasource.dart';
import 'package:loc_motos/features/navigation/data/datasources/valhalla_remote_datasource.dart';
import 'package:loc_motos/features/navigation/data/models/navigation_route_model.dart';
import 'package:loc_motos/features/navigation/domain/entities/geo_point.dart';
import 'package:loc_motos/features/navigation/domain/entities/navigation_route.dart';
import 'package:loc_motos/features/navigation/domain/entities/route_plan.dart';
import 'package:loc_motos/features/navigation/domain/entities/route_preferences.dart';
import 'package:loc_motos/features/navigation/domain/exceptions/navigation_exceptions.dart';
import 'package:loc_motos/features/navigation/domain/repositories/navigation_repository.dart';

class NavigationRepositoryImpl implements NavigationRepository {
  NavigationRepositoryImpl(this._valhalla, this._cache);

  final ValhallaRemoteDataSource _valhalla;
  final HiveRouteCacheDataSource _cache;

  @override
  Future<RoutePlan> planRoute({
    required GeoPoint origin,
    required GeoPoint destination,
    List<GeoPoint> waypoints = const [],
    RoutePreferences preferences = RoutePreferences.defaults,
    String costing = 'motorcycle',
    String? originLabel,
    String? destinationLabel,
    bool includeAlternates = true,
  }) async {
    final List<NavigationRouteModel> baseRoutes;
    if (_valhalla.isConfigured) {
      baseRoutes = await _valhalla.fetchRoutes(
        origin: origin,
        destination: destination,
        waypoints: waypoints,
        preferences: preferences,
        costing: costing,
        maxAlternates: includeAlternates ? null : 0,
        attachSpeedLimits: true,
      );
    } else {
      baseRoutes = [
        NavigationRouteModel.demo(
          origin: origin,
          destination: destination,
          waypoints: waypoints,
        ),
      ];
    }

    final labeled = [
      for (final route in baseRoutes)
        route.copyWithLabels(
          originLabel: originLabel,
          destinationLabel: destinationLabel,
        ),
    ];
    await _cache.saveRoute(labeled.first);
    return RoutePlan(alternatives: List.unmodifiable(labeled));
  }

  @override
  Future<NavigationRoute?> loadCachedRoute(String routeId) {
    return _cache.loadRoute(routeId);
  }

  @override
  Future<NavigationRoute?> loadLastActiveRoute() {
    return _cache.loadActiveRoute();
  }

  @override
  Future<void> saveActiveRoute(NavigationRoute route) {
    if (route is! NavigationRouteModel) {
      throw const NavigationException('No se pudo guardar la ruta.');
    }
    return _cache.saveRoute(route);
  }

  @override
  Future<void> clearActiveRoute() => _cache.clearActiveRoute();

  @override
  Future<NavigationRoute> refreshSpeedLimits(NavigationRoute route) async {
    if (!_valhalla.isConfigured || route is! NavigationRouteModel) {
      return route;
    }
    return _valhalla.attachSpeedLimitsToRoute(route);
  }
}
