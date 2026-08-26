import 'package:equatable/equatable.dart';
import 'package:loc_motos/features/auth/domain/entities/vehicle_map_marker.dart';

/// Tipo de vehículo para costing Valhalla.
enum VehicleKind {
  motorcycle,
  auto,
  truck,
}

extension VehicleKindX on VehicleKind {
  String get label => switch (this) {
        VehicleKind.motorcycle => 'Moto',
        VehicleKind.auto => 'Coche',
        VehicleKind.truck => 'Camión',
      };

  /// Perfil Valhalla (`costing`).
  String get valhallaCosting => switch (this) {
        VehicleKind.motorcycle => 'motorcycle',
        VehicleKind.auto => 'auto',
        VehicleKind.truck => 'truck',
      };

  List<VehicleMapIcon> get suggestedMapIcons => switch (this) {
        VehicleKind.motorcycle => const [
            VehicleMapIcon.motorcycle,
            VehicleMapIcon.sportBike,
            VehicleMapIcon.scooter,
          ],
        VehicleKind.auto => const [
            VehicleMapIcon.car,
            VehicleMapIcon.carFilled,
            VehicleMapIcon.van,
          ],
        VehicleKind.truck => const [
            VehicleMapIcon.truck,
            VehicleMapIcon.van,
            VehicleMapIcon.car,
          ],
      };
}

/// Combustible preferido (precios MITECO).
enum VehicleFuelType {
  gasolina95,
  gasolina98,
  gasoleoA,
  gasoleoPremium,
  unspecified,
}

extension VehicleFuelTypeX on VehicleFuelType {
  String get label => switch (this) {
        VehicleFuelType.gasolina95 => 'Gasolina 95',
        VehicleFuelType.gasolina98 => 'Gasolina 98',
        VehicleFuelType.gasoleoA => 'Gasóleo A',
        VehicleFuelType.gasoleoPremium => 'Gasóleo Premium',
        VehicleFuelType.unspecified => 'Sin especificar',
      };

  /// Clave en `prices` del JSON de gasolineras.
  String? get priceKey => switch (this) {
        VehicleFuelType.gasolina95 => 'gasolina95',
        VehicleFuelType.gasolina98 => 'gasolina98',
        VehicleFuelType.gasoleoA => 'gasoleoA',
        VehicleFuelType.gasoleoPremium => 'gasoleoPremium',
        VehicleFuelType.unspecified => null,
      };
}

/// Vehículo del usuario (perfil).
class UserVehicle extends Equatable {
  const UserVehicle({
    required this.id,
    required this.kind,
    this.fuelType = VehicleFuelType.unspecified,
    this.brand,
    this.model,
    this.year,
    this.color,
    this.plate,
    this.mapIcon,
    this.mapColorHex,
  });

  final String id;
  final VehicleKind kind;
  final VehicleFuelType fuelType;
  final String? brand;
  final String? model;
  final String? year;

  /// Color descriptivo (texto libre del perfil).
  final String? color;
  final String? plate;

  /// Icono del marcador GPS en navegación (`null` = puck por defecto).
  final VehicleMapIcon? mapIcon;

  /// Color del marcador (`#RRGGBB`). Si hay icono y no hay color, se usa el default.
  final String? mapColorHex;

  String get displayLabel {
    final parts = [
      brand,
      model,
    ].where((v) => v != null && v.trim().isNotEmpty).map((v) => v!.trim());
    if (parts.isEmpty) {
      return kind.label;
    }
    return parts.join(' ');
  }

  NavigationPuckStyle? get navigationPuckStyle {
    final icon = mapIcon;
    if (icon == null) {
      return null;
    }
    final color =
        VehicleMapColors.tryParseHex(mapColorHex) ??
        VehicleMapColors.defaultFor(icon);
    return NavigationPuckStyle(icon: icon, color: color);
  }

  UserVehicle copyWith({
    String? id,
    VehicleKind? kind,
    VehicleFuelType? fuelType,
    String? brand,
    String? model,
    String? year,
    String? color,
    String? plate,
    VehicleMapIcon? mapIcon,
    String? mapColorHex,
    bool clearMapIcon = false,
    bool clearMapColor = false,
  }) {
    return UserVehicle(
      id: id ?? this.id,
      kind: kind ?? this.kind,
      fuelType: fuelType ?? this.fuelType,
      brand: brand ?? this.brand,
      model: model ?? this.model,
      year: year ?? this.year,
      color: color ?? this.color,
      plate: plate ?? this.plate,
      mapIcon: clearMapIcon ? null : (mapIcon ?? this.mapIcon),
      mapColorHex: clearMapColor ? null : (mapColorHex ?? this.mapColorHex),
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'kind': kind.name,
        'fuelType': fuelType.name,
        'brand': brand,
        'model': model,
        'year': year,
        'color': color,
        'plate': plate,
        'mapIcon': mapIcon?.name,
        'mapColorHex': mapColorHex,
      };

  factory UserVehicle.fromJson(Map<String, dynamic> json) {
    final kindName = json['kind'] as String? ?? 'motorcycle';
    final fuelName = json['fuelType'] as String? ?? 'unspecified';
    final iconName = json['mapIcon'] as String?;
    VehicleMapIcon? mapIcon;
    if (iconName != null) {
      for (final icon in VehicleMapIcon.values) {
        if (icon.name == iconName) {
          mapIcon = icon;
          break;
        }
      }
    }
    return UserVehicle(
      id: json['id'] as String? ??
          'v_${DateTime.now().millisecondsSinceEpoch}',
      kind: VehicleKind.values.firstWhere(
        (k) => k.name == kindName,
        orElse: () => VehicleKind.motorcycle,
      ),
      fuelType: VehicleFuelType.values.firstWhere(
        (f) => f.name == fuelName,
        orElse: () => VehicleFuelType.unspecified,
      ),
      brand: json['brand'] as String?,
      model: json['model'] as String?,
      year: json['year'] as String?,
      color: json['color'] as String?,
      plate: json['plate'] as String?,
      mapIcon: mapIcon,
      mapColorHex: json['mapColorHex'] as String?,
    );
  }

  @override
  List<Object?> get props => [
        id,
        kind,
        fuelType,
        brand,
        model,
        year,
        color,
        plate,
        mapIcon,
        mapColorHex,
      ];
}
