import 'package:equatable/equatable.dart';
import 'package:loc_motos/features/navigation/domain/entities/geo_bounds.dart';

/// Cobertura offline + estilo online para mapas híbridos.
class HybridMapStyles extends Equatable {
  const HybridMapStyles({
    required this.onlineStyle,
    required this.unavailableStyle,
    this.offline = const [],
  });

  final String onlineStyle;
  /// Fondo vacío cuando no hay red ni pack local para ese punto.
  final String unavailableStyle;
  final List<OfflineMapStyle> offline;

  bool get hasOfflineCoverage => offline.isNotEmpty;

  bool covers(double latitude, double longitude) {
    for (final region in offline) {
      if (region.bounds.contains(latitude, longitude)) {
        return true;
      }
    }
    return false;
  }

  /// Estilo según el punto visible y si hay internet.
  String resolve(
    double latitude,
    double longitude, {
    required bool hasNetwork,
  }) {
    for (final region in offline) {
      if (region.bounds.contains(latitude, longitude)) {
        return region.styleString;
      }
    }
    if (hasNetwork) {
      return onlineStyle;
    }
    return unavailableStyle;
  }

  @override
  List<Object?> get props => [onlineStyle, unavailableStyle, offline];
}

class OfflineMapStyle extends Equatable {
  const OfflineMapStyle({
    required this.regionId,
    required this.bounds,
    required this.styleString,
  });

  final String regionId;
  final GeoBounds bounds;
  final String styleString;

  @override
  List<Object?> get props => [regionId, bounds, styleString];
}
