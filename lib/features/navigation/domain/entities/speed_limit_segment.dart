import 'package:equatable/equatable.dart';

/// Tramo de la ruta con un límite de velocidad legal (km/h).
class SpeedLimitSegment extends Equatable {
  const SpeedLimitSegment({
    required this.beginShapeIndex,
    required this.endShapeIndex,
    required this.speedLimitKmh,
  });

  final int beginShapeIndex;
  final int endShapeIndex;
  final int speedLimitKmh;

  factory SpeedLimitSegment.fromJson(Map<String, dynamic> json) {
    return SpeedLimitSegment(
      beginShapeIndex: (json['beginShapeIndex'] as num).toInt(),
      endShapeIndex: (json['endShapeIndex'] as num).toInt(),
      speedLimitKmh: (json['speedLimitKmh'] as num).toInt(),
    );
  }

  Map<String, dynamic> toJson() => {
        'beginShapeIndex': beginShapeIndex,
        'endShapeIndex': endShapeIndex,
        'speedLimitKmh': speedLimitKmh,
      };

  @override
  List<Object?> get props => [beginShapeIndex, endShapeIndex, speedLimitKmh];
}
