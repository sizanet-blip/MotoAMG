import 'package:flutter_test/flutter_test.dart';
import 'package:moto_amg/features/navigation/data/services/route_guidance_service.dart';
import 'package:moto_amg/features/navigation/domain/entities/geo_point.dart';
import 'package:moto_amg/features/navigation/domain/entities/navigation_maneuver.dart';
import 'package:moto_amg/features/navigation/domain/entities/navigation_route.dart';
import 'package:moto_amg/features/navigation/domain/entities/route_alert.dart';
import 'package:moto_amg/features/navigation/domain/services/maneuver_significance.dart';

void main() {
  group('ManeuverSignificance', () {
    test('giro con misma vía antes y después es curva, no cambio de calle', () {
      const bend = NavigationManeuver(
        index: 1,
        type: ManeuverType.turnRight,
        valhallaType: 10,
        turnDegree: 28,
        instruction: 'Gira a la derecha',
        distanceMeters: 200,
        location: GeoPoint(lat: 0, lng: 0),
        streetName: 'Carretera de la Sierra',
        beginStreetName: 'Carretera de la Sierra',
      );
      expect(
        ManeuverSignificance.isSignificantNavigationManeuver(bend),
        isFalse,
      );
      expect(ManeuverSignificance.isSameRoadBend(bend), isTrue);
    });

    test('to_stay_on de Valhalla indica cruce sin cambiar de vía', () {
      const crossing = NavigationManeuver(
        index: 1,
        type: ManeuverType.turnRight,
        valhallaType: 10,
        toStayOn: true,
        instruction: 'Gira a la derecha para permanecer en CV-500',
        distanceMeters: 80,
        location: GeoPoint(lat: 0, lng: 0),
        streetName: 'CV-500',
        beginStreetName: 'Camino Secundario',
      );
      expect(
        ManeuverSignificance.isSignificantNavigationManeuver(crossing),
        isFalse,
      );
    });

    test('cruce real con cambio de vía nombrada es giro significativo', () {
      const previous = NavigationManeuver(
        index: 0,
        type: ManeuverType.depart,
        instruction: 'Sal',
        distanceMeters: 400,
        location: GeoPoint(lat: 0, lng: 0),
        streetName: 'CV-700',
      );
      const junction = NavigationManeuver(
        index: 1,
        type: ManeuverType.turnRight,
        valhallaType: 10,
        instruction: 'Gira a la derecha hacia CV-700',
        distanceMeters: 300,
        location: GeoPoint(lat: 0, lng: 0),
        streetName: 'CV-700',
        beginStreetName: 'Camino Transversal',
      );
      expect(
        ManeuverSignificance.isSignificantNavigationManeuver(
          junction,
          previous: previous,
        ),
        isTrue,
      );
    });

    test('giro con cambio de calle sigue siendo significativo', () {
      const turn = NavigationManeuver(
        index: 1,
        type: ManeuverType.turnRight,
        valhallaType: 10,
        instruction: 'Gira a la derecha hacia Calle Mayor',
        distanceMeters: 200,
        location: GeoPoint(lat: 0, lng: 0),
        streetName: 'Calle Mayor',
        beginStreetName: 'Avenida Principal',
      );
      expect(
        ManeuverSignificance.isSignificantNavigationManeuver(turn),
        isTrue,
      );
    });

    test('giro leve con misma calle en la siguiente maniobra es curva', () {
      const bend = NavigationManeuver(
        index: 1,
        type: ManeuverType.turnRight,
        valhallaType: 9,
        instruction: 'Gira levemente a la derecha',
        distanceMeters: 80,
        location: GeoPoint(lat: 0, lng: 0),
        streetName: 'CV-500',
      );
      const next = NavigationManeuver(
        index: 2,
        type: ManeuverType.turnLeft,
        valhallaType: 14,
        instruction: 'Gira levemente a la izquierda',
        distanceMeters: 120,
        location: GeoPoint(lat: 0, lng: 0),
        streetName: 'CV-500',
      );
      expect(
        ManeuverSignificance.isSignificantNavigationManeuver(
          bend,
          next: next,
        ),
        isFalse,
      );
    });

    test('nextSignificantAfter salta curvas intermedias', () {
      final maneuvers = [
        const NavigationManeuver(
          index: 0,
          type: ManeuverType.depart,
          instruction: 'Sal',
          distanceMeters: 500,
          location: GeoPoint(lat: 0, lng: 0),
        ),
        const NavigationManeuver(
          index: 1,
          type: ManeuverType.turnRight,
          valhallaType: 10,
          turnDegree: 30,
          instruction: 'Gira a la derecha',
          distanceMeters: 100,
          location: GeoPoint(lat: 0, lng: 0),
          streetName: 'Camino Viejo',
          beginStreetName: 'Camino Viejo',
        ),
        const NavigationManeuver(
          index: 2,
          type: ManeuverType.turnLeft,
          valhallaType: 10,
          instruction: 'Gira a la izquierda hacia Plaza',
          distanceMeters: 400,
          location: GeoPoint(lat: 0, lng: 0),
          streetName: 'Plaza',
          beginStreetName: 'Camino Viejo',
        ),
      ];
      final next = ManeuverSignificance.nextSignificantAfter(maneuvers, 0);
      expect(next?.index, 2);
      expect(next?.streetName, 'Plaza');
    });

    test('bifurcación en Y con mismo nombre OSM es giro significativo', () {
      const fork = NavigationManeuver(
        index: 1,
        type: ManeuverType.turnRight,
        valhallaType: 10,
        turnDegree: 85,
        instruction: 'Gira a la derecha',
        distanceMeters: 2000,
        location: GeoPoint(lat: 0, lng: 0),
        streetName: 'Camino Rural',
        beginStreetName: 'Camino Rural',
      );
      expect(
        ManeuverSignificance.isSignificantNavigationManeuver(fork),
        isTrue,
      );
      expect(ManeuverSignificance.isSameRoadBend(fork), isFalse);
    });

    test('type 9 sin nombre en bifurcación en Y es giro significativo', () {
      const fork = NavigationManeuver(
        index: 2,
        type: ManeuverType.turnRight,
        valhallaType: 9,
        instruction: 'Siga por la derecha.',
        distanceMeters: 1800,
        location: GeoPoint(lat: 0, lng: 0),
        polylineTurnDegrees: -27,
      );
      expect(
        ManeuverSignificance.isSignificantNavigationManeuver(fork),
        isTrue,
      );
      expect(ManeuverSignificance.isForkBearManeuver(fork), isTrue);
    });

    test('type 10 genérico con giro suave sigue siendo curva', () {
      const bend = NavigationManeuver(
        index: 2,
        type: ManeuverType.turnRight,
        valhallaType: 10,
        instruction: 'Gire a la derecha.',
        distanceMeters: 800,
        location: GeoPoint(lat: 0, lng: 0),
        polylineTurnDegrees: -25,
      );
      expect(
        ManeuverSignificance.isSignificantNavigationManeuver(bend),
        isFalse,
      );
    });

    test('filterCurvesAtSignificantTurns elimina curva en cruce con giro real', () {
      const polyline = [
        GeoPoint(lat: 41.0, lng: -1.0),
        GeoPoint(lat: 41.001, lng: -1.0),
        GeoPoint(lat: 41.001, lng: -0.999),
        GeoPoint(lat: 41.002, lng: -0.999),
      ];
      final route = NavigationRoute(
        id: 'junction',
        origin: polyline.first,
        destination: polyline.last,
        polyline: polyline,
        maneuvers: [
          const NavigationManeuver(
            index: 0,
            type: ManeuverType.depart,
            instruction: 'Sal',
            distanceMeters: 300,
            location: GeoPoint(lat: 41.0, lng: -1.0),
            beginShapeIndex: 0,
          ),
          const NavigationManeuver(
            index: 1,
            type: ManeuverType.turnRight,
            valhallaType: 10,
            instruction: 'Gira a la derecha hacia CV-700',
            distanceMeters: 200,
            location: GeoPoint(lat: 41.001, lng: -1.0),
            beginShapeIndex: 1,
            streetName: 'CV-700',
            beginStreetName: 'Camino',
          ),
        ],
        distanceMeters: 500,
        durationSeconds: 60,
        createdAt: DateTime(2026),
      );
      final guidance = RouteGuidanceService();
      final junctionAlong = guidance.distanceAtShapeIndex(polyline, 1);
      final curves = [
        RouteAlert(
          id: 'curve_junction',
          type: RouteAlertType.sharpCurve,
          point: polyline[1],
          distanceAlongRouteMeters: junctionAlong,
          label: 'Cerrada derecha',
        ),
        RouteAlert(
          id: 'curve_far',
          type: RouteAlertType.sharpCurve,
          point: polyline[3],
          distanceAlongRouteMeters: junctionAlong + 500,
          label: 'Cerrada derecha',
        ),
      ];

      final filtered = ManeuverSignificance.filterCurvesAtSignificantTurns(
        curves,
        route,
        maneuverAlongMeters: (maneuver) =>
            guidance.distanceAlongRouteMeters(maneuver.location, polyline),
      );

      expect(filtered.map((c) => c.id), ['curve_far']);
    });
  });

  group('RouteGuidanceService — curvas vs giros', () {
    final polyline = [
      const GeoPoint(lat: 40.0, lng: -3.0),
      const GeoPoint(lat: 40.005, lng: -3.0),
      const GeoPoint(lat: 40.01, lng: -3.0),
      const GeoPoint(lat: 40.02, lng: -3.0),
    ];

    final routeWithBend = NavigationRoute(
      id: 'bend',
      origin: polyline.first,
      destination: polyline.last,
      polyline: polyline,
      maneuvers: [
        const NavigationManeuver(
          index: 0,
          type: ManeuverType.depart,
          instruction: 'Sal',
          distanceMeters: 500,
          location: GeoPoint(lat: 40.0, lng: -3.0),
          beginShapeIndex: 0,
        ),
        const NavigationManeuver(
          index: 1,
          type: ManeuverType.turnRight,
          valhallaType: 10,
          turnDegree: 28,
          instruction: 'Gira a la derecha',
          distanceMeters: 300,
          location: GeoPoint(lat: 40.005, lng: -3.0),
          beginShapeIndex: 1,
          streetName: 'Carretera del Puerto',
          beginStreetName: 'Carretera del Puerto',
        ),
        const NavigationManeuver(
          index: 2,
          type: ManeuverType.turnLeft,
          valhallaType: 10,
          instruction: 'Gira a la izquierda hacia Calle Nueva',
          distanceMeters: 800,
          location: GeoPoint(lat: 40.02, lng: -3.0),
          beginShapeIndex: 3,
          streetName: 'Calle Nueva',
          beginStreetName: 'Carretera del Puerto',
        ),
      ],
      distanceMeters: 2200,
      durationSeconds: 180,
      createdAt: DateTime(2026),
    );

    final guidance = RouteGuidanceService();

    test('cerca de una curva muestra el siguiente giro real, no la curva', () {
      const nearBend = GeoPoint(lat: 40.0048, lng: -3.0);
      final index = guidance.resolveUpcomingManeuverIndex(
        position: nearBend,
        route: routeWithBend,
        passedThresholdMeters: 20,
      );
      expect(index, 2);

      final remaining = guidance.remainingMetersToUpcoming(
        position: nearBend,
        route: routeWithBend,
        upcomingIndex: index,
      );
      expect(remaining, greaterThan(1500));
    });

    test('cruce real cercano se muestra como maniobra, no se salta', () {
      final routeWithJunction = NavigationRoute(
        id: 'junction',
        origin: polyline.first,
        destination: polyline.last,
        polyline: polyline,
        maneuvers: [
          const NavigationManeuver(
            index: 0,
            type: ManeuverType.depart,
            instruction: 'Sal',
            distanceMeters: 100,
            location: GeoPoint(lat: 40.0, lng: -3.0),
            beginShapeIndex: 0,
            streetName: 'CV-700',
          ),
          const NavigationManeuver(
            index: 1,
            type: ManeuverType.turnRight,
            valhallaType: 10,
            instruction: 'Gira a la derecha hacia CV-700',
            distanceMeters: 7000,
            location: GeoPoint(lat: 40.005, lng: -3.0),
            beginShapeIndex: 1,
            streetName: 'CV-700',
            beginStreetName: 'Camino',
          ),
          const NavigationManeuver(
            index: 2,
            type: ManeuverType.turnLeft,
            valhallaType: 10,
            instruction: 'Gira a la izquierda',
            distanceMeters: 800,
            location: GeoPoint(lat: 40.02, lng: -3.0),
            beginShapeIndex: 3,
            streetName: 'CV-700',
            beginStreetName: 'Otra',
          ),
        ],
        distanceMeters: 8000,
        durationSeconds: 600,
        createdAt: DateTime(2026),
      );

      const nearJunction = GeoPoint(lat: 40.0048, lng: -3.0);
      final index = guidance.resolveUpcomingManeuverIndex(
        position: nearJunction,
        route: routeWithJunction,
        passedThresholdMeters: 20,
      );
      expect(index, 1);
    });
  });
}
