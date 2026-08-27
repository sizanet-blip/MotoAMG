import 'package:flutter_test/flutter_test.dart';
import 'package:loc_motos/features/navigation/domain/entities/route_preferences.dart';

void main() {
  group('RoutePreferences.toValhallaCostingOptions', () {
    test('Rápida y Solo secundarias difieren en highways y top_speed', () {
      const avoid = RoutePreferences(avoidHighways: true);
      final fast = avoid
          .copyWith(curvature: RouteCurvatureLevel.fast)
          .toValhallaCostingOptions('motorcycle');
      final max = avoid
          .copyWith(curvature: RouteCurvatureLevel.maxCurves)
          .toValhallaCostingOptions('motorcycle');

      expect(fast['use_highways'], 0.35);
      expect(max['use_highways'], 0.0);
      expect(fast['top_speed'], 120);
      expect(max['top_speed'], 38);
    });

    test('los cuatro niveles tienen top_speed distintos', () {
      const prefs = RoutePreferences();
      final speeds = RouteCurvatureLevel.values
          .map(
            (level) => prefs
                .copyWith(curvature: level)
                .toValhallaCostingOptions('motorcycle')['top_speed'],
          )
          .toSet();
      expect(speeds.length, RouteCurvatureLevel.values.length);
    });
  });
}
