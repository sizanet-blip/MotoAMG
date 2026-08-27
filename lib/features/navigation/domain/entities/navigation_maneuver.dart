import 'package:equatable/equatable.dart';
import 'package:loc_motos/features/navigation/domain/entities/geo_point.dart';
import 'package:loc_motos/features/navigation/domain/entities/lane_guidance.dart';

enum ManeuverType {
  depart,
  arrive,
  turn,
  continueStraight,
  roundabout,
  merge,
  ramp,
  unknown,
  /// Giro a la izquierda (Valhalla 14–16).
  turnLeft,
  /// Giro a la derecha (Valhalla 9–11).
  turnRight,
}

/// Instrucción giro a giro precargada (ruta en mochila).
class NavigationManeuver extends Equatable {
  const NavigationManeuver({
    required this.index,
    required this.type,
    required this.instruction,
    required this.distanceMeters,
    required this.location,
    this.beginShapeIndex = 0,
    this.streetName,
    this.laneHint,
    this.lanes = const [],
    this.roundaboutExit,
    this.voiceInstruction,
  });

  final int index;
  final ManeuverType type;

  /// Texto corto para la tarjeta (Valhalla `instruction`).
  final String instruction;

  /// Longitud del tramo hasta la siguiente maniobra (metros).
  final double distanceMeters;
  final GeoPoint location;

  /// Índice en la polilínea donde empieza esta maniobra (Valhalla).
  final int beginShapeIndex;

  final String? streetName;
  final String? laneHint;

  /// Carriles Valhalla (`turn_lanes`); vacío si no hay datos OSM/servidor.
  final List<LaneInfo> lanes;

  final int? roundaboutExit;

  /// Texto para TTS; si es null se usa [instruction].
  final String? voiceInstruction;

  String get spokenInstruction => voiceInstruction ?? instruction;

  bool get hasLaneGuidance => lanes.length >= 2;

  @override
  List<Object?> get props => [
        index,
        type,
        instruction,
        distanceMeters,
        location,
        beginShapeIndex,
        streetName,
        laneHint,
        lanes,
        roundaboutExit,
        voiceInstruction,
      ];
}
