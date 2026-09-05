import 'package:flutter/foundation.dart';
import 'package:moto_amg/features/navigation/data/models/navigation_route_model.dart';
import 'package:moto_amg/features/navigation/domain/entities/navigation_route.dart';
import 'package:moto_amg/features/navigation/domain/entities/speed_limit_segment.dart';
import 'package:moto_amg/features/navigation/presentation/helpers/speed_limit_compare.dart';

/// Ruta enriquecida con TomTom guardada en memoria (solo esta sesión).
@immutable
class TomTomRoutePreviewSnapshot {
  const TomTomRoutePreviewSnapshot({
    required this.routeJson,
    required this.enrichedAt,
    this.motoAmgSegmentsJson = const [],
    this.tomtomSegmentsJson = const [],
  });

  final Map<String, dynamic> routeJson;
  final DateTime enrichedAt;
  final List<Map<String, dynamic>> motoAmgSegmentsJson;
  final List<Map<String, dynamic>> tomtomSegmentsJson;

  NavigationRoute get route => NavigationRouteModel.fromJson(routeJson);

  List<SpeedLimitSegment> get motoAmgSegments {
    if (motoAmgSegmentsJson.isEmpty) {
      return route.speedLimitSegments;
    }
    return _parseSegments(motoAmgSegmentsJson);
  }

  List<SpeedLimitSegment> get tomtomSegments =>
      _parseSegments(tomtomSegmentsJson);

  bool get canCompare =>
      motoAmgSegmentsJson.isNotEmpty && tomtomSegmentsJson.isNotEmpty;

  int get segmentCount => route.speedLimitSegments.length;

  SpeedLimitCompareStats compareStats() {
    return SpeedLimitCompare.compare(
      polyline: route.polyline,
      motoAmg: motoAmgSegments,
      tomtom: tomtomSegments,
    );
  }

  static List<SpeedLimitSegment> _parseSegments(
    Iterable<Map<String, dynamic>> raw,
  ) {
    return [
      for (final map in raw) SpeedLimitSegment.fromJson(map),
    ];
  }

  static List<Map<String, dynamic>> segmentsToJson(
    Iterable<SpeedLimitSegment> segments,
  ) {
    return [for (final s in segments) s.toJson()];
  }
}
