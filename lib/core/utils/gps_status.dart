import 'package:loc_motos/core/constants/app_constants.dart';

bool isGpsStale(DateTime updatedAt, DateTime now) {
  return now.difference(updatedAt) >= AppConstants.gpsStaleAfter;
}

/// Etiqueta corta para marcador de grupo («hace 2 min»).
String formatGpsStaleLabel(DateTime updatedAt, DateTime now) {
  if (!isGpsStale(updatedAt, now)) {
    return 'Sin señal';
  }
  final diff = now.difference(updatedAt);
  if (diff.inMinutes < 1) {
    return 'Sin señal · ahora';
  }
  if (diff.inMinutes < 60) {
    final minutes = diff.inMinutes;
    return minutes == 1
        ? 'Sin señal · hace 1 min'
        : 'Sin señal · hace $minutes min';
  }
  final hours = diff.inHours;
  return hours == 1 ? 'Sin señal · hace 1 h' : 'Sin señal · hace $hours h';
}
