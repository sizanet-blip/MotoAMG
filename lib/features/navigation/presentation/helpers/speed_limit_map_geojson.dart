import 'package:moto_amg/features/navigation/domain/entities/geo_point.dart';
import 'package:moto_amg/features/navigation/domain/entities/navigation_route.dart';
import 'package:moto_amg/features/navigation/domain/entities/speed_limit_segment.dart';
import 'package:moto_amg/features/navigation/presentation/helpers/speed_limit_compare.dart';

/// GeoJSON para pintar límites de velocidad sobre la polilínea de ruta.
abstract final class SpeedLimitMapGeoJson {
  static const diffLineColor = '#7B1FA2';

  static String signIconId(int kmh) => 'motoamg-speed-sign-$kmh';

  static String diffSignIconId(int? motoAmgKmh, int? tomtomKmh) =>
      'motoamg-diff-sign-${motoAmgKmh ?? 'x'}-${tomtomKmh ?? 'x'}';

  static Map<String, dynamic> lines(NavigationRoute route) {
    return linesFromSegments(route.polyline, route.speedLimitSegments);
  }

  static Map<String, dynamic> linesFromSegments(
    List<GeoPoint> polyline,
    List<SpeedLimitSegment> segments, {
    String? fixedColor,
  }) {
    if (polyline.length < 2 || segments.isEmpty) {
      return {'type': 'FeatureCollection', 'features': <Map<String, dynamic>>[]};
    }

    final features = <Map<String, dynamic>>[];
    for (final segment in segments) {
      final slice = _slice(polyline, segment);
      if (slice.length < 2) {
        continue;
      }
      features.add({
        'type': 'Feature',
        'properties': {
          'limit': segment.speedLimitKmh,
          'color': fixedColor ?? _lineColor(segment.speedLimitKmh),
        },
        'geometry': {
          'type': 'LineString',
          'coordinates': [
            for (final p in slice) [p.lng, p.lat],
          ],
        },
      });
    }
    return {'type': 'FeatureCollection', 'features': features};
  }

  static Map<String, dynamic> diffLines(
    List<GeoPoint> polyline,
    List<SpeedLimitDifference> differences,
  ) {
    return linesFromSegments(
      polyline,
      SpeedLimitCompare.differenceSegments(differences),
      fixedColor: diffLineColor,
    );
  }

  /// Señal en el inicio de cada tramo (donde cambia el límite).
  static Map<String, dynamic> signs(NavigationRoute route) {
    return signsFromSegments(route.polyline, route.speedLimitSegments);
  }

  static Map<String, dynamic> signsFromSegments(
    List<GeoPoint> polyline,
    List<SpeedLimitSegment> segments,
  ) {
    if (polyline.length < 2 || segments.isEmpty) {
      return {'type': 'FeatureCollection', 'features': <Map<String, dynamic>>[]};
    }

    final features = <Map<String, dynamic>>[];
    var lastAlongIndex = -1;
    for (final segment in segments) {
      if (segment.speedLimitKmh <= 0) {
        continue;
      }
      final begin = segment.beginShapeIndex.clamp(0, polyline.length - 1);
      if (begin == lastAlongIndex) {
        continue;
      }
      lastAlongIndex = begin;
      final point = polyline[begin];
      features.add({
        'type': 'Feature',
        'properties': {
          'limit': segment.speedLimitKmh,
          'icon': signIconId(segment.speedLimitKmh),
        },
        'geometry': {
          'type': 'Point',
          'coordinates': [point.lng, point.lat],
        },
      });
    }
    return {'type': 'FeatureCollection', 'features': features};
  }

  /// Señal doble donde MotoAMG y TomTom difieren.
  static Map<String, dynamic> diffSigns(
    List<GeoPoint> polyline,
    List<SpeedLimitDifference> differences,
  ) {
    if (polyline.isEmpty || differences.isEmpty) {
      return {'type': 'FeatureCollection', 'features': <Map<String, dynamic>>[]};
    }
    return {
      'type': 'FeatureCollection',
      'features': [
        for (final diff in differences)
          {
            'type': 'Feature',
            'properties': {
              'icon': diffSignIconId(diff.motoAmgKmh, diff.tomtomKmh),
            },
            'geometry': {
              'type': 'Point',
              'coordinates': [
                polyline[diff.beginShapeIndex.clamp(0, polyline.length - 1)]
                    .lng,
                polyline[diff.beginShapeIndex.clamp(0, polyline.length - 1)]
                    .lat,
              ],
            },
          },
      ],
    };
  }

  static Set<int> uniqueLimits(NavigationRoute route) {
    return uniqueLimitsFromSegments(route.speedLimitSegments);
  }

  static Set<int> uniqueLimitsFromSegments(List<SpeedLimitSegment> segments) {
    return {
      for (final s in segments)
        if (s.speedLimitKmh > 0) s.speedLimitKmh,
    };
  }

  static Set<(int?, int?)> uniqueDiffPairs(
    List<SpeedLimitDifference> differences,
  ) {
    return {
      for (final d in differences) (d.motoAmgKmh, d.tomtomKmh),
    };
  }

  static List<GeoPoint> _slice(
    List<GeoPoint> polyline,
    SpeedLimitSegment segment,
  ) {
    final begin = segment.beginShapeIndex.clamp(0, polyline.length - 1);
    final end = segment.endShapeIndex.clamp(0, polyline.length - 1);
    if (end < begin) {
      return const [];
    }
    return polyline.sublist(begin, end + 1);
  }

  static String _lineColor(int kmh) {
    if (kmh <= 30) {
      return '#2E7D32';
    }
    if (kmh <= 50) {
      return '#558B2F';
    }
    if (kmh <= 70) {
      return '#F9A825';
    }
    if (kmh <= 90) {
      return '#EF6C00';
    }
    if (kmh <= 100) {
      return '#E65100';
    }
    return '#C62828';
  }
}
