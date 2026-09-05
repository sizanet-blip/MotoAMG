import 'dart:math' as math;

import 'package:geolocator/geolocator.dart';
import 'package:moto_amg/core/constants/navigation_constants.dart';
import 'package:moto_amg/features/auth/domain/entities/user_vehicle.dart';
import 'package:moto_amg/features/navigation/data/datasources/overpass_poi_datasource.dart';
import 'package:moto_amg/features/navigation/data/datasources/spain_fuel_datasource.dart';
import 'package:moto_amg/features/navigation/data/datasources/spain_radar_datasource.dart';
import 'package:moto_amg/features/navigation/data/datasources/valhalla_remote_datasource.dart';
import 'package:moto_amg/features/navigation/data/models/navigation_route_model.dart';
import 'package:moto_amg/features/navigation/data/services/route_guidance_service.dart';
import 'package:moto_amg/features/navigation/data/services/sharp_curve_detector.dart';
import 'package:moto_amg/features/navigation/domain/entities/alert_preferences.dart';
import 'package:moto_amg/features/navigation/domain/entities/fuel_alert_display.dart';
import 'package:moto_amg/features/navigation/domain/entities/geo_point.dart';
import 'package:moto_amg/features/navigation/domain/entities/navigation_route.dart';
import 'package:moto_amg/features/navigation/domain/entities/navigation_route.dart';
import 'package:moto_amg/features/navigation/domain/entities/route_alert.dart';
import 'package:moto_amg/features/navigation/domain/services/maneuver_significance.dart';
import 'package:moto_amg/features/navigation/domain/entities/route_map_poi.dart';

/// Enriquece una ruta con avisos (peajes, gasolineras MITECO, radares, curvas)
/// y POI de mapa (semáforos / STOP / ceda vía Overpass).
class RouteAlertsService {
  RouteAlertsService({
    ValhallaRemoteDataSource? valhalla,
    SpainFuelDatasource? spainFuel,
    SpainRadarDatasource? spainRadars,
    OverpassPoiDatasource? overpass,
    RouteGuidanceService? guidance,
  })  : _valhalla = valhalla ?? ValhallaRemoteDataSource(),
        _spainFuel = spainFuel ?? SpainFuelDatasource(),
        _spainRadars = spainRadars ?? SpainRadarDatasource(),
        _overpass = overpass ?? OverpassPoiDatasource(),
        _guidance = guidance ?? RouteGuidanceService();

  final ValhallaRemoteDataSource _valhalla;
  final SpainFuelDatasource _spainFuel;
  final SpainRadarDatasource _spainRadars;
  final OverpassPoiDatasource _overpass;
  final RouteGuidanceService _guidance;

  final _cache = <String, ({List<RouteAlert> alerts, List<RouteMapPoi> mapPois})>{};

  Future<NavigationRoute> enrich(
    NavigationRoute route, {
    VehicleFuelType? preferredFuel,
    AlertPreferences preferences = AlertPreferences.defaults,
  }) async {
    if (route.polyline.length < 2) {
      return route;
    }
    final cacheKey =
        '${route.id}_${preferredFuel?.name ?? 'all'}_${preferences.enrichCacheSuffix}_radar75_tc1';
    final cached = _cache[cacheKey];
    if (cached != null) {
      return _withAlertsAndMapPois(route, cached.alerts, cached.mapPois);
    }

    final futures = <Future<List<RouteAlert>>>[
      if (preferences.tollsEnabled)
        _tollAlerts(route)
      else
        Future.value(const <RouteAlert>[]),
      if (preferences.fuelEnabled)
        _spainFuel.fetchFuelNearRoute(
          route.polyline,
          preferredFuel: preferredFuel,
          maxPriceEur: preferences.activeFuelMaxPriceEur,
        )
      else
        Future.value(const <RouteAlert>[]),
      if (preferences.radarsEnabled)
        _spainRadars.fetchCamerasNearRoute(route.polyline)
      else
        Future.value(const <RouteAlert>[]),
      if (preferences.curvesEnabled)
        Future.value(_detectCurves(route))
      else
        Future.value(const <RouteAlert>[]),
    ];

    final alertsFuture = Future.wait(futures);
    final mapPoisFuture =
        _overpass.fetchTrafficControlsNearRoute(route.polyline);
    final alertLists = await alertsFuture;
    final mapPois = await mapPoisFuture;

    final merged = <RouteAlert>[
      ...alertLists[0],
      ...alertLists[1],
      ..._withRouteSpeedLimits(route, alertLists[2]),
      ...alertLists[3],
    ]..sort(
        (a, b) =>
            a.distanceAlongRouteMeters.compareTo(b.distanceAlongRouteMeters),
      );

    _cache[cacheKey] = (
      alerts: List.unmodifiable(merged),
      mapPois: List.unmodifiable(mapPois),
    );
    return _withAlertsAndMapPois(route, merged, mapPois);
  }

  List<RouteAlert> _detectCurves(NavigationRoute route) {
    final raw = SharpCurveDetector.detect(route.polyline);
    return ManeuverSignificance.filterCurvesAtSignificantTurns(
      raw,
      route,
      maneuverAlongMeters: (maneuver) =>
          _guidance.distanceAlongRouteMeters(maneuver.location, route.polyline),
    );
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

  NavigationRoute _withAlertsAndMapPois(
    NavigationRoute route,
    List<RouteAlert> alerts,
    List<RouteMapPoi> mapPois,
  ) {
    if (route is NavigationRouteModel) {
      return route.copyWithAlertsAndMapPois(alerts: alerts, mapPois: mapPois);
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
      mapPois: mapPois,
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

  RouteAlert? nextRadar({
    required NavigationRoute route,
    required double alongMeters,
    double graceMeters = 40,
    GeoPoint? position,
  }) {
    final slack = NavigationConstants.radarHudLateralSlackMeters;
    for (final alert in route.alerts) {
      if (alert.type != RouteAlertType.speedCamera) {
        continue;
      }
      if (alongMeters > alert.distanceAlongRouteMeters + graceMeters) {
        continue;
      }
      if (position != null &&
          !_radarPlausibleOnRoute(
            alert: alert,
            alongMeters: alongMeters,
            position: position,
            lateralSlackMeters: slack,
          )) {
        continue;
      }
      return alert;
    }
    return null;
  }

  /// Descarta radares “cercanos” que no están en tu trazado (p. ej. paralelo).
  bool _radarPlausibleOnRoute({
    required RouteAlert alert,
    required double alongMeters,
    required GeoPoint position,
    required double lateralSlackMeters,
  }) {
    final remaining =
        (alert.distanceAlongRouteMeters - alongMeters).clamp(0.0, 1e9);
    final direct = Geolocator.distanceBetween(
      position.lat,
      position.lng,
      alert.point.lat,
      alert.point.lng,
    );
    // Componente lateral aproximada: si queda mucho más lejos en línea recta
    // que lo que falta por ruta, no es el radar de esta calzada.
    final lateralSq = direct * direct - remaining * remaining;
    if (lateralSq <= 0) {
      return true;
    }
    return math.sqrt(lateralSq) <= lateralSlackMeters;
  }

  RouteAlert? nextFuel({
    required NavigationRoute route,
    required double alongMeters,
    double graceMeters = 40,
  }) {
    return nextAlert(
      route: route,
      alongMeters: alongMeters,
      graceMeters: graceMeters,
      onlyType: RouteAlertType.fuel,
    );
  }

  RouteAlert? nextToll({
    required NavigationRoute route,
    required double alongMeters,
    double graceMeters = 40,
  }) {
    return nextAlert(
      route: route,
      alongMeters: alongMeters,
      graceMeters: graceMeters,
      onlyType: RouteAlertType.toll,
    );
  }

  RouteAlert? nextCurve({
    required NavigationRoute route,
    required double alongMeters,
    double graceMeters = 40,
    bool Function(RouteAlert alert)? accept,
  }) {
    for (final alert in route.alerts) {
      if (alert.type != RouteAlertType.sharpCurve) {
        continue;
      }
      if (accept != null && !accept(alert)) {
        continue;
      }
      if (alongMeters <= alert.distanceAlongRouteMeters + graceMeters) {
        return alert;
      }
    }
    return null;
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

/// Texto plano de gasolinera (voz / fallback) según preferencia de precio.
String fuelAlertDisplayLabel(RouteAlert alert, {required bool showPrice}) {
  final parts = parseFuelAlertParts(alert);
  if (!showPrice || !parts.hasPrice) {
    return parts.brand;
  }
  final priceBits = [
    for (final p in parts.prices)
      p.grade.isEmpty ? p.priceText : '${p.grade} ${p.priceText}',
  ];
  return '${parts.brand} · ${priceBits.join(' · ')}';
}
