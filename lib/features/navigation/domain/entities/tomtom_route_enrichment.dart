import 'package:equatable/equatable.dart';
import 'package:moto_amg/features/navigation/domain/entities/navigation_route.dart';
import 'package:moto_amg/features/navigation/domain/entities/speed_limit_segment.dart';

/// Resultado de enriquecer una ruta con TomTom (sin volver a llamar a la API).
class TomTomRouteEnrichment extends Equatable {
  const TomTomRouteEnrichment({
    required this.route,
    required this.motoAmgSegments,
    required this.tomtomSegments,
  });

  final NavigationRoute route;
  final List<SpeedLimitSegment> motoAmgSegments;
  final List<SpeedLimitSegment> tomtomSegments;

  @override
  List<Object?> get props => [route, motoAmgSegments, tomtomSegments];
}
