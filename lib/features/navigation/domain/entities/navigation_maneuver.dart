import 'package:equatable/equatable.dart';
import 'package:loc_motos/features/navigation/domain/entities/geo_point.dart';

enum ManeuverType {
  depart,
  arrive,
  turn,
  continueStraight,
  roundabout,
  merge,
  ramp,
  unknown,
}

/// Instrucción giro a giro precargada (ruta en mochila).
class NavigationManeuver extends Equatable {
  const NavigationManeuver({
    required this.index,
    required this.type,
    required this.instruction,
    required this.distanceMeters,
    required this.location,
    this.streetName,
    this.laneHint,
    this.roundaboutExit,
  });

  final int index;
  final ManeuverType type;
  final String instruction;
  final double distanceMeters;
  final GeoPoint location;
  final String? streetName;
  final String? laneHint;
  final int? roundaboutExit;

  @override
  List<Object?> get props => [
    index,
    type,
    instruction,
    distanceMeters,
    location,
    streetName,
    laneHint,
    roundaboutExit,
  ];
}
