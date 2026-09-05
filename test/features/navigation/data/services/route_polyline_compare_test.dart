import 'package:flutter_test/flutter_test.dart';
import 'package:moto_amg/features/navigation/data/services/route_polyline_compare.dart';
import 'package:moto_amg/features/navigation/domain/entities/geo_point.dart';

void main() {
  group('routesShareSameCorridor', () {
    test('detects same path with slightly different polyline density', () {
      const a = [
        GeoPoint(lat: 41.0, lng: -1.0),
        GeoPoint(lat: 41.01, lng: -1.01),
        GeoPoint(lat: 41.02, lng: -1.02),
        GeoPoint(lat: 41.03, lng: -1.03),
      ];
      const b = [
        GeoPoint(lat: 41.0, lng: -1.0),
        GeoPoint(lat: 41.015, lng: -1.015),
        GeoPoint(lat: 41.03, lng: -1.03),
      ];

      expect(routesShareSameCorridor(a, b), isTrue);
    });

    test('does not treat clearly different paths as the same corridor', () {
      const a = [
        GeoPoint(lat: 41.0, lng: -1.0),
        GeoPoint(lat: 41.01, lng: -1.0),
        GeoPoint(lat: 41.02, lng: -1.0),
      ];
      const b = [
        GeoPoint(lat: 41.0, lng: -1.0),
        GeoPoint(lat: 41.01, lng: -0.99),
        GeoPoint(lat: 41.02, lng: -0.98),
      ];

      expect(routesShareSameCorridor(a, b), isFalse);
    });
  });
}
