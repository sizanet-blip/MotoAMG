/// Límites genéricos DGT (turismo/moto) cuando no hay maxspeed OSM/TomTom.
///
/// Art. 48 RGCir (fuera de poblado) y límites urbanos habituales.
/// No usa 100 en convencionales: ese valor solo aplica si está señalizado.
abstract final class DgtSpeedLimitResolver {
  /// Densidad Valhalla (0–15) a partir de la cual tratamos el tramo como urbano.
  static const urbanDensityThreshold = 8;

  /// Inferencia desde atributos de edge de Valhalla `trace_attributes`.
  static int? fromValhallaEdge(Map<String, dynamic> edge) {
    final unpaved = edge['unpaved'] == true;
    if (unpaved) {
      return 30;
    }

    final use = (edge['use'] as String?)?.toLowerCase();
    if (use != null && _ignoredUses.contains(use)) {
      return null;
    }
    if (use != null && _slowUses.contains(use)) {
      return 30;
    }

    final roadClass = (edge['road_class'] as String?)?.toLowerCase();
    if (roadClass == null || roadClass.isEmpty) {
      return null;
    }

    final density = (edge['density'] as num?)?.toInt() ?? 0;
    final urban = density >= urbanDensityThreshold;

    return switch (roadClass) {
      // Autopista / autovía clara en OSM.
      'motorway' => 120,
      // `trunk` en España mezcla autovía y convencional: sin maxspeed → duda.
      'trunk' => null,
      // Convencional genérica: 90 (no 100).
      'primary' || 'secondary' || 'tertiary' || 'unclassified' =>
        urban ? 50 : 90,
      'residential' || 'service_other' => 30,
      _ => null,
    };
  }

  static const _ignoredUses = {
    'ferry',
    'rail',
    'rail-ferry',
    'tram',
    'bus',
    'footway',
    'sidewalk',
    'steps',
    'cycleway',
    'mountain_bike',
    'egress_connection',
    'platform_connection',
    'transit_connection',
  };

  static const _slowUses = {
    'track',
    'driveway',
    'alley',
    'parking_aisle',
    'emergency_access',
    'drive_through',
    'culdesac',
  };
}
