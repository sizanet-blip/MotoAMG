import 'package:flutter_test/flutter_test.dart';
import 'package:loc_motos/features/navigation/data/models/navigation_route_model.dart';
import 'package:loc_motos/features/navigation/domain/entities/geo_point.dart';
import 'package:loc_motos/features/navigation/domain/entities/navigation_maneuver.dart';

void main() {
  group('NavigationRouteModel.fromValhalla', () {
    test('convierte longitudes de km a metros', () {
      const origin = GeoPoint(lat: 40.4168, lng: -3.7038);
      const destination = GeoPoint(lat: 40.9489, lng: -2.5058);
      final route = NavigationRouteModel.fromValhalla(
        {
          'trip': {
            'legs': [
              {
                'summary': {'length': 12.5, 'time': 900},
                'shape': 'w~l~Fjk~uOwHJy@P',
                'maneuvers': [
                  {
                    'type': 1,
                    'instruction': 'Sal',
                    'verbal_pre_transition_instruction':
                        'Sal. Después, Continúe.',
                    'length': 0.2,
                    'begin_shape_index': 0,
                  },
                  {
                    'type': 4,
                    'instruction': 'Llegada',
                    'length': 0,
                    'begin_shape_index': 2,
                  },
                ],
              },
            ],
          },
        },
        origin: origin,
        destination: destination,
      );

      expect(route.distanceMeters, 12500);
      expect(route.durationSeconds, 900);
      expect(route.maneuvers.first.distanceMeters, 200);
      expect(route.maneuvers.first.instruction, 'Sal');
      expect(route.maneuvers.first.beginShapeIndex, 0);
      expect(route.maneuvers.last.beginShapeIndex, 2);
      expect(route.maneuvers.last.type, ManeuverType.arrive);
      expect(route.maneuvers, hasLength(2));
      expect(route.polyline, isNotEmpty);
      expect(route.maneuvers.last.location, route.polyline[2]);
    });

    test('parsea y fusiona límites de trace_attributes', () {
      final segments = NavigationRouteModel.speedLimitsFromTraceAttributes({
        'edges': [
          {
            'speed_limit': 30,
            'begin_shape_index': 0,
            'end_shape_index': 2,
          },
          {
            'speed_limit': 30,
            'begin_shape_index': 2,
            'end_shape_index': 4,
          },
          {
            'speed_limit': 50,
            'begin_shape_index': 4,
            'end_shape_index': 8,
          },
          {
            'begin_shape_index': 8,
            'end_shape_index': 9,
          },
        ],
      });
      expect(segments, hasLength(2));
      expect(segments.first.speedLimitKmh, 30);
      expect(segments.first.beginShapeIndex, 0);
      expect(segments.first.endShapeIndex, 4);
      expect(segments.last.speedLimitKmh, 50);
    });

    test('mapea rotonda Valhalla (26/27) y giros izquierda/derecha', () {
      expect(
        NavigationRouteModel.mapValhallaManeuverType(26),
        ManeuverType.roundabout,
      );
      expect(
        NavigationRouteModel.mapValhallaManeuverType(27),
        ManeuverType.roundabout,
      );
      expect(
        NavigationRouteModel.mapValhallaManeuverType(10),
        ManeuverType.turnRight,
      );
      expect(
        NavigationRouteModel.mapValhallaManeuverType(15),
        ManeuverType.turnLeft,
      );
      expect(
        NavigationRouteModel.mapValhallaManeuverType(4),
        ManeuverType.arrive,
      );
    });
  });
}
