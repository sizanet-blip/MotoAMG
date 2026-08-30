import 'package:flutter_test/flutter_test.dart';
import 'package:loc_motos/features/navigation/domain/services/dgt_speed_limit_resolver.dart';

void main() {
  group('DgtSpeedLimitResolver', () {
    test('convencional rural → 90, nunca 100', () {
      expect(
        DgtSpeedLimitResolver.fromValhallaEdge({
          'road_class': 'secondary',
          'density': 1,
        }),
        90,
      );
      expect(
        DgtSpeedLimitResolver.fromValhallaEdge({
          'road_class': 'primary',
          'density': 0,
        }),
        90,
      );
      expect(
        DgtSpeedLimitResolver.fromValhallaEdge({
          'road_class': 'tertiary',
          'density': 3,
        }),
        90,
      );
    });

    test('motorway rural → 120; trunk sin maxspeed → duda (null)', () {
      expect(
        DgtSpeedLimitResolver.fromValhallaEdge({
          'road_class': 'motorway',
          'density': 0,
        }),
        120,
      );
      expect(
        DgtSpeedLimitResolver.fromValhallaEdge({
          'road_class': 'trunk',
          'density': 2,
        }),
        isNull,
      );
      expect(
        DgtSpeedLimitResolver.fromValhallaEdge({
          'road_class': 'trunk',
          'density': 10,
        }),
        isNull,
      );
    });

    test('urbano por densidad → 50 en primaria, 30 en residential', () {
      expect(
        DgtSpeedLimitResolver.fromValhallaEdge({
          'road_class': 'primary',
          'density': 10,
        }),
        50,
      );
      expect(
        DgtSpeedLimitResolver.fromValhallaEdge({
          'road_class': 'residential',
          'density': 0,
        }),
        30,
      );
    });

    test('sin pavimentar → 30', () {
      expect(
        DgtSpeedLimitResolver.fromValhallaEdge({
          'road_class': 'secondary',
          'unpaved': true,
        }),
        30,
      );
    });
  });
}
