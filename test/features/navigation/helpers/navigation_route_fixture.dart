import 'dart:convert';
import 'dart:io';

import 'package:moto_amg/features/navigation/data/models/navigation_route_model.dart';
import 'package:moto_amg/features/navigation/data/services/route_guidance_service.dart';
import 'package:moto_amg/features/navigation/data/services/sharp_curve_detector.dart';
import 'package:moto_amg/features/navigation/domain/entities/geo_point.dart';
import 'package:moto_amg/features/navigation/domain/entities/navigation_maneuver.dart';
import 'package:moto_amg/features/navigation/domain/entities/navigation_route.dart';
import 'package:moto_amg/features/navigation/domain/entities/route_alert.dart';
import 'package:moto_amg/features/navigation/domain/services/maneuver_significance.dart';

/// Carga rutas de prueba desde `test/fixtures/navigation/*.json`.
///
/// Formato soportado:
/// - `valhalla`: respuesta cruda de Valhalla (`trip.legs…`).
/// - `polyline` + `maneuvers`: fixture simplificado (sin codificar shape6).
abstract final class NavigationRouteFixture {
  static const fixturesDir = 'test/fixtures/navigation';

  static List<File> listFixtureFiles() {
    final dir = Directory(fixturesDir);
    if (!dir.existsSync()) {
      return const [];
    }
    return dir
        .listSync()
        .whereType<File>()
        .where((f) => f.path.endsWith('.json'))
        .where((f) => !f.path.contains('_template'))
        .where((f) => !f.uri.pathSegments.last.startsWith('_'))
        .toList()
      ..sort((a, b) => a.path.compareTo(b.path));
  }

  static Map<String, dynamic> readJson(File file) {
    return jsonDecode(file.readAsStringSync()) as Map<String, dynamic>;
  }

  static NavigationRouteModel loadRoute(Map<String, dynamic> json) {
    final origin = _point(json['origin'] as Map<String, dynamic>);
    final destination = _point(json['destination'] as Map<String, dynamic>);
    final id = json['id'] as String? ?? 'fixture';

    final valhalla = json['valhalla'];
    if (valhalla is Map<String, dynamic>) {
      return NavigationRouteModel.fromValhalla(
        valhalla,
        origin: origin,
        destination: destination,
        id: id,
      );
    }

    final polyline = (json['polyline'] as List<dynamic>)
        .map((p) => _point(p as Map<String, dynamic>))
        .toList(growable: false);
    final maneuvers = (json['maneuvers'] as List<dynamic>)
        .map((m) => _maneuverFromJson(m as Map<String, dynamic>))
        .toList(growable: false);

    final polylineTurnEnriched = [
      for (final maneuver in maneuvers)
        NavigationManeuver(
          index: maneuver.index,
          type: maneuver.type,
          instruction: maneuver.instruction,
          distanceMeters: maneuver.distanceMeters,
          location: maneuver.location,
          beginShapeIndex: maneuver.beginShapeIndex,
          streetName: maneuver.streetName,
          beginStreetName: maneuver.beginStreetName,
          valhallaType: maneuver.valhallaType,
          toStayOn: maneuver.toStayOn,
          turnDegree: maneuver.turnDegree,
          polylineTurnDegrees: maneuver.polylineTurnDegrees ??
              NavigationRouteModel.polylineTurnDegreesAt(
                polyline,
                maneuver.beginShapeIndex,
              ),
          voiceInstruction: maneuver.voiceInstruction,
          lanes: maneuver.lanes,
        ),
    ];

    return NavigationRouteModel(
      id: id,
      origin: origin,
      destination: destination,
      polyline: polyline,
      maneuvers: polylineTurnEnriched,
      distanceMeters: (json['distanceMeters'] as num?)?.toDouble() ??
          _polylineLength(polyline),
      durationSeconds: (json['durationSeconds'] as num?)?.toInt() ?? 300,
      createdAt: DateTime(2026),
    );
  }

  /// Mismo pipeline que [RouteAlertsService] para curvas (sin red).
  static NavigationRouteModel withCurveAlerts(NavigationRoute route) {
    final guidance = RouteGuidanceService();
    final raw = SharpCurveDetector.detect(route.polyline);
    final curves = ManeuverSignificance.filterCurvesAtSignificantTurns(
      raw,
      route,
      maneuverAlongMeters: (maneuver) =>
          guidance.distanceAlongRouteMeters(maneuver.location, route.polyline),
    );
    if (route is NavigationRouteModel) {
      return route.copyWithAlerts(curves);
    }
    return NavigationRouteModel(
      id: route.id,
      origin: route.origin,
      destination: route.destination,
      polyline: route.polyline,
      maneuvers: route.maneuvers,
      distanceMeters: route.distanceMeters,
      durationSeconds: route.durationSeconds,
      createdAt: route.createdAt,
      alerts: curves,
    );
  }

  static void assertCheckpoint({
    required NavigationRoute route,
    required Map<String, dynamic> checkpoint,
    required RouteGuidanceService guidance,
  }) {
    final position = _point(checkpoint['position'] as Map<String, dynamic>);
    final upcomingIndex = guidance.resolveUpcomingManeuverIndex(
      position: position,
      route: route,
    );
    final maneuver = route.maneuvers[upcomingIndex];

    final expectedType = checkpoint['expectManeuverType'] as String?;
    final expectHidden = checkpoint['expectHiddenManeuverCard'] as bool? ?? false;
    if (expectHidden) {
      if (guidance.shouldShowManeuverCard(
        route: route,
        upcomingIndex: upcomingIndex,
        remainingMeters: guidance.remainingMetersToUpcoming(
          position: position,
          route: route,
          upcomingIndex: upcomingIndex,
        ),
      )) {
        throw NavigationFixtureAssertionError(
          'No debería mostrarse cartel de maniobra en esta posición '
          '(índice $upcomingIndex, «${maneuver.instruction}»)',
        );
      }
      return;
    }
    if (expectedType != null) {
      final expected = _maneuverTypeFromString(expectedType);
      if (maneuver.type != expected) {
        throw NavigationFixtureAssertionError(
          'Se esperaba maniobra $expectedType y llegó ${maneuver.type.name} '
          '(índice $upcomingIndex, «${maneuver.instruction}»)',
        );
      }
    }

    final maxRemaining = checkpoint['maxRemainingMeters'] as num?;
    if (maxRemaining != null) {
      final remaining = guidance.remainingMetersToUpcoming(
        position: position,
        route: route,
        upcomingIndex: upcomingIndex,
      );
      if (remaining > maxRemaining) {
        throw NavigationFixtureAssertionError(
          'Distancia al aviso ${remaining.toStringAsFixed(0)} m '
          'supera el máximo ${maxRemaining.toStringAsFixed(0)} m',
        );
      }
    }

    final minRemaining = checkpoint['minRemainingMeters'] as num?;
    if (minRemaining != null) {
      final remaining = guidance.remainingMetersToUpcoming(
        position: position,
        route: route,
        upcomingIndex: upcomingIndex,
      );
      if (remaining < minRemaining) {
        throw NavigationFixtureAssertionError(
          'Distancia al aviso ${remaining.toStringAsFixed(0)} m '
          'por debajo del mínimo ${minRemaining.toStringAsFixed(0)} m',
        );
      }
    }

    final along = guidance.distanceAlongRouteMeters(position, route.polyline);
    final expectCurve = checkpoint['expectCurveAlert'] as bool?;
    if (expectCurve != null) {
      if (expectCurve) {
        final search = (checkpoint['curveSearchMeters'] as num? ?? 250).toDouble();
        final curve = _nearestCurve(route, along);
        final hasCurve = curve != null &&
            (curve.distanceAlongRouteMeters - along).abs() <= search;
        if (!hasCurve) {
          throw NavigationFixtureAssertionError(
            'Se esperaba alerta de curva cerca de la posición',
          );
        }
      } else {
        final marginBehind = 30.0;
        final marginAhead = 130.0;
        final maneuverAlong = guidance.distanceAlongRouteMeters(
          maneuver.location,
          route.polyline,
        );
        final curveOnJunction = route.alerts.any((alert) {
          if (alert.type != RouteAlertType.sharpCurve) {
            return false;
          }
          final delta = alert.distanceAlongRouteMeters - maneuverAlong;
          return delta >= -marginBehind && delta <= marginAhead;
        });
        if (curveOnJunction) {
          throw NavigationFixtureAssertionError(
            'No debería haber alerta de curva en el giro de cruce',
          );
        }
      }
    }
  }

  static RouteAlert? _nearestCurve(NavigationRoute route, double along) {
    RouteAlert? best;
    var bestDist = double.infinity;
    for (final alert in route.alerts) {
      if (alert.type != RouteAlertType.sharpCurve) {
        continue;
      }
      final d = (alert.distanceAlongRouteMeters - along).abs();
      if (d < bestDist) {
        bestDist = d;
        best = alert;
      }
    }
    return best;
  }

  static NavigationManeuver _maneuverFromJson(Map<String, dynamic> m) {
    return NavigationManeuver(
      index: (m['index'] as num).toInt(),
      type: _maneuverTypeFromString(m['type'] as String),
      instruction: m['instruction'] as String,
      distanceMeters: (m['distanceMeters'] as num).toDouble(),
      location: _point(m['location'] as Map<String, dynamic>),
      beginShapeIndex: (m['beginShapeIndex'] as num?)?.toInt() ?? 0,
      streetName: m['streetName'] as String?,
      beginStreetName: m['beginStreetName'] as String?,
      valhallaType: (m['valhallaType'] as num?)?.toInt(),
      toStayOn: m['toStayOn'] as bool? ?? false,
      turnDegree: (m['turnDegree'] as num?)?.toInt(),
      polylineTurnDegrees: (m['polylineTurnDegrees'] as num?)?.toDouble(),
      voiceInstruction: m['voiceInstruction'] as String?,
      lanes: const [],
    );
  }

  static ManeuverType _maneuverTypeFromString(String raw) {
    return ManeuverType.values.firstWhere(
      (t) => t.name == raw,
      orElse: () => throw ArgumentError('ManeuverType desconocido: $raw'),
    );
  }

  static GeoPoint _point(Map<String, dynamic> json) {
    return GeoPoint(
      lat: (json['lat'] as num).toDouble(),
      lng: (json['lng'] as num).toDouble(),
    );
  }

  static double _polylineLength(List<GeoPoint> polyline) {
    if (polyline.length < 2) {
      return 0;
    }
    final guidance = RouteGuidanceService();
    return guidance.distanceAtShapeIndex(polyline, polyline.length - 1);
  }
}

final class NavigationFixtureAssertionError implements Exception {
  NavigationFixtureAssertionError(this.message);

  final String message;

  @override
  String toString() => message;
}
