import 'package:flutter/foundation.dart';
import 'package:moto_amg/core/api_usage/tomtom_route_preview_snapshot.dart';
import 'package:moto_amg/features/navigation/data/models/navigation_route_model.dart';
import 'package:moto_amg/features/navigation/domain/entities/tomtom_route_enrichment.dart';

/// Identificador de APIs externas que MotoAMG puede consumir.
enum MotoAmgApi {
  tomtomSnapToRoads,
}

extension MotoAmgApiX on MotoAmgApi {
  String get label => switch (this) {
        MotoAmgApi.tomtomSnapToRoads => 'TomTom · Snap to Roads (límites)',
      };
}

enum ApiCallOutcome { success, failure, skipped }

@immutable
class ApiCallRecord {
  const ApiCallRecord({
    required this.api,
    required this.outcome,
    required this.at,
    this.httpStatus,
    this.message,
    this.detail,
  });

  final MotoAmgApi api;
  final ApiCallOutcome outcome;
  final DateTime at;
  final int? httpStatus;
  final String? message;
  final String? detail;
}

@immutable
class ApiUsageStats {
  const ApiUsageStats({
    this.successCount = 0,
    this.failureCount = 0,
    this.skippedCount = 0,
    this.last,
  });

  final int successCount;
  final int failureCount;
  final int skippedCount;
  final ApiCallRecord? last;

  int get totalAttempts => successCount + failureCount;

  ApiUsageStats copyWith({
    int? successCount,
    int? failureCount,
    int? skippedCount,
    ApiCallRecord? last,
  }) {
    return ApiUsageStats(
      successCount: successCount ?? this.successCount,
      failureCount: failureCount ?? this.failureCount,
      skippedCount: skippedCount ?? this.skippedCount,
      last: last ?? this.last,
    );
  }
}

/// Contadores de sesión en memoria (no sustituye el panel de TomTom).
class ApiUsageTracker extends ChangeNotifier {
  ApiUsageTracker._();
  static final ApiUsageTracker instance = ApiUsageTracker._();

  final Map<MotoAmgApi, ApiUsageStats> _byApi = {};
  TomTomRoutePreviewSnapshot? _lastTomTomRoute;

  TomTomRoutePreviewSnapshot? get lastTomTomRoute => _lastTomTomRoute;

  ApiUsageStats statsFor(MotoAmgApi api) =>
      _byApi[api] ?? const ApiUsageStats();

  Map<MotoAmgApi, ApiUsageStats> get all => Map.unmodifiable(_byApi);

  /// Guarda la última ruta enriquecida con TomTom (solo memoria, esta sesión).
  void saveTomTomRoutePreview(TomTomRouteEnrichment enrichment) {
    final route = enrichment.route;
    if (route is! NavigationRouteModel || route.speedLimitSegments.isEmpty) {
      return;
    }
    _lastTomTomRoute = TomTomRoutePreviewSnapshot(
      routeJson: route.toJson(),
      enrichedAt: DateTime.now(),
      motoAmgSegmentsJson: TomTomRoutePreviewSnapshot.segmentsToJson(
        enrichment.motoAmgSegments,
      ),
      tomtomSegmentsJson: TomTomRoutePreviewSnapshot.segmentsToJson(
        enrichment.tomtomSegments,
      ),
    );
    notifyListeners();
  }

  void record({
    required MotoAmgApi api,
    required ApiCallOutcome outcome,
    int? httpStatus,
    String? message,
    String? detail,
  }) {
    final record = ApiCallRecord(
      api: api,
      outcome: outcome,
      at: DateTime.now(),
      httpStatus: httpStatus,
      message: message,
      detail: detail,
    );
    final prev = statsFor(api);
    final next = switch (outcome) {
      ApiCallOutcome.success => prev.copyWith(
          successCount: prev.successCount + 1,
          last: record,
        ),
      ApiCallOutcome.failure => prev.copyWith(
          failureCount: prev.failureCount + 1,
          last: record,
        ),
      ApiCallOutcome.skipped => prev.copyWith(
          skippedCount: prev.skippedCount + 1,
          last: record,
        ),
    };
    _byApi[api] = next;
    notifyListeners();
  }

  void reset() {
    _byApi.clear();
    _lastTomTomRoute = null;
    notifyListeners();
  }
}
