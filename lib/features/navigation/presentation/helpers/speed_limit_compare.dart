import 'package:moto_amg/features/navigation/data/services/route_guidance_service.dart';
import 'package:moto_amg/features/navigation/domain/entities/geo_point.dart';
import 'package:moto_amg/features/navigation/domain/entities/speed_limit_segment.dart';

/// Tramo donde MotoAMG y TomTom no coinciden.
class SpeedLimitDifference {
  const SpeedLimitDifference({
    required this.beginShapeIndex,
    required this.endShapeIndex,
    required this.motoAmgKmh,
    required this.tomtomKmh,
    required this.beginAlongMeters,
    required this.lengthMeters,
  });

  final int beginShapeIndex;
  final int endShapeIndex;
  final int? motoAmgKmh;
  final int? tomtomKmh;
  final double beginAlongMeters;
  final double lengthMeters;

  bool get motoAmgMissing => motoAmgKmh == null;
  bool get tomtomMissing => tomtomKmh == null;

  String get summary {
    final lm = motoAmgKmh?.toString() ?? '—';
    final tt = tomtomKmh?.toString() ?? '—';
    return '$lm → $tt km/h';
  }
}

class SpeedLimitCompareStats {
  const SpeedLimitCompareStats({
    required this.differences,
    required this.matchingPoints,
    required this.totalComparedPoints,
  });

  final List<SpeedLimitDifference> differences;
  final int matchingPoints;
  final int totalComparedPoints;

  int get differenceCount => differences.length;

  bool get hasDifferences => differences.isNotEmpty;

  double get matchRatio =>
      totalComparedPoints == 0 ? 1 : matchingPoints / totalComparedPoints;
}

abstract final class SpeedLimitCompare {
  static SpeedLimitCompareStats compare({
    required List<GeoPoint> polyline,
    required List<SpeedLimitSegment> motoAmg,
    required List<SpeedLimitSegment> tomtom,
  }) {
    if (polyline.isEmpty) {
      return const SpeedLimitCompareStats(
        differences: [],
        matchingPoints: 0,
        totalComparedPoints: 0,
      );
    }

    final lm = _limitsAtIndices(polyline.length, motoAmg);
    final tt = _limitsAtIndices(polyline.length, tomtom);
    final guidance = RouteGuidanceService();

    final differences = <SpeedLimitDifference>[];
    var matching = 0;
    var compared = 0;

    int? runStart;
    int? runLm;
    int? runTt;

    void flushRun(int endIndex) {
      if (runStart == null) {
        return;
      }
      final begin = runStart!;
      final end = endIndex.clamp(0, polyline.length - 1);
      if (end < begin) {
        runStart = null;
        runLm = null;
        runTt = null;
        return;
      }
      final beginAlong = guidance.distanceAtShapeIndex(polyline, begin);
      final endAlong = guidance.distanceAtShapeIndex(polyline, end);
      differences.add(
        SpeedLimitDifference(
          beginShapeIndex: begin,
          endShapeIndex: end,
          motoAmgKmh: runLm,
          tomtomKmh: runTt,
          beginAlongMeters: beginAlong,
          lengthMeters: (endAlong - beginAlong).clamp(0, 1e12),
        ),
      );
      runStart = null;
      runLm = null;
      runTt = null;
    }

    for (var i = 0; i < polyline.length; i++) {
      final a = lm[i];
      final b = tt[i];
      if (a == null && b == null) {
        flushRun(i - 1);
        continue;
      }
      compared++;
      if (a == b) {
        matching++;
        flushRun(i - 1);
        continue;
      }
      if (runStart == null) {
        runStart = i;
        runLm = a;
        runTt = b;
      } else if (a != runLm || b != runTt) {
        flushRun(i - 1);
        runStart = i;
        runLm = a;
        runTt = b;
      }
    }
    flushRun(polyline.length - 1);

    return SpeedLimitCompareStats(
      differences: List.unmodifiable(differences),
      matchingPoints: matching,
      totalComparedPoints: compared,
    );
  }

  /// Tramos solo donde difieren (para resaltar en el mapa).
  static List<SpeedLimitSegment> differenceSegments(
    List<SpeedLimitDifference> differences,
  ) {
    return [
      for (final d in differences)
        SpeedLimitSegment(
          beginShapeIndex: d.beginShapeIndex,
          endShapeIndex: d.endShapeIndex,
          speedLimitKmh: d.tomtomKmh ?? d.motoAmgKmh ?? 0,
        ),
    ];
  }

  static List<int?> _limitsAtIndices(
    int polylineLength,
    List<SpeedLimitSegment> segments,
  ) {
    final maxIdx = polylineLength - 1;
    final limits = List<int?>.filled(polylineLength, null);
    for (final segment in segments) {
      if (segment.speedLimitKmh <= 0) {
        continue;
      }
      final lo = segment.beginShapeIndex.clamp(0, maxIdx);
      final hi = segment.endShapeIndex.clamp(0, maxIdx);
      final a = lo <= hi ? lo : hi;
      final b = lo <= hi ? hi : lo;
      for (var i = a; i <= b; i++) {
        limits[i] = segment.speedLimitKmh;
      }
    }
    return limits;
  }
}
