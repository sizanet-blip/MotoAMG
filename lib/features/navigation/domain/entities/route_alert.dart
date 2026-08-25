import 'package:equatable/equatable.dart';
import 'package:loc_motos/features/navigation/domain/entities/geo_point.dart';

enum RouteAlertType {
  toll,
  fuel,
  speedCamera,
  sharpCurve,
}

/// Clasificación de radar para UI / voz.
enum RadarKind {
  /// Cabina fija puntual.
  fixed,

  /// Radar de tramo / velocidad media.
  section,

  /// Cinemómetro en remolque / móvil señalizado.
  trailer,

  /// Tipo desconocido (p. ej. OSM sin tags).
  unknown,
}

extension RadarKindX on RadarKind {
  String get shortLabel => switch (this) {
        RadarKind.fixed => 'Fijo',
        RadarKind.section => 'Tramo',
        RadarKind.trailer => 'Remolque',
        RadarKind.unknown => 'Radar',
      };

  String get titleLabel => switch (this) {
        RadarKind.fixed => 'RADAR FIJO',
        RadarKind.section => 'RADAR DE TRAMO',
        RadarKind.trailer => 'RADAR REMOLQUE',
        RadarKind.unknown => 'RADAR',
      };

  String get voiceNoun => switch (this) {
        RadarKind.fixed => 'Radar fijo',
        RadarKind.section => 'Radar de tramo',
        RadarKind.trailer => 'Radar remolque',
        RadarKind.unknown => 'Radar',
      };
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
    this.radarKind,
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

  /// Solo para [RouteAlertType.speedCamera].
  final RadarKind? radarKind;

  RadarKind get effectiveRadarKind =>
      radarKind ?? RadarKind.unknown;

  String get voiceAnnouncement => type.voicePrefix;

  String announcementForDistance(double metersAhead, {bool imminent = false}) {
    final distance = metersAhead < 1000
        ? '${metersAhead.round()} metros'
        : '${(metersAhead / 1000).toStringAsFixed(1).replaceAll('.', ',')} kilómetros';
    if (type == RouteAlertType.speedCamera) {
      final kind = effectiveRadarKind.voiceNoun;
      final speed = speedLimitKmh != null && speedLimitKmh! > 0
          ? ', límite $speedLimitKmh kilómetros por hora'
          : '';
      if (imminent) {
        return speedLimitKmh != null && speedLimitKmh! > 0
            ? '$kind. Límite $speedLimitKmh'
            : '$kind delante';
      }
      return '$kind en $distance$speed';
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
    RadarKind? radarKind,
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
      radarKind: radarKind ?? this.radarKind,
    );
  }

  factory RouteAlert.fromJson(Map<String, dynamic> json) {
    final typeName = json['type'] as String? ?? 'fuel';
    final type = RouteAlertType.values.firstWhere(
      (t) => t.name == typeName,
      orElse: () => RouteAlertType.fuel,
    );
    final kindName = json['radarKind'] as String?;
    final kind = kindName == null
        ? null
        : RadarKind.values.firstWhere(
            (k) => k.name == kindName,
            orElse: () => RadarKind.unknown,
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
      radarKind: kind,
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
        'radarKind': radarKind?.name,
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
        radarKind,
      ];
}
