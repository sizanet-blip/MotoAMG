import 'package:equatable/equatable.dart';
import 'package:moto_amg/features/navigation/domain/entities/geo_point.dart';

/// Controles de tráfico para pintar en el mapa (sin voz ni HUD de distancia).
enum RouteMapPoiKind {
  trafficSignal,
  stop,
  giveWay,
}

extension RouteMapPoiKindX on RouteMapPoiKind {
  String get shortLabel => switch (this) {
        RouteMapPoiKind.trafficSignal => 'Semáforo',
        RouteMapPoiKind.stop => 'STOP',
        RouteMapPoiKind.giveWay => 'Ceda',
      };
}

class RouteMapPoi extends Equatable {
  const RouteMapPoi({
    required this.id,
    required this.kind,
    required this.point,
    required this.distanceAlongRouteMeters,
    this.label,
  });

  final String id;
  final RouteMapPoiKind kind;
  final GeoPoint point;
  final double distanceAlongRouteMeters;
  final String? label;

  factory RouteMapPoi.fromJson(Map<String, dynamic> json) {
    final kindName = json['kind'] as String? ?? 'trafficSignal';
    final kind = RouteMapPoiKind.values.firstWhere(
      (k) => k.name == kindName,
      orElse: () => RouteMapPoiKind.trafficSignal,
    );
    return RouteMapPoi(
      id: json['id'] as String,
      kind: kind,
      point: GeoPoint(
        lat: (json['lat'] as num).toDouble(),
        lng: (json['lng'] as num).toDouble(),
      ),
      distanceAlongRouteMeters:
          (json['distanceAlongRouteMeters'] as num).toDouble(),
      label: json['label'] as String?,
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'kind': kind.name,
        'lat': point.lat,
        'lng': point.lng,
        'distanceAlongRouteMeters': distanceAlongRouteMeters,
        'label': label,
      };

  @override
  List<Object?> get props =>
      [id, kind, point, distanceAlongRouteMeters, label];
}
