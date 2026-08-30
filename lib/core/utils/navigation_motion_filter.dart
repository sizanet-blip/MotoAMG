import 'package:geolocator/geolocator.dart';

/// Suaviza lat/lng/velocidad entre fixes GPS para evitar trompicones en el HUD.
class NavigationMotionFilter {
  double? _lat;
  double? _lng;
  double? _speedMps;
  DateTime? _lastAt;

  ({double lat, double lng, double speedMps}) next({
    required double lat,
    required double lng,
    required double speedMps,
  }) {
    final now = DateTime.now();
    final prevLat = _lat;
    final prevLng = _lng;
    final prevSpeed = _speedMps;
    final lastAt = _lastAt;
    _lastAt = now;

    if (prevLat == null || prevLng == null || lastAt == null) {
      _lat = lat;
      _lng = lng;
      _speedMps = speedMps.clamp(0.0, 70.0);
      return (lat: lat, lng: lng, speedMps: _speedMps!);
    }

    final dtMs = now.difference(lastAt).inMilliseconds.clamp(1, 3000);
    final jump = Geolocator.distanceBetween(prevLat, prevLng, lat, lng);

    // Alpha más alto = más reactivo. Saltos enormes (túnel/relock) se aceptan.
    final posAlpha = jump > 45
        ? 1.0
        : jump > 18
            ? 0.55
            : dtMs < 400
                ? 0.42
                : 0.28;
    final nextLat = prevLat + (lat - prevLat) * posAlpha;
    final nextLng = prevLng + (lng - prevLng) * posAlpha;

    final rawSpeed = speedMps.isFinite && speedMps >= 0 ? speedMps : 0.0;
    final speedAlpha = (rawSpeed - (prevSpeed ?? 0)).abs() > 6 ? 0.55 : 0.28;
    final nextSpeed =
        ((prevSpeed ?? rawSpeed) + (rawSpeed - (prevSpeed ?? rawSpeed)) * speedAlpha)
            .clamp(0.0, 70.0);

    _lat = nextLat;
    _lng = nextLng;
    _speedMps = nextSpeed;
    return (lat: nextLat, lng: nextLng, speedMps: nextSpeed);
  }

  void reset() {
    _lat = null;
    _lng = null;
    _speedMps = null;
    _lastAt = null;
  }
}
