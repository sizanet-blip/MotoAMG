import 'package:moto_amg/core/constants/navigation_constants.dart';

/// Antigüedad legible de datos España descargados (radares, gasolineras).
String formatSpainDataAge(DateTime? fetchedAt, {DateTime? now}) {
  if (fetchedAt == null) {
    return '';
  }
  final reference = (now ?? DateTime.now()).toLocal();
  final local = fetchedAt.toLocal();
  final diff = reference.difference(local);
  if (diff.isNegative) {
    return 'actualizado hace un momento';
  }
  if (diff.inMinutes < 1) {
    return 'actualizado hace un momento';
  }
  if (diff.inHours < 1) {
    final minutes = diff.inMinutes;
    return minutes == 1
        ? 'actualizado hace 1 minuto'
        : 'actualizado hace $minutes minutos';
  }
  if (diff.inHours < 24) {
    final hours = diff.inHours;
    return hours == 1
        ? 'actualizado hace 1 hora'
        : 'actualizado hace $hours horas';
  }
  final days = diff.inDays;
  if (days == 1) {
    return 'actualizado hace 1 día';
  }
  return 'actualizado hace $days días';
}

bool isSpainFuelDataStale(DateTime? fetchedAt, {DateTime? now}) {
  if (fetchedAt == null) {
    return false;
  }
  final age = (now ?? DateTime.now()).difference(fetchedAt);
  return age > NavigationConstants.spainFuelDiskMaxAge;
}

bool isSpainRadarDataStale(DateTime? fetchedAt, {DateTime? now}) {
  if (fetchedAt == null) {
    return false;
  }
  final age = (now ?? DateTime.now()).difference(fetchedAt);
  return age > NavigationConstants.spainRadarDiskMaxAge;
}

/// Mensaje corto para avisar de datos desactualizados.
String spainFuelStaleMessage(DateTime? fetchedAt) {
  if (!isSpainFuelDataStale(fetchedAt)) {
    return '';
  }
  final age = formatSpainDataAge(fetchedAt);
  return 'Los precios están antiguos ($age). '
      'Actualiza gasolineras en Configuración.';
}

bool isSpainRadarCacheStale({
  required bool hasOfficial,
  DateTime? officialFetchedAt,
  required bool hasOsm,
  DateTime? osmFetchedAt,
  DateTime? now,
}) {
  if (hasOfficial && isSpainRadarDataStale(officialFetchedAt, now: now)) {
    return true;
  }
  if (hasOsm && isSpainRadarDataStale(osmFetchedAt, now: now)) {
    return true;
  }
  return false;
}

/// True si no hay caché o la más antigua supera [intervalDays].
bool shouldRemindRadarUpdate({
  required bool hasOfficial,
  DateTime? officialFetchedAt,
  required bool hasOsm,
  DateTime? osmFetchedAt,
  required int intervalDays,
  DateTime? now,
}) {
  final days = intervalDays.clamp(1, 365);
  if (!hasOfficial && !hasOsm) {
    return true;
  }
  final reference = now ?? DateTime.now();
  final dates = <DateTime>[
    if (hasOfficial && officialFetchedAt != null) officialFetchedAt,
    if (hasOsm && osmFetchedAt != null) osmFetchedAt,
  ];
  if (dates.isEmpty) {
    return true;
  }
  dates.sort();
  final oldest = dates.first;
  return reference.difference(oldest) >= Duration(days: days);
}

String spainRadarCacheStaleMessage({
  required bool hasOfficial,
  DateTime? officialFetchedAt,
  required bool hasOsm,
  DateTime? osmFetchedAt,
}) {
  final staleOfficial =
      hasOfficial && isSpainRadarDataStale(officialFetchedAt);
  final staleOsm = hasOsm && isSpainRadarDataStale(osmFetchedAt);
  if (!staleOfficial && !staleOsm) {
    return '';
  }
  final parts = <String>[];
  if (staleOfficial) {
    parts.add(formatSpainDataAge(officialFetchedAt));
  }
  if (staleOsm) {
    parts.add(formatSpainDataAge(osmFetchedAt));
  }
  return 'Los radares están antiguos (${parts.join(' · ')}). '
      'Actualiza radares en Configuración.';
}
