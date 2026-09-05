import 'package:geolocator/geolocator.dart';
import 'package:moto_amg/features/navigation/domain/entities/geo_point.dart';
import 'package:moto_amg/features/navigation/presentation/helpers/route_progress_split.dart';

/// Dos rutas siguen el mismo corredor (p. ej. la misma A-220) aunque Valhalla
/// devuelva tiempos distintos en peticiones con otro perfil.
bool routesShareSameCorridor(
  List<GeoPoint> a,
  List<GeoPoint> b, {
  double maxLateralMeters = 80,
  double minMatchedRatio = 0.88,
  int maxSamples = 40,
}) {
  if (a.length < 2 || b.length < 2) {
    return false;
  }
  final ratioA = _matchedSampleRatio(a, b, maxSamples, maxLateralMeters);
  final ratioB = _matchedSampleRatio(b, a, maxSamples, maxLateralMeters);
  final matched = ratioA < ratioB ? ratioA : ratioB;
  return matched >= minMatchedRatio;
}

double _matchedSampleRatio(
  List<GeoPoint> reference,
  List<GeoPoint> other,
  int maxSamples,
  double maxLateralMeters,
) {
  final samples = _samplePolyline(reference, maxSamples);
  if (samples.isEmpty) {
    return 0;
  }
  var matched = 0;
  for (final point in samples) {
    final snap = projectOntoPolyline(other, point.lat, point.lng);
    if (snap != null && snap.distanceMeters <= maxLateralMeters) {
      matched++;
    }
  }
  return matched / samples.length;
}

List<GeoPoint> _samplePolyline(List<GeoPoint> polyline, int maxSamples) {
  if (polyline.length <= maxSamples) {
    return List<GeoPoint>.from(polyline);
  }
  final step = (polyline.length - 1) / (maxSamples - 1);
  return [
    for (var i = 0; i < maxSamples; i++)
      polyline[(i * step).round().clamp(0, polyline.length - 1)],
  ];
}

/// Longitud aproximada de la polilínea (para logs/tests).
double polylineLengthMeters(List<GeoPoint> polyline) {
  if (polyline.length < 2) {
    return 0;
  }
  var total = 0.0;
  for (var i = 0; i < polyline.length - 1; i++) {
    total += Geolocator.distanceBetween(
      polyline[i].lat,
      polyline[i].lng,
      polyline[i + 1].lat,
      polyline[i + 1].lng,
    );
  }
  return total;
}
