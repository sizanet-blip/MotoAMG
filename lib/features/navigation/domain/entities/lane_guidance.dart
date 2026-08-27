import 'package:equatable/equatable.dart';

/// Bitmasks Valhalla `lanes` (turn_lanes).
abstract final class LaneDirectionBits {
  static const empty = 0;
  static const none = 1;
  static const through = 2;
  static const sharpLeft = 4;
  static const left = 8;
  static const slightLeft = 16;
  static const slightRight = 32;
  static const right = 64;
  static const sharpRight = 128;
  static const reverse = 256;
  static const mergeToLeft = 512;
  static const mergeToRight = 1024;
}

/// Un carril de la maniobra (Valhalla).
class LaneInfo extends Equatable {
  const LaneInfo({
    required this.directions,
    this.valid = 0,
    this.active = 0,
  });

  /// Direcciones posibles del carril.
  final int directions;

  /// Usable para la ruta (puede requerir cambio posterior).
  final int valid;

  /// Preferido (sin más cambios de carril).
  final int active;

  bool get isActive => active != 0;
  bool get isValid => valid != 0 || isActive;
  bool get isRecommended => isActive || isValid;

  /// Direcciones a dibujar: active > valid > directions.
  int get displayMask {
    if (active != 0) {
      return active;
    }
    if (valid != 0) {
      return valid;
    }
    return directions;
  }

  Map<String, dynamic> toJson() => {
        'directions': directions,
        'valid': valid,
        'active': active,
      };

  factory LaneInfo.fromJson(Map<String, dynamic> json) {
    return LaneInfo(
      directions: (json['directions'] as num?)?.toInt() ?? 0,
      valid: (json['valid'] as num?)?.toInt() ?? 0,
      active: (json['active'] as num?)?.toInt() ?? 0,
    );
  }

  factory LaneInfo.fromValhalla(Map<String, dynamic> json) {
    return LaneInfo(
      directions: (json['directions'] as num?)?.toInt() ?? 0,
      valid: (json['valid'] as num?)?.toInt() ?? 0,
      active: (json['active'] as num?)?.toInt() ?? 0,
    );
  }

  @override
  List<Object?> get props => [directions, valid, active];
}

/// Extrae flechas individuales de un bitmask (máx. 3 para el dibujo).
List<int> laneArrowBits(int mask) {
  const order = [
    LaneDirectionBits.sharpLeft,
    LaneDirectionBits.left,
    LaneDirectionBits.slightLeft,
    LaneDirectionBits.through,
    LaneDirectionBits.slightRight,
    LaneDirectionBits.right,
    LaneDirectionBits.sharpRight,
    LaneDirectionBits.reverse,
    LaneDirectionBits.mergeToLeft,
    LaneDirectionBits.mergeToRight,
  ];
  final out = <int>[];
  for (final bit in order) {
    if ((mask & bit) != 0) {
      out.add(bit);
    }
  }
  if (out.isEmpty && mask != 0) {
    out.add(LaneDirectionBits.through);
  }
  if (out.length > 3) {
    return out.sublist(0, 3);
  }
  return out;
}
