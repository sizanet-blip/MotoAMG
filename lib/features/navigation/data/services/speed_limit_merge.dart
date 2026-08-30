import 'package:loc_motos/features/navigation/data/models/navigation_route_model.dart';
import 'package:loc_motos/features/navigation/domain/entities/speed_limit_segment.dart';

/// Combina límites de varias fuentes. [overlay] (p. ej. TomTom) gana en solapes.
abstract final class SpeedLimitMerge {
  /// Pinta índices de forma y coalesce tramos contiguos con el mismo km/h.
  static List<SpeedLimitSegment> mergePreferringOverlay({
    required List<SpeedLimitSegment> base,
    required List<SpeedLimitSegment> overlay,
    required int polylineLength,
  }) {
    if (polylineLength < 1) {
      return const [];
    }
    if (overlay.isEmpty) {
      return base.isEmpty
          ? const []
          : NavigationRouteModel.coalesceSpeedLimits(base);
    }
    if (base.isEmpty) {
      return NavigationRouteModel.coalesceSpeedLimits(overlay);
    }

    final maxIdx = polylineLength - 1;
    final limits = List<int?>.filled(maxIdx + 1, null);

    void paint(Iterable<SpeedLimitSegment> segments) {
      for (final segment in segments) {
        if (segment.speedLimitKmh <= 0) {
          continue;
        }
        final a = segment.beginShapeIndex.clamp(0, maxIdx);
        final b = segment.endShapeIndex.clamp(0, maxIdx);
        final lo = a <= b ? a : b;
        final hi = a <= b ? b : a;
        for (var i = lo; i <= hi; i++) {
          limits[i] = segment.speedLimitKmh;
        }
      }
    }

    paint(base);
    paint(overlay);

    final raw = <SpeedLimitSegment>[];
    int? runStart;
    int? runLimit;
    for (var i = 0; i <= maxIdx; i++) {
      final value = limits[i];
      if (value == null) {
        if (runStart != null && runLimit != null) {
          raw.add(
            SpeedLimitSegment(
              beginShapeIndex: runStart,
              endShapeIndex: i - 1,
              speedLimitKmh: runLimit,
            ),
          );
          runStart = null;
          runLimit = null;
        }
        continue;
      }
      if (runStart == null) {
        runStart = i;
        runLimit = value;
        continue;
      }
      if (value != runLimit) {
        raw.add(
          SpeedLimitSegment(
            beginShapeIndex: runStart,
            endShapeIndex: i - 1,
            speedLimitKmh: runLimit!,
          ),
        );
        runStart = i;
        runLimit = value;
      }
    }
    if (runStart != null && runLimit != null) {
      raw.add(
        SpeedLimitSegment(
          beginShapeIndex: runStart,
          endShapeIndex: maxIdx,
          speedLimitKmh: runLimit,
        ),
      );
    }
    return List.unmodifiable(raw);
  }
}
