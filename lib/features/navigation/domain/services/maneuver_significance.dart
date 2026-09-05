import 'package:moto_amg/features/navigation/domain/entities/navigation_maneuver.dart';
import 'package:moto_amg/features/navigation/domain/entities/navigation_route.dart';
import 'package:moto_amg/features/navigation/domain/entities/route_alert.dart';

/// Distingue un giro de calle/carretera de una curva en la misma vía (Valhalla).
abstract final class ManeuverSignificance {
  /// Metros de margen para no marcar curva donde hay un giro de cruce real.
  static const double junctionCurveExcludeBehindMeters = 30;
  static const double junctionCurveExcludeAheadMeters = 130;

  /// Por debajo de esto, mismo nombre OSM suele ser curva revirada (no bifurcación).
  static const int sameNameCurveMaxTurnDegree = 38;

  /// Normaliza nombres de vía para comparar (mayúsculas, espacios).
  static String normalizeStreetName(String? name) {
    if (name == null) {
      return '';
    }
    return name.trim().toLowerCase().replaceAll(RegExp(r'\s+'), ' ');
  }

  /// True si la maniobra debe mostrarse/anunciarse en el cartel de giros.
  static bool isSignificantNavigationManeuver(
    NavigationManeuver maneuver, {
    NavigationManeuver? next,
    NavigationManeuver? previous,
  }) {
    return switch (maneuver.type) {
      ManeuverType.depart ||
      ManeuverType.arrive ||
      ManeuverType.roundabout ||
      ManeuverType.ramp ||
      ManeuverType.merge ||
      ManeuverType.turn =>
        true,
      ManeuverType.continueStraight || ManeuverType.unknown => false,
      ManeuverType.turnLeft || ManeuverType.turnRight =>
        !isSameRoadBend(maneuver, next: next, previous: previous),
    };
  }

  /// Giro Valhalla que en realidad es curva en la misma carretera (sin cruce decisorio).
  static bool isSameRoadBend(
    NavigationManeuver maneuver, {
    NavigationManeuver? next,
    NavigationManeuver? previous,
  }) {
    if (maneuver.type != ManeuverType.turnLeft &&
        maneuver.type != ManeuverType.turnRight) {
      return false;
    }

    if (maneuver.toStayOn) {
      return true;
    }

    if (_instructionIndicatesContinuation(maneuver.instruction)) {
      return true;
    }

    final vt = maneuver.valhallaType;
    if (vt == 9 || vt == 14) {
      return _isSameRoadBear(maneuver, next: next, previous: previous);
    }

    if (_isFullTurnValhalla(vt)) {
      final begin = normalizeStreetName(maneuver.beginStreetName);
      final after = normalizeStreetName(maneuver.streetName);
      if (begin.isNotEmpty && after.isNotEmpty && begin == after) {
        final deg = maneuver.turnDegree;
        if (deg != null && deg < sameNameCurveMaxTurnDegree) {
          return true;
        }
        return false;
      }
      if (_isGenericUnnamedTurn(maneuver) &&
          _effectiveTurnAngleAbs(maneuver) != null &&
          _effectiveTurnAngleAbs(maneuver)! < sameNameCurveMaxTurnDegree) {
        return true;
      }
      return false;
    }

    return false;
  }

  static bool _isFullTurnValhalla(int? type) =>
      type == 10 || type == 11 || type == 15 || type == 16;

  /// Giro leve Valhalla (9/14): curva si sigues la misma vía nombrada.
  static bool _isSameRoadBear(
    NavigationManeuver maneuver, {
    NavigationManeuver? next,
    NavigationManeuver? previous,
  }) {
    final after = normalizeStreetName(maneuver.streetName);
    final begin = normalizeStreetName(maneuver.beginStreetName);

    if (begin.isNotEmpty && after.isNotEmpty && begin == after) {
      final deg = maneuver.turnDegree;
      if (deg == null || deg < sameNameCurveMaxTurnDegree) {
        return true;
      }
      return false;
    }

    if (after.isNotEmpty) {
      final prevStreet = normalizeStreetName(previous?.streetName);
      final nextStreet = normalizeStreetName(next?.streetName);
      final deg = maneuver.turnDegree;
      final gentle = deg == null || deg < sameNameCurveMaxTurnDegree;
      if (gentle && (prevStreet == after || nextStreet == after)) {
        return true;
      }
    }

    // «Siga por la derecha/izquierda» sin calle nombrada = bifurcación en Y (decisión).
    return false;
  }

  /// Valhalla 9/14: mantenerse en un brazo de la bifurcación (no «Gire a la …»).
  static bool isForkBearManeuver(NavigationManeuver maneuver) {
    final vt = maneuver.valhallaType;
    if (vt == 9 || vt == 14) {
      return true;
    }
    final t = maneuver.instruction.toLowerCase().trim();
    return t.startsWith('siga por la derecha') ||
        t.startsWith('siga por la izquierda');
  }

  static bool _isGenericUnnamedTurn(NavigationManeuver maneuver) {
    final begin = normalizeStreetName(maneuver.beginStreetName);
    final after = normalizeStreetName(maneuver.streetName);
    if (begin.isNotEmpty || after.isNotEmpty) {
      return false;
    }
    final t = maneuver.instruction.toLowerCase().trim();
    if (t == 'gire a la derecha.' ||
        t == 'gire a la izquierda.' ||
        t.startsWith('siga por la derecha') ||
        t.startsWith('siga por la izquierda')) {
      return true;
    }
    return false;
  }

  static double? _effectiveTurnAngleAbs(NavigationManeuver maneuver) {
    final valhalla = maneuver.turnDegree;
    if (valhalla != null) {
      return valhalla.abs().toDouble();
    }
    final poly = maneuver.polylineTurnDegrees;
    if (poly != null) {
      return poly.abs();
    }
    return null;
  }

  /// Elimina alertas de curva que coinciden con un giro de cruce real.
  static List<RouteAlert> filterCurvesAtSignificantTurns(
    List<RouteAlert> curves,
    NavigationRoute route, {
    required double Function(NavigationManeuver maneuver) maneuverAlongMeters,
  }) {
    if (curves.isEmpty || route.maneuvers.isEmpty) {
      return curves;
    }

    final junctionAlongs = <double>[];
    final maneuvers = route.maneuvers;
    for (var i = 0; i < maneuvers.length; i++) {
      final maneuver = maneuvers[i];
      if (maneuver.type != ManeuverType.turnLeft &&
          maneuver.type != ManeuverType.turnRight) {
        continue;
      }
      if (!isSignificantNavigationManeuver(
        maneuver,
        next: i + 1 < maneuvers.length ? maneuvers[i + 1] : null,
        previous: i > 0 ? maneuvers[i - 1] : null,
      )) {
        continue;
      }
      junctionAlongs.add(maneuverAlongMeters(maneuver));
    }

    if (junctionAlongs.isEmpty) {
      return curves;
    }

    return [
      for (final curve in curves)
        if (!_curveConflictsWithJunctionTurn(
          curve.distanceAlongRouteMeters,
          junctionAlongs,
        ))
          curve,
    ];
  }

  static bool _curveConflictsWithJunctionTurn(
    double curveAlong,
    List<double> junctionAlongs,
  ) {
    for (final junctionAlong in junctionAlongs) {
      final delta = curveAlong - junctionAlong;
      if (delta >= -junctionCurveExcludeBehindMeters &&
          delta <= junctionCurveExcludeAheadMeters) {
        return true;
      }
    }
    return false;
  }

  /// Siguiente maniobra relevante tras [afterIndex] (p. ej. hint «Después»).
  static NavigationManeuver? nextSignificantAfter(
    List<NavigationManeuver> maneuvers,
    int afterIndex,
  ) {
    for (var i = afterIndex + 1; i < maneuvers.length; i++) {
      if (isSignificantNavigationManeuver(
        maneuvers[i],
        next: i + 1 < maneuvers.length ? maneuvers[i + 1] : null,
        previous: i > 0 ? maneuvers[i - 1] : null,
      )) {
        return maneuvers[i];
      }
    }
    return null;
  }

  static bool _instructionIndicatesContinuation(String instruction) {
    final t = instruction.toLowerCase();
    if (t.contains('continúa') ||
        t.contains('continua') ||
        t.contains('continue') ||
        t.contains('mantente') ||
        t.contains('mantente en') ||
        t.contains('permanece') ||
        t.contains('permanecer') ||
        t.contains('permanezca') ||
        t.contains('to stay on')) {
      return true;
    }
    if (t.contains('sigue recto') || t.contains('siga recto')) {
      return true;
    }
    return false;
  }
}
