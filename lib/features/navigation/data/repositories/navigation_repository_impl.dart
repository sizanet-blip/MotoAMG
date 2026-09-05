import 'package:moto_amg/features/navigation/data/datasources/hive_route_cache_datasource.dart';
import 'package:moto_amg/features/navigation/data/datasources/tomtom_snap_to_roads_datasource.dart';
import 'package:moto_amg/features/navigation/data/datasources/valhalla_remote_datasource.dart';
import 'package:moto_amg/features/navigation/data/models/navigation_route_model.dart';
import 'package:moto_amg/features/navigation/data/services/speed_limit_merge.dart';
import 'package:moto_amg/features/navigation/domain/entities/geo_point.dart';
import 'package:moto_amg/features/navigation/domain/entities/navigation_route.dart';
import 'package:moto_amg/features/navigation/domain/entities/route_plan.dart';
import 'package:moto_amg/features/navigation/domain/entities/route_preferences.dart';
import 'package:moto_amg/features/navigation/domain/entities/speed_limit_segment.dart';
import 'package:moto_amg/features/navigation/domain/entities/tomtom_route_enrichment.dart';
import 'package:moto_amg/features/navigation/domain/exceptions/navigation_exceptions.dart';
import 'package:moto_amg/features/navigation/domain/repositories/navigation_repository.dart';

class NavigationRepositoryImpl implements NavigationRepository {
  NavigationRepositoryImpl(
    this._valhalla,
    this._cache, {
    TomTomSnapToRoadsDataSource? tomtom,
  }) : _tomtom = tomtom ?? TomTomSnapToRoadsDataSource();

  final ValhallaRemoteDataSource _valhalla;
  final HiveRouteCacheDataSource _cache;
  final TomTomSnapToRoadsDataSource _tomtom;

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

    // Límites TomTom: solo al confirmar «Empezar navegación», no aquí.
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
    if (route is! NavigationRouteModel) {
      return route;
    }
    if (!_valhalla.isConfigured) {
      return route;
    }
    return _valhalla.attachSpeedLimitsToRoute(route);
  }

  @override
  Future<NavigationRoute> enrichSpeedLimitsWithTomTom(
    NavigationRoute route,
  ) async {
    final details = await enrichRouteWithTomTomDetails(route);
    return details?.route ?? route;
  }

  @override
  Future<TomTomRouteEnrichment?> enrichRouteWithTomTomDetails(
    NavigationRoute route,
  ) async {
    if (route is! NavigationRouteModel) {
      return null;
    }
    return _enrichWithTomTomLimitsDetailed(route);
  }

  Future<TomTomRouteEnrichment?> _enrichWithTomTomLimitsDetailed(
    NavigationRouteModel route,
  ) async {
    if (!_tomtom.isConfigured || route.polyline.length < 2) {
      return null;
    }
    final motoAmgSegments = List<SpeedLimitSegment>.from(
      route.speedLimitSegments,
    );
    final tomtomSegments =
        await _tomtom.fetchSpeedLimitSegments(route.polyline);
    if (tomtomSegments.isEmpty) {
      return null;
    }
    final merged = SpeedLimitMerge.mergePreferringOverlay(
      base: motoAmgSegments,
      overlay: tomtomSegments,
      polylineLength: route.polyline.length,
    );
    if (merged.isEmpty) {
      return null;
    }
    return TomTomRouteEnrichment(
      route: route.copyWithSpeedLimits(merged),
      motoAmgSegments: motoAmgSegments,
      tomtomSegments: tomtomSegments,
    );
  }
}
