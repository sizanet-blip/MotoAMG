String formatRideDistance(double meters) {
  if (!meters.isFinite || meters < 0) {
    return '—';
  }
  if (meters < 1000) {
    return '${meters.round()} m';
  }
  final km = meters / 1000;
  if (km < 10) {
    return '${km.toStringAsFixed(1).replaceAll('.', ',')} km';
  }
  return '${km.round()} km';
}
