import 'package:flutter_test/flutter_test.dart';
import 'package:loc_motos/features/navigation/data/models/navigation_route_model.dart';
import 'package:loc_motos/features/navigation/domain/entities/geo_point.dart';

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
                    'length': 0.2,
                    'lat': 40.4168,
                    'lon': -3.7038,
                  },
                  {
                    'type': 20,
                    'instruction': 'Llegada',
                    'length': 0,
                    'lat': 40.9489,
                    'lon': -2.5058,
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
      expect(route.maneuvers, hasLength(2));
      expect(route.polyline, isNotEmpty);
    });
  });
}
