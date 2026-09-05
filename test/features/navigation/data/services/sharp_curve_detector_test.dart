import 'package:flutter_test/flutter_test.dart';
import 'package:moto_amg/features/navigation/data/services/sharp_curve_detector.dart';
import 'package:moto_amg/features/navigation/domain/entities/geo_point.dart';
import 'package:moto_amg/features/navigation/domain/entities/route_alert.dart';

void main() {
  group('SharpCurveDetector', () {
    test('detects a right hairpin and classifies severity', () {
      // Giro ~180° a la derecha en pocos segmentos.
      const poly = [
        GeoPoint(lat: 41.0000, lng: -1.0000),
        GeoPoint(lat: 41.0010, lng: -1.0000),
        GeoPoint(lat: 41.0015, lng: -0.9995),
        GeoPoint(lat: 41.0015, lng: -0.9985),
        GeoPoint(lat: 41.0010, lng: -0.9980),
        GeoPoint(lat: 41.0000, lng: -0.9980),
      ];

      final alerts = SharpCurveDetector.detect(
        poly,
        windowMeters: 200,
        minBearingDeltaDeg: 35,
        minSeparationMeters: 50,
      );

      expect(alerts, isNotEmpty);
      final first = alerts.first;
      expect(first.type, RouteAlertType.sharpCurve);
      expect(first.curveTurn, CurveTurn.right);
      expect(
        first.effectiveCurveSeverity,
        isIn([
          CurveSeverity.tight,
          CurveSeverity.hairpin,
          CurveSeverity.pronounced,
        ]),
      );
      expect(first.curveDegrees, greaterThan(50));
    });

    test('ignores nearly straight roads', () {
      const poly = [
        GeoPoint(lat: 41.00, lng: -1.00),
        GeoPoint(lat: 41.01, lng: -1.00),
        GeoPoint(lat: 41.02, lng: -1.00),
        GeoPoint(lat: 41.03, lng: -1.00),
      ];

      final alerts = SharpCurveDetector.detect(poly);
      expect(alerts, isEmpty);
    });

    test('separates successive curves by minSeparation', () {
      // Norte → este (90°) → norte largo → este (90°).
      final poly = <GeoPoint>[
        const GeoPoint(lat: 41.0000, lng: -1.0000),
        const GeoPoint(lat: 41.0010, lng: -1.0000),
        const GeoPoint(lat: 41.0015, lng: -0.9995),
        const GeoPoint(lat: 41.0015, lng: -0.9985), // fin 1ª curva ~90°
        const GeoPoint(lat: 41.0025, lng: -0.9985),
        const GeoPoint(lat: 41.0035, lng: -0.9985),
        const GeoPoint(lat: 41.0045, lng: -0.9985), // recta ~330 m
        const GeoPoint(lat: 41.0050, lng: -0.9980),
        const GeoPoint(lat: 41.0050, lng: -0.9970), // 2ª curva ~90°
        const GeoPoint(lat: 41.0050, lng: -0.9960),
      ];

      final alerts = SharpCurveDetector.detect(
        poly,
        windowMeters: 120,
        minBearingDeltaDeg: 35,
        minSeparationMeters: 180,
      );

      expect(alerts.length, greaterThanOrEqualTo(2));
      final gap = alerts[1].distanceAlongRouteMeters -
          alerts[0].distanceAlongRouteMeters;
      expect(gap, greaterThanOrEqualTo(180));
    });
  });

  group('RouteAlert curve voice', () {
    test('announces severity and side', () {
      const alert = RouteAlert(
        id: 'c1',
        type: RouteAlertType.sharpCurve,
        point: GeoPoint(lat: 0, lng: 0),
        distanceAlongRouteMeters: 1000,
        label: 'Cerrada izquierda',
        curveSeverity: CurveSeverity.tight,
        curveTurn: CurveTurn.left,
        curveDegrees: 100,
      );

      expect(
        alert.announcementForDistance(250),
        'Se aproxima curva cerrada a la izquierda en 250 metros',
      );
      expect(
        alert.announcementForDistance(40, imminent: true),
        'Se aproxima curva cerrada a la izquierda',
      );
    });
  });

  group('CurveSeverity.fromTurnDegrees', () {
    test('maps degree bands', () {
      expect(CurveSeverity.fromTurnDegrees(40), CurveSeverity.open);
      expect(CurveSeverity.fromTurnDegrees(70), CurveSeverity.pronounced);
      expect(CurveSeverity.fromTurnDegrees(100), CurveSeverity.tight);
      expect(CurveSeverity.fromTurnDegrees(150), CurveSeverity.hairpin);
    });
  });
}
