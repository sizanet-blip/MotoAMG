import 'package:flutter/material.dart';

/// Iconos disponibles para el marcador GPS en navegación.
enum VehicleMapIcon {
  motorcycle,
  sportBike,
  scooter,
  car,
  carFilled,
  van,
  truck,
}

extension VehicleMapIconX on VehicleMapIcon {
  String get label => switch (this) {
        VehicleMapIcon.motorcycle => 'Moto',
        VehicleMapIcon.sportBike => 'Moto sport',
        VehicleMapIcon.scooter => 'Scooter',
        VehicleMapIcon.car => 'Coche',
        VehicleMapIcon.carFilled => 'Turismo',
        VehicleMapIcon.van => 'Furgoneta',
        VehicleMapIcon.truck => 'Camión',
      };

  IconData get iconData => switch (this) {
        VehicleMapIcon.motorcycle => Icons.two_wheeler_rounded,
        VehicleMapIcon.sportBike => Icons.sports_motorsports_rounded,
        VehicleMapIcon.scooter => Icons.electric_scooter_rounded,
        VehicleMapIcon.car => Icons.directions_car_outlined,
        VehicleMapIcon.carFilled => Icons.directions_car_filled_rounded,
        VehicleMapIcon.van => Icons.airport_shuttle_rounded,
        VehicleMapIcon.truck => Icons.local_shipping_rounded,
      };
}

/// Paleta de colores para el marcador en el mapa.
abstract final class VehicleMapColors {
  static const List<Color> palette = [
    Color(0xFF1A73E8),
    Color(0xFF0D47A1),
    Color(0xFF00897B),
    Color(0xFF2E7D32),
    Color(0xFFF9A825),
    Color(0xFFEF6C00),
    Color(0xFFC62828),
    Color(0xFF6A1B9A),
    Color(0xFF455A64),
    Color(0xFF212121),
    Color(0xFFEC407A),
    Color(0xFF00ACC1),
  ];

  static Color defaultFor(VehicleMapIcon icon) => switch (icon) {
        VehicleMapIcon.motorcycle ||
        VehicleMapIcon.sportBike ||
        VehicleMapIcon.scooter =>
          const Color(0xFF1A73E8),
        VehicleMapIcon.car ||
        VehicleMapIcon.carFilled ||
        VehicleMapIcon.van =>
          const Color(0xFF00897B),
        VehicleMapIcon.truck => const Color(0xFFEF6C00),
      };

  static String toHex(Color color) {
    final argb = color.toARGB32();
    return '#${argb.toRadixString(16).padLeft(8, '0').substring(2).toUpperCase()}';
  }

  static Color? tryParseHex(String? raw) {
    if (raw == null) {
      return null;
    }
    var hex = raw.trim();
    if (hex.startsWith('#')) {
      hex = hex.substring(1);
    }
    if (hex.length == 6) {
      hex = 'FF$hex';
    }
    if (hex.length != 8) {
      return null;
    }
    final value = int.tryParse(hex, radix: 16);
    if (value == null) {
      return null;
    }
    return Color(value);
  }
}

/// Estilo del puck en HUD (`null` = círculo azul por defecto).
class NavigationPuckStyle {
  const NavigationPuckStyle({
    required this.icon,
    required this.color,
  });

  final VehicleMapIcon icon;
  final Color color;

  @override
  bool operator ==(Object other) =>
      other is NavigationPuckStyle &&
      other.icon == icon &&
      other.color.toARGB32() == color.toARGB32();

  @override
  int get hashCode => Object.hash(icon, color.toARGB32());
}
