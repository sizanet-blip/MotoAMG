import 'package:loc_motos/features/navigation/data/datasources/overpass_poi_datasource.dart';
import 'package:loc_motos/features/navigation/data/datasources/spain_radar_datasource.dart';
import 'package:loc_motos/features/navigation/data/datasources/valhalla_remote_datasource.dart';
import 'package:loc_motos/features/navigation/data/models/navigation_route_model.dart';
import 'package:loc_motos/features/navigation/data/services/route_guidance_service.dart';
import 'package:loc_motos/features/navigation/data/services/sharp_curve_detector.dart';
import 'package:loc_motos/features/navigation/domain/entities/navigation_route.dart';
import 'package:loc_motos/features/navigation/domain/entities/route_alert.dart';

/// Enriquece una ruta con avisos moto (peajes, gasolineras, radares oficiales, curvas).
class RouteAlertsService {
  RouteAlertsService({
    ValhallaRemoteDataSource? valhalla,
    OverpassPoiDatasource? overpass,
    SpainRadarDatasource? spainRadars,
    RouteGuidanceService? guidance,
  })  : _valhalla = valhalla ?? ValhallaRemoteDataSource(),
        _overpass = overpass ?? OverpassPoiDatasource(),
        _spainRadars = spainRadars ?? SpainRadarDatasource(),
        _guidance = guidance ?? RouteGuidanceService();

  final ValhallaRemoteDataSource _valhalla;
  final OverpassPoiDatasource _overpass;
  final SpainRadarDatasource _spainRadars;
  final RouteGuidanceService _guidance;

  final _cache = <String, List<RouteAlert>>{};

  Future<NavigationRoute> enrich(NavigationRoute route) async {
    if (route.polyline.length < 2) {
      return route;
    }
    final cached = _cache[route.id];
    if (cached != null) {
      return _withAlerts(route, cached);
    }

    final results = await Future.wait([
      _tollAlerts(route),
      _overpass.fetchFuelNearRoute(route.polyline),
      _spainRadars.fetchCamerasNearRoute(route.polyline),
      Future.value(SharpCurveDetector.detect(route.polyline)),
    ]);

    final merged = <RouteAlert>[
      ...results[0],
      ...results[1],
      ..._withRouteSpeedLimits(route, results[2]),
      ...results[3],
    ]..sort(
        (a, b) =>
            a.distanceAlongRouteMeters.compareTo(b.distanceAlongRouteMeters),
      );

    _cache[route.id] = List.unmodifiable(merged);
    return _withAlerts(route, merged);
  }

  /// Rellena velocidad del radar con el límite Valhalla del tramo si falta.
  List<RouteAlert> _withRouteSpeedLimits(
    NavigationRoute route,
    List<RouteAlert> cameras,
  ) {
    return [
      for (final alert in cameras) _radarWithSpeed(route, alert),
    ];
  }

  RouteAlert _radarWithSpeed(NavigationRoute route, RouteAlert alert) {
    if (alert.speedLimitKmh != null && alert.speedLimitKmh! > 0) {
      return alert;
    }
    final limit = _guidance.resolveSpeedLimitKmh(
      position: alert.point,
      route: route,
    );
    if (limit == null || limit <= 0) {
      return alert;
    }
    final label = alert.label.contains('km/h')
        ? alert.label
        : '${alert.label} · $limit km/h';
    return alert.copyWith(speedLimitKmh: limit, label: label);
  }

  Future<List<RouteAlert>> _tollAlerts(NavigationRoute route) async {
    try {
      final entries = await _valhalla.fetchTollEntries(route.polyline);
      return [
        for (final e in entries)
          RouteAlert(
            id: 'toll_${e.beginShapeIndex}',
            type: RouteAlertType.toll,
            point: e.point,
            distanceAlongRouteMeters: _guidance.distanceAtShapeIndex(
              route.polyline,
              e.beginShapeIndex,
            ),
            label: 'Inicio de peaje',
          ),
      ];
    } catch (_) {
      return const [];
    }
  }

  NavigationRoute _withAlerts(NavigationRoute route, List<RouteAlert> alerts) {
    if (route is NavigationRouteModel) {
      return route.copyWithAlerts(alerts);
    }
    return NavigationRouteModel(
      id: route.id,
      origin: route.origin,
      destination: route.destination,
      waypoints: route.waypoints,
      polyline: route.polyline,
      maneuvers: route.maneuvers,
      distanceMeters: route.distanceMeters,
      durationSeconds: route.durationSeconds,
      createdAt: route.createdAt,
      speedLimitKmh: route.speedLimitKmh,
      speedLimitSegments: route.speedLimitSegments,
      alerts: alerts,
      originLabel: route.originLabel,
      destinationLabel: route.destinationLabel,
    );
  }

  /// Próximo aviso aún no pasado (para HUD).
  RouteAlert? nextAlert({
    required NavigationRoute route,
    required double alongMeters,
    double graceMeters = 40,
    RouteAlertType? onlyType,
  }) {
    for (final alert in route.alerts) {
      if (onlyType != null && alert.type != onlyType) {
        continue;
      }
      if (alongMeters <= alert.distanceAlongRouteMeters + graceMeters) {
        return alert;
      }
    }
    return null;
  }

  /// Próximo radar (HUD en navegación).
  RouteAlert? nextRadar({
    required NavigationRoute route,
    required double alongMeters,
    double graceMeters = 40,
  }) {
    return nextAlert(
      route: route,
      alongMeters: alongMeters,
      graceMeters: graceMeters,
      onlyType: RouteAlertType.speedCamera,
    );
  }

  Map<RouteAlertType, int> counts(List<RouteAlert> alerts) {
    final map = <RouteAlertType, int>{
      for (final t in RouteAlertType.values) t: 0,
    };
    for (final a in alerts) {
      map[a.type] = (map[a.type] ?? 0) + 1;
    }
    return map;
  }
}
