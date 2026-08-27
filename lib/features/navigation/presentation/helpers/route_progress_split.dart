import 'package:geolocator/geolocator.dart';
import 'package:loc_motos/features/navigation/domain/entities/geo_point.dart';

/// Parte la polilínea en tramo ya recorrido (atenuado) y restante (activo).
({List<GeoPoint> traveled, List<GeoPoint> remaining}) splitRoutePolyline(
  List<GeoPoint> polyline,
  double lat,
  double lng,
) {
  if (polyline.length < 2) {
    return (traveled: const [], remaining: List<GeoPoint>.from(polyline));
  }

  var bestSeg = 0;
  var bestT = 0.0;
  var bestDist = double.infinity;
  GeoPoint? bestPoint;

  for (var i = 0; i < polyline.length - 1; i++) {
    final a = polyline[i];
    final b = polyline[i + 1];
    final projected = _projectOnSegment(lat, lng, a, b);
    final d = Geolocator.distanceBetween(
      lat,
      lng,
      projected.point.lat,
      projected.point.lng,
    );
    if (d < bestDist) {
      bestDist = d;
      bestSeg = i;
      bestT = projected.t;
      bestPoint = projected.point;
    }
  }

  final at = bestPoint!;
  final traveled = <GeoPoint>[
    ...polyline.sublist(0, bestSeg + 1),
    if (bestT > 0.02) at,
  ];
  final remaining = <GeoPoint>[
    at,
    ...polyline.sublist(bestSeg + 1),
  ];

  if (remaining.length < 2) {
    return (
      traveled: traveled.length >= 2 ? traveled : polyline,
      remaining: polyline.length >= 2
          ? polyline.sublist(polyline.length - 2)
          : polyline,
    );
  }
  if (traveled.length < 2) {
    return (traveled: const [], remaining: remaining);
  }
  return (traveled: traveled, remaining: remaining);
}

({GeoPoint point, double t}) _projectOnSegment(
  double lat,
  double lng,
  GeoPoint a,
  GeoPoint b,
) {
  final abLat = b.lat - a.lat;
  final abLng = b.lng - a.lng;
  final abLen2 = abLat * abLat + abLng * abLng;
  if (abLen2 < 1e-18) {
    return (point: a, t: 0);
  }
  final apLat = lat - a.lat;
  final apLng = lng - a.lng;
  final t = (apLat * abLat + apLng * abLng) / abLen2;
  final clamped = t.clamp(0.0, 1.0);
  return (
    point: GeoPoint(
      lat: a.lat + abLat * clamped,
      lng: a.lng + abLng * clamped,
    ),
    t: clamped,
  );
}
