import 'package:equatable/equatable.dart';
import 'package:moto_amg/core/constants/navigation_constants.dart';
import 'package:moto_amg/features/navigation/domain/entities/geo_point.dart';

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

  /// Color del marcador en mapa / chip HUD.
  int get mapColorArgb => switch (this) {
        RadarKind.fixed => 0xFFC62828,
        RadarKind.section => 0xFFE65100,
        RadarKind.trailer => 0xFF6A1B9A,
        RadarKind.unknown => 0xFFB71C1C,
      };
}

/// Gravedad geométrica de una curva (detector de polilínea).
enum CurveSeverity {
  /// ~35–54°.
  open,

  /// ~55–89°.
  pronounced,

  /// ~90–134°.
  tight,

  /// ≥ ~135° (casi 180°).
  hairpin;

  static CurveSeverity fromTurnDegrees(double absDegrees) {
    final deg = absDegrees.abs();
    if (deg >= 135) {
      return CurveSeverity.hairpin;
    }
    if (deg >= 90) {
      return CurveSeverity.tight;
    }
    if (deg >= 55) {
      return CurveSeverity.pronounced;
    }
    return CurveSeverity.open;
  }
}

extension CurveSeverityX on CurveSeverity {
  String get shortLabel => switch (this) {
        CurveSeverity.open => 'Abierta',
        CurveSeverity.pronounced => 'Pronunciada',
        CurveSeverity.tight => 'Cerrada',
        CurveSeverity.hairpin => 'Muy cerrada',
      };

  String get titleLabel => switch (this) {
        CurveSeverity.open => 'CURVA ABIERTA',
        CurveSeverity.pronounced => 'CURVA PRONUNCIADA',
        CurveSeverity.tight => 'CURVA CERRADA',
        CurveSeverity.hairpin => 'CURVA MUY CERRADA',
      };

  String get voiceNoun => switch (this) {
        CurveSeverity.open => 'curva abierta',
        CurveSeverity.pronounced => 'curva pronunciada',
        CurveSeverity.tight => 'curva cerrada',
        CurveSeverity.hairpin => 'curva muy cerrada',
      };

  int get mapColorArgb => switch (this) {
        CurveSeverity.open => 0xFF26A69A,
        CurveSeverity.pronounced => 0xFF00897B,
        CurveSeverity.tight => 0xFFEF6C00,
        CurveSeverity.hairpin => 0xFFC62828,
      };
}

enum CurveTurn {
  left,
  right,
}

extension CurveTurnX on CurveTurn {
  String get shortLabel => switch (this) {
        CurveTurn.left => 'Izquierda',
        CurveTurn.right => 'Derecha',
      };

  String get voiceSide => switch (this) {
        CurveTurn.left => 'a la izquierda',
        CurveTurn.right => 'a la derecha',
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
        RouteAlertType.sharpCurve => 'Curva en',
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
    this.curveSeverity,
    this.curveTurn,
    this.curveDegrees,
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

  /// Solo para [RouteAlertType.sharpCurve].
  final CurveSeverity? curveSeverity;

  /// Solo para [RouteAlertType.sharpCurve].
  final CurveTurn? curveTurn;

  /// Giro estimado en grados (valor absoluto), solo curvas.
  final double? curveDegrees;

  RadarKind get effectiveRadarKind =>
      radarKind ?? RadarKind.unknown;

  CurveSeverity get effectiveCurveSeverity =>
      curveSeverity ?? CurveSeverity.pronounced;

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
    if (type == RouteAlertType.sharpCurve) {
      final noun = effectiveCurveSeverity.voiceNoun;
      final side = curveTurn?.voiceSide;
      final sidePart = side != null ? ' $side' : '';
      if (imminent || metersAhead <= NavigationConstants.curveAnnounceMeters + 5) {
        return 'Se aproxima $noun$sidePart';
      }
      return 'Se aproxima $noun$sidePart en $distance';
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
    CurveSeverity? curveSeverity,
    CurveTurn? curveTurn,
    double? curveDegrees,
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
      curveSeverity: curveSeverity ?? this.curveSeverity,
      curveTurn: curveTurn ?? this.curveTurn,
      curveDegrees: curveDegrees ?? this.curveDegrees,
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
    final severityName = json['curveSeverity'] as String?;
    final severity = severityName == null
        ? null
        : CurveSeverity.values.firstWhere(
            (s) => s.name == severityName,
            orElse: () => CurveSeverity.pronounced,
          );
    final turnName = json['curveTurn'] as String?;
    final turn = turnName == null
        ? null
        : CurveTurn.values.firstWhere(
            (t) => t.name == turnName,
            orElse: () => CurveTurn.right,
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
      curveSeverity: severity,
      curveTurn: turn,
      curveDegrees: (json['curveDegrees'] as num?)?.toDouble(),
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
        'curveSeverity': curveSeverity?.name,
        'curveTurn': curveTurn?.name,
        'curveDegrees': curveDegrees,
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
        curveSeverity,
        curveTurn,
        curveDegrees,
      ];
}
