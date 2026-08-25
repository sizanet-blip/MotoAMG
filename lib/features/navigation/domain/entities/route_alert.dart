import 'package:equatable/equatable.dart';
import 'package:loc_motos/features/navigation/domain/entities/geo_point.dart';

enum RouteAlertType {
  toll,
  fuel,
  speedCamera,
  sharpCurve,
}

extension RouteAlertTypeX on RouteAlertType {
  String get shortLabel => switch (this) {
        RouteAlertType.toll => 'Peaje',
        RouteAlertType.fuel => 'Gasolinera',
        RouteAlertType.speedCamera => 'Radar',
        RouteAlertType.sharpCurve => 'Curva',
      };

  String get voicePrefix => switch (this) {
        RouteAlertType.toll => 'Peaje en',
        RouteAlertType.fuel => 'Gasolinera en',
        RouteAlertType.speedCamera => 'Radar en',
        RouteAlertType.sharpCurve => 'Curva pronunciada en',
      };
}

/// Aviso a lo largo de la ruta (peaje, gasolinera, radar, curva).
class RouteAlert extends Equatable {
  const RouteAlert({
    required this.id,
    required this.type,
    required this.point,
    required this.distanceAlongRouteMeters,
    required this.label,
    this.meta,
    this.speedLimitKmh,
  });

  final String id;
  final RouteAlertType type;
  final GeoPoint point;

  /// Distancia desde el origen de la ruta hasta este aviso (metros).
  final double distanceAlongRouteMeters;

  final String label;

  /// Extra opcional (p. ej. nombre de gasolinera o carretera).
  final String? meta;

  /// Límite asociado al radar (km/h), si se conoce.
  final int? speedLimitKmh;

  String get voiceAnnouncement => type.voicePrefix;

  String announcementForDistance(double metersAhead, {bool imminent = false}) {
    final distance = metersAhead < 1000
        ? '${metersAhead.round()} metros'
        : '${(metersAhead / 1000).toStringAsFixed(1).replaceAll('.', ',')} kilómetros';
    if (type == RouteAlertType.speedCamera) {
      final speed = speedLimitKmh != null && speedLimitKmh! > 0
          ? ', límite $speedLimitKmh kilómetros por hora'
          : '';
      if (imminent) {
        return speedLimitKmh != null && speedLimitKmh! > 0
            ? 'Radar. Límite $speedLimitKmh'
            : 'Radar delante';
      }
      return 'Radar en $distance$speed';
    }
    final detail = meta != null && meta!.trim().isNotEmpty
        ? ', ${meta!.trim()}'
        : '';
    return '${type.voicePrefix} $distance$detail';
  }

  String get voicePrefix => type.voicePrefix;

  RouteAlert copyWith({
    String? id,
    RouteAlertType? type,
    GeoPoint? point,
    double? distanceAlongRouteMeters,
    String? label,
    String? meta,
    int? speedLimitKmh,
  }) {
    return RouteAlert(
      id: id ?? this.id,
      type: type ?? this.type,
      point: point ?? this.point,
      distanceAlongRouteMeters:
          distanceAlongRouteMeters ?? this.distanceAlongRouteMeters,
      label: label ?? this.label,
      meta: meta ?? this.meta,
      speedLimitKmh: speedLimitKmh ?? this.speedLimitKmh,
    );
  }

  factory RouteAlert.fromJson(Map<String, dynamic> json) {
    final typeName = json['type'] as String? ?? 'fuel';
    final type = RouteAlertType.values.firstWhere(
      (t) => t.name == typeName,
      orElse: () => RouteAlertType.fuel,
    );
    return RouteAlert(
      id: json['id'] as String,
      type: type,
      point: GeoPoint(
        lat: (json['lat'] as num).toDouble(),
        lng: (json['lng'] as num).toDouble(),
      ),
      distanceAlongRouteMeters:
          (json['distanceAlongRouteMeters'] as num).toDouble(),
      label: json['label'] as String? ?? type.shortLabel,
      meta: json['meta'] as String?,
      speedLimitKmh: (json['speedLimitKmh'] as num?)?.toInt(),
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'type': type.name,
        'lat': point.lat,
        'lng': point.lng,
        'distanceAlongRouteMeters': distanceAlongRouteMeters,
        'label': label,
        'meta': meta,
        'speedLimitKmh': speedLimitKmh,
      };

  @override
  List<Object?> get props => [
        id,
        type,
        point,
        distanceAlongRouteMeters,
        label,
        meta,
        speedLimitKmh,
      ];
}
