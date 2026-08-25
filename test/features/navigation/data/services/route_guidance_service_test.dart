import 'package:flutter_test/flutter_test.dart';
import 'package:loc_motos/features/navigation/data/services/route_guidance_service.dart';
import 'package:loc_motos/features/navigation/domain/entities/geo_point.dart';
import 'package:loc_motos/features/navigation/domain/entities/navigation_maneuver.dart';
import 'package:loc_motos/features/navigation/domain/entities/navigation_route.dart';
import 'package:loc_motos/features/navigation/domain/entities/speed_limit_segment.dart';

void main() {
  group('RouteGuidanceService (estilo Waze)', () {
    // ~1112 m por 0.01° de latitud.
    final polyline = [
      const GeoPoint(lat: 40.0, lng: -3.0),
      const GeoPoint(lat: 40.01, lng: -3.0), // ~1112 m
      const GeoPoint(lat: 40.02, lng: -3.0), // ~2224 m
      const GeoPoint(lat: 40.03, lng: -3.0), // ~3336 m
    ];

    final route = NavigationRoute(
      id: 'test',
      origin: polyline.first,
      destination: polyline.last,
      polyline: polyline,
      maneuvers: [
        NavigationManeuver(
          index: 0,
          type: ManeuverType.depart,
          instruction: 'Sal',
          distanceMeters: 2224,
          location: polyline[0],
          beginShapeIndex: 0,
        ),
        NavigationManeuver(
          index: 1,
          type: ManeuverType.turn,
          instruction: 'Gire a la derecha',
          distanceMeters: 1112,
          location: polyline[2],
          beginShapeIndex: 2,
        ),
        NavigationManeuver(
          index: 2,
          type: ManeuverType.arrive,
          instruction: 'Has llegado',
          distanceMeters: 0,
          location: polyline[3],
          beginShapeIndex: 3,
        ),
      ],
      distanceMeters: 3336,
      durationSeconds: 300,
      createdAt: DateTime(2026),
    );

    final guidance = RouteGuidanceService();

    test('remainingRouteMeters baja al avanzar por la polilínea', () {
      expect(
        guidance.remainingRouteMeters(
          position: polyline.first,
          route: route,
        ),
        closeTo(3336, 5),
      );
      expect(
        guidance.remainingRouteMeters(
          position: polyline[2],
          route: route,
        ),
        closeTo(1112, 30),
      );
    });

    test('estimateRemainingDuration usa velocidad si te mueves', () {
      // 1112 m a 16.7 m/s (~60 km/h) ≈ 67 s
      final duration = guidance.estimateRemainingDuration(
        remainingMeters: 1112,
        speedMps: 16.7,
        routeDurationSeconds: 300,
        routeDistanceMeters: 3336,
      );
      expect(duration.inSeconds, closeTo(67, 3));
    });

    test('estimateRemainingDuration prorratea Valhalla si estás parado', () {
      // Mitad de la ruta → mitad del tiempo Valhalla
      final duration = guidance.estimateRemainingDuration(
        remainingMeters: 1668,
        speedMps: 0,
        routeDurationSeconds: 300,
        routeDistanceMeters: 3336,
      );
      expect(duration.inSeconds, closeTo(150, 2));
    });

    test('resolveSpeedLimitKmh cambia según el tramo', () {
      final withLimits = NavigationRoute(
        id: 'limits',
        origin: polyline.first,
        destination: polyline.last,
        polyline: polyline,
        maneuvers: route.maneuvers,
        distanceMeters: 3336,
        durationSeconds: 300,
        createdAt: DateTime(2026),
        speedLimitSegments: const [
          SpeedLimitSegment(
            beginShapeIndex: 0,
            endShapeIndex: 2,
            speedLimitKmh: 30,
          ),
          SpeedLimitSegment(
            beginShapeIndex: 2,
            endShapeIndex: 3,
            speedLimitKmh: 50,
          ),
        ],
      );
      expect(
        guidance.resolveSpeedLimitKmh(
          position: polyline.first,
          route: withLimits,
        ),
        30,
      );
      expect(
        guidance.resolveSpeedLimitKmh(
          position: polyline[2],
          route: withLimits,
        ),
        50,
      );
    });

    test('hasArrived es true cerca del destino', () {
      expect(
        guidance.hasArrived(
          position: polyline.last,
          route: route,
          thresholdMeters: 40,
        ),
        isTrue,
      );
      expect(
        guidance.hasArrived(
          position: polyline.first,
          route: route,
          thresholdMeters: 40,
        ),
        isFalse,
      );
    });

    test('al inicio el aviso es el primer giro (no solo Sal)', () {
      // Tras pasar depart (+20 m), el cartel debe ser el giro con cuenta atrás.
      const justStarted = GeoPoint(lat: 40.0005, lng: -3.0);
      final index = guidance.resolveUpcomingManeuverIndex(
        position: justStarted,
        route: route,
        passedThresholdMeters: 20,
      );
      expect(index, 1);

      final remaining = guidance.remainingMetersToUpcoming(
        position: justStarted,
        route: route,
        upcomingIndex: index,
      );
      // Hasta el índice 2 (~2224 m) menos lo ya recorrido (~55 m).
      expect(remaining, greaterThan(2000));
      expect(remaining, lessThan(2224));
    });

    test('con ~150 m al giro sigue mostrando ese giro y la distancia baja', () {
      // Índice 2 a ~2224 m; 150 m antes ≈ lat 40.01865
      const stillFar = GeoPoint(lat: 40.01865, lng: -3.0);
      final index = guidance.resolveUpcomingManeuverIndex(
        position: stillFar,
        route: route,
        passedThresholdMeters: 20,
      );
      expect(index, 1);

      final remaining = guidance.remainingMetersToUpcoming(
        position: stillFar,
        route: route,
        upcomingIndex: 1,
      );
      expect(remaining, greaterThan(100));
      expect(remaining, lessThan(200));
    });

    test('cerca del giro la distancia tiende a 0 y aún es ese aviso', () {
      const almostThere = GeoPoint(lat: 40.0199, lng: -3.0);
      final index = guidance.resolveUpcomingManeuverIndex(
        position: almostThere,
        route: route,
        passedThresholdMeters: 20,
      );
      expect(index, 1);
      final remaining = guidance.remainingMetersToUpcoming(
        position: almostThere,
        route: route,
        upcomingIndex: 1,
      );
      expect(remaining, lessThan(30));
    });

    test('tras pasar el giro cambia al siguiente aviso', () {
      // ~50 m después del índice 2.
      const afterTurn = GeoPoint(lat: 40.0205, lng: -3.0);
      final index = guidance.resolveUpcomingManeuverIndex(
        position: afterTurn,
        route: route,
        passedThresholdMeters: 20,
      );
      expect(index, 2);

      final remaining = guidance.remainingMetersToUpcoming(
        position: afterTurn,
        route: route,
        upcomingIndex: 2,
      );
      expect(remaining, greaterThan(900));
    });
  });

  group('shouldShowNextManeuverHint', () {
    test('oculta si la instrucción ya contiene la siguiente', () {
      const current = NavigationManeuver(
        index: 0,
        type: ManeuverType.depart,
        instruction:
            'Conduzca por Paseo. Después, Siga por la derecha hacia Plaza.',
        distanceMeters: 400,
        location: GeoPoint(lat: 0, lng: 0),
      );
      const next = NavigationManeuver(
        index: 1,
        type: ManeuverType.turn,
        instruction: 'Siga por la derecha hacia Plaza.',
        distanceMeters: 100,
        location: GeoPoint(lat: 0, lng: 0),
      );
      expect(shouldShowNextManeuverHint(current, next), isFalse);
    });

    test('muestra si la siguiente es distinta', () {
      const current = NavigationManeuver(
        index: 0,
        type: ManeuverType.turn,
        instruction: 'Gire a la derecha',
        distanceMeters: 400,
        location: GeoPoint(lat: 0, lng: 0),
      );
      const next = NavigationManeuver(
        index: 1,
        type: ManeuverType.turn,
        instruction: 'Gire a la izquierda hacia Calle Mayor',
        distanceMeters: 100,
        location: GeoPoint(lat: 0, lng: 0),
      );
      expect(shouldShowNextManeuverHint(current, next), isTrue);
    });
  });
}
