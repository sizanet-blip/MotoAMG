import 'package:flutter_test/flutter_test.dart';
import 'package:loc_motos/features/navigation/data/datasources/tomtom_snap_to_roads_datasource.dart';
import 'package:loc_motos/features/navigation/data/services/speed_limit_merge.dart';
import 'package:loc_motos/features/navigation/domain/entities/geo_point.dart';
import 'package:loc_motos/features/navigation/domain/entities/speed_limit_segment.dart';

void main() {
  group('TomTomSnapToRoadsDataSource.chunkPolylineByMaxDistance', () {
    test('ruta corta → un solo tramo', () {
      final points = [
        const GeoPoint(lat: 40.0, lng: -3.0),
        const GeoPoint(lat: 40.01, lng: -3.0),
        const GeoPoint(lat: 40.02, lng: -3.0),
      ];
      final chunks = TomTomSnapToRoadsDataSource.chunkPolylineByMaxDistance(
        points,
        maxMeters: 95000,
      );
      expect(chunks, hasLength(1));
      expect(chunks.single, hasLength(3));
    });

    test('ruta larga → varios tramos bajo el tope', () {
      // ~1 km por paso en lat (~0.009°)
      final points = [
        for (var i = 0; i < 150; i++)
          GeoPoint(lat: 40.0 + i * 0.009, lng: -3.0),
      ];
      final chunks = TomTomSnapToRoadsDataSource.chunkPolylineByMaxDistance(
        points,
        maxMeters: 50000,
      );
      expect(chunks.length, greaterThan(1));
      for (final chunk in chunks) {
        expect(chunk.length, greaterThanOrEqualTo(2));
        var len = 0.0;
        for (var i = 1; i < chunk.length; i++) {
          final a = chunk[i - 1];
          final b = chunk[i];
          // Distancia aproximada solo para aserto débil
          final dLat = (b.lat - a.lat).abs() * 111000;
          len += dLat;
        }
        expect(len, lessThanOrEqualTo(52000));
      }
    });
  });

  group('TomTomSnapToRoadsDataSource.samplePolylineForSnap', () {
    test('deja corta la polilínea si cabe', () {
      final points = [
        const GeoPoint(lat: 40.0, lng: -3.0),
        const GeoPoint(lat: 40.01, lng: -3.01),
        const GeoPoint(lat: 40.02, lng: -3.02),
      ];
      final sample = TomTomSnapToRoadsDataSource.samplePolylineForSnap(points);
      expect(sample, hasLength(3));
      expect(sample.first, points.first);
      expect(sample.last, points.last);
    });

    test('reduce a maxPoints en polilíneas largas', () {
      final points = [
        for (var i = 0; i < 500; i++)
          GeoPoint(lat: 40 + i * 0.001, lng: -3 + i * 0.001),
      ];
      final sample = TomTomSnapToRoadsDataSource.samplePolylineForSnap(
        points,
        maxPoints: 50,
      );
      expect(sample.length, lessThanOrEqualTo(50));
      expect(sample.first, points.first);
      expect(sample.last.lat, closeTo(points.last.lat, 0.002));
    });
  });

  group('TomTomSnapToRoadsDataSource.segmentsFromSnapResponse', () {
    final polyline = [
      const GeoPoint(lat: 40.0, lng: -3.70),
      const GeoPoint(lat: 40.01, lng: -3.70),
      const GeoPoint(lat: 40.02, lng: -3.70),
      const GeoPoint(lat: 40.03, lng: -3.70),
      const GeoPoint(lat: 40.04, lng: -3.70),
    ];

    test('mapea Maximum kmph a SpeedLimitSegment', () {
      final segments = TomTomSnapToRoadsDataSource.segmentsFromSnapResponse(
        {
          'route': [
            {
              'type': 'Feature',
              'geometry': {
                'type': 'LineString',
                'coordinates': [
                  [-3.70, 40.0],
                  [-3.70, 40.015],
                ],
              },
              'properties': {
                'speedLimits': {
                  'value': 90,
                  'unit': 'kmph',
                  'type': 'Maximum',
                },
              },
            },
            {
              'type': 'Feature',
              'geometry': {
                'type': 'LineString',
                'coordinates': [
                  [-3.70, 40.02],
                  [-3.70, 40.04],
                ],
              },
              'properties': {
                'speedLimits': {
                  'value': 120,
                  'unit': 'kmph',
                  'type': 'Maximum',
                },
              },
            },
          ],
        },
        routePolyline: polyline,
      );
      expect(segments, isNotEmpty);
      expect(segments.any((s) => s.speedLimitKmh == 90), isTrue);
      expect(segments.any((s) => s.speedLimitKmh == 120), isTrue);
    });

    test('ignora tipos que no son Maximum', () {
      final segments = TomTomSnapToRoadsDataSource.segmentsFromSnapResponse(
        {
          'route': [
            {
              'geometry': {
                'type': 'LineString',
                'coordinates': [
                  [-3.70, 40.0],
                  [-3.70, 40.02],
                ],
              },
              'properties': {
                'speedLimits': {
                  'value': 70,
                  'unit': 'kmph',
                  'type': 'Advisory',
                },
              },
            },
          ],
        },
        routePolyline: polyline,
      );
      expect(segments, isEmpty);
    });

    test('sin route → vacío', () {
      expect(
        TomTomSnapToRoadsDataSource.segmentsFromSnapResponse(
          {},
          routePolyline: polyline,
        ),
        isEmpty,
      );
    });
  });

  group('SpeedLimitMerge', () {
    test('TomTom pisa tramos Valhalla solapados', () {
      const base = [
        SpeedLimitSegment(
          beginShapeIndex: 0,
          endShapeIndex: 10,
          speedLimitKmh: 90,
        ),
      ];
      const overlay = [
        SpeedLimitSegment(
          beginShapeIndex: 4,
          endShapeIndex: 6,
          speedLimitKmh: 70,
        ),
      ];
      final merged = SpeedLimitMerge.mergePreferringOverlay(
        base: base,
        overlay: overlay,
        polylineLength: 11,
      );
      expect(merged, hasLength(3));
      expect(merged[0].speedLimitKmh, 90);
      expect(merged[0].beginShapeIndex, 0);
      expect(merged[0].endShapeIndex, 3);
      expect(merged[1].speedLimitKmh, 70);
      expect(merged[1].beginShapeIndex, 4);
      expect(merged[1].endShapeIndex, 6);
      expect(merged[2].speedLimitKmh, 90);
      expect(merged[2].beginShapeIndex, 7);
      expect(merged[2].endShapeIndex, 10);
    });

    test('sin overlay deja la base', () {
      const base = [
        SpeedLimitSegment(
          beginShapeIndex: 0,
          endShapeIndex: 5,
          speedLimitKmh: 50,
        ),
      ];
      final merged = SpeedLimitMerge.mergePreferringOverlay(
        base: base,
        overlay: const [],
        polylineLength: 6,
      );
      expect(merged.single.speedLimitKmh, 50);
    });

    test('sin base usa solo overlay', () {
      const overlay = [
        SpeedLimitSegment(
          beginShapeIndex: 0,
          endShapeIndex: 3,
          speedLimitKmh: 120,
        ),
      ];
      final merged = SpeedLimitMerge.mergePreferringOverlay(
        base: const [],
        overlay: overlay,
        polylineLength: 4,
      );
      expect(merged.single.speedLimitKmh, 120);
    });
  });

  group('TomTomSnapToRoadsDataSource config', () {
    test('sin key no está configurado', () {
      final ds = TomTomSnapToRoadsDataSource(apiKey: '');
      expect(ds.isConfigured, isFalse);
    });

    test('con key está configurado', () {
      final ds = TomTomSnapToRoadsDataSource(apiKey: 'test-key');
      expect(ds.isConfigured, isTrue);
    });

    test('fetch sin key devuelve vacío', () async {
      final ds = TomTomSnapToRoadsDataSource(apiKey: '');
      final segments = await ds.fetchSpeedLimitSegments([
        const GeoPoint(lat: 40.0, lng: -3.0),
        const GeoPoint(lat: 40.1, lng: -3.1),
      ]);
      expect(segments, isEmpty);
    });
  });
}
