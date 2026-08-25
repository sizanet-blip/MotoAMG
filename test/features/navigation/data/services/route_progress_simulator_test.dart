import 'package:flutter_test/flutter_test.dart';
import 'package:loc_motos/features/navigation/data/services/route_progress_simulator.dart';
import 'package:loc_motos/features/navigation/domain/entities/geo_point.dart';

void main() {
  group('RouteProgressSimulator', () {
    test('avanza a lo largo de la polilínea', () {
      const polyline = [
        GeoPoint(lat: 40.0, lng: -3.0),
        GeoPoint(lat: 40.01, lng: -3.0),
        GeoPoint(lat: 40.02, lng: -3.0),
      ];
      final simulator = RouteProgressSimulator(
        polyline: polyline,
        speedMps: 20,
      );

      expect(simulator.totalLengthMeters, greaterThan(2000));
      expect(simulator.isFinished, isFalse);

      final first = simulator.sample();
      expect(first.position.lat, closeTo(40.0, 0.0001));

      final mid = simulator.advance(const Duration(seconds: 30));
      expect(mid.finished, isFalse);
      expect(mid.position.lat, greaterThan(40.0));
      expect(mid.speedMps, 20);
      expect(mid.bearingDegrees, closeTo(0, 5));
    });

    test('marca finished al llegar al final', () {
      const polyline = [
        GeoPoint(lat: 40.0, lng: -3.0),
        GeoPoint(lat: 40.001, lng: -3.0),
      ];
      final simulator = RouteProgressSimulator(
        polyline: polyline,
        speedMps: 50,
      );

      RouteSimulationSample sample = simulator.sample();
      for (var i = 0; i < 50 && !sample.finished; i++) {
        sample = simulator.advance(const Duration(seconds: 1));
      }

      expect(sample.finished, isTrue);
      expect(sample.position.lat, closeTo(40.001, 0.0002));
      expect(simulator.progressRatio, 1);
    });
  });
}
