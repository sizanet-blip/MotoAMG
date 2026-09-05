import 'package:flutter_test/flutter_test.dart';
import 'package:moto_amg/features/navigation/data/services/route_guidance_service.dart';

import 'helpers/navigation_route_fixture.dart';

/// Ejecuta todos los JSON en [NavigationRouteFixture.fixturesDir].
///
/// Cuando reportes un fallo en carretera, se añade un `.json` nuevo y este test
/// lo valida automáticamente con `flutter test`.
void main() {
  final guidance = RouteGuidanceService();
  final files = NavigationRouteFixture.listFixtureFiles();

  test('hay al menos un fixture de navegación', () {
    expect(
      files,
      isNotEmpty,
      reason: 'Añade casos en test/fixtures/navigation/*.json',
    );
  });

  for (final file in files) {
    final json = NavigationRouteFixture.readJson(file);
    final id = json['id'] as String? ?? file.uri.pathSegments.last;
    final description = json['description'] as String? ?? id;

    test('fixture: $id — $description', () {
      final route = NavigationRouteFixture.loadRoute(json);
      final enriched = NavigationRouteFixture.withCurveAlerts(route);
      final checkpoints =
          json['checkpoints'] as List<dynamic>? ?? const [];

      expect(checkpoints, isNotEmpty, reason: 'El fixture necesita checkpoints');

      for (final raw in checkpoints) {
        NavigationRouteFixture.assertCheckpoint(
          route: enriched,
          checkpoint: raw as Map<String, dynamic>,
          guidance: guidance,
        );
      }
    });
  }
}
