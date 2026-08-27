import 'package:equatable/equatable.dart';
import 'package:loc_motos/features/navigation/domain/entities/geo_bounds.dart';

/// Cobertura por CCAA (PMTiles) + fallback online fuera de España.
class HybridMapStyles extends Equatable {
  const HybridMapStyles({
    required this.onlineStyle,
    required this.unavailableStyle,
    this.onlineStyleDark,
    this.offline = const [],
  });

  /// Fuera de todas las CCAA (p. ej. Portugal), con red — día.
  final String onlineStyle;

  /// Estilo oscuro online (noche / HUD).
  final String? onlineStyleDark;

  /// Sin red y sin pack local para ese punto.
  final String unavailableStyle;

  /// Una entrada por CCAA: estilo Protomaps (local o remoto).
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

  /// Mismo estilo Protomaps en toda España: archivo local si está descargado,
  /// o PMTiles del servidor si hay red. Fuera de CCAA → [onlineStyle].
  /// Con [preferDark] prioriza variante oscura de la misma familia (no saltar
  /// a Fiord si hay cobertura Protomaps).
  String resolve(
    double latitude,
    double longitude, {
    required bool hasNetwork,
    bool preferDark = false,
  }) {
    for (final region in offline) {
      if (!region.bounds.contains(latitude, longitude)) {
        continue;
      }
      if (!region.requiresNetwork || hasNetwork) {
        if (preferDark) {
          return region.darkStyleString ?? region.styleString;
        }
        return region.styleString;
      }
    }
    if (preferDark && hasNetwork) {
      return onlineStyleDark ?? onlineStyle;
    }
    if (hasNetwork) {
      return onlineStyle;
    }
    return unavailableStyle;
  }

  @override
  List<Object?> get props =>
      [onlineStyle, onlineStyleDark, unavailableStyle, offline];
}

class OfflineMapStyle extends Equatable {
  const OfflineMapStyle({
    required this.regionId,
    required this.bounds,
    required this.styleString,
    this.darkStyleString,
    this.requiresNetwork = false,
  });

  final String regionId;
  final GeoBounds bounds;
  final String styleString;

  /// Variante nocturna (mismo PMTiles, pintura oscura).
  final String? darkStyleString;

  /// `true` = PMTiles por HTTPS (mismo estilo que offline, hace falta red).
  final bool requiresNetwork;

  @override
  List<Object?> get props =>
      [regionId, bounds, styleString, darkStyleString, requiresNetwork];
}
