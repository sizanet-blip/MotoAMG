import 'package:flutter/foundation.dart';

/// Identificador de APIs externas que LocMotos puede consumir.
enum LocMotosApi {
  tomtomSnapToRoads,
}

extension LocMotosApiX on LocMotosApi {
  String get label => switch (this) {
        LocMotosApi.tomtomSnapToRoads => 'TomTom · Snap to Roads (límites)',
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

  final LocMotosApi api;
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

  final Map<LocMotosApi, ApiUsageStats> _byApi = {};

  ApiUsageStats statsFor(LocMotosApi api) =>
      _byApi[api] ?? const ApiUsageStats();

  Map<LocMotosApi, ApiUsageStats> get all => Map.unmodifiable(_byApi);

  void record({
    required LocMotosApi api,
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
    notifyListeners();
  }
}
