/// Configuración del módulo de navegación GPS híbrida.
abstract final class NavigationConstants {
  /// URL base del servidor Valhalla (sin barra final).
  /// Vacío = modo demo sin servidor.
  static const String valhallaBaseUrl = 'https://valhalla.albertomaestre.es';

  /// URL base del servidor Photon (sin barra final).
  /// Vacío = usar Nominatim público como fallback.
  static const String photonBaseUrl = 'https://photon.albertomaestre.es';

  /// Idioma de respuestas Photon. Este servidor admite: default, de, en, fr.
  static const String photonLanguage = 'en';

  /// Timeout para peticiones de ruta (rutas largas pueden tardar varios segundos).
  static const Duration valhallaRequestTimeout = Duration(seconds: 45);

  /// Perfil de costing para motos en asfalto.
  static const String valhallaCosting = 'motorcycle';

  /// Umbral de desvío (metros) antes de avisar al usuario.
  static const double deviationThresholdMeters = 80;

  /// Distancia para anticipar la siguiente maniobra (metros).
  static const double maneuverAdvanceMeters = 120;

  /// Cámara 3D: inclinación suave (legible en movimiento).
  static const double defaultMapPitch = 35;

  /// Zoom inicial en modo navegación.
  static const double defaultNavigationZoom = 17.5;

  /// Desplaza el centro del mapa para dejar sitio al HUD.
  static const double mapPaddingTop = 148;
  static const double mapPaddingBottom = 112;

  /// Márgenes al encuadrar la ruta en vista previa.
  static const double routePreviewPaddingHorizontal = 48;
  static const double routePreviewPaddingTop = 72;
  static const double routePreviewPaddingBottom = 220;

  static const String routeCacheBox = 'navigation_routes';
  static const String activeRouteKey = 'active_route_id';

  /// Estilo online (OpenFreeMap): calidad profesional con internet.
  static const String onlineNavigationStyleUrl =
      'https://tiles.openfreemap.org/styles/liberty';

  /// Estilo MapLibre empaquetado (PMTiles remoto, fallback / offline).
  static const String navigationStyleAsset = 'assets/maps/navigation_style.json';

  /// PMTiles demo de Protomaps (online). Sustituir por archivo local offline.
  static const String defaultPmtilesUrl =
      'https://demo-bucket.protomaps.com/v4.pmtiles';

  static const String mapGlyphsUrl =
      'https://protomaps.github.io/basemaps-assets/fonts/{fontstack}/{range}.pbf';

  static const String mapSpriteUrl =
      'https://protomaps.github.io/basemaps-assets/sprites/v4/light';

  /// Capas Protomaps light (legibles de día, estilo navegación).
  static const String protomapsNavigationLayersAsset =
      'assets/maps/protomaps_light_layers.json';

  static const String mapAttribution =
      '<a href="https://github.com/protomaps/basemaps">Protomaps</a> '
      '© <a href="https://www.openstreetmap.org/copyright">OpenStreetMap</a>';

  /// Geocodificación de direcciones (OpenStreetMap Nominatim).
  static const String nominatimBaseUrl = 'https://nominatim.openstreetmap.org';
  static const String geocodingUserAgent =
      'LocMotos/1.0 (+https://github.com; contact: app@locmotos.local)';

  /// Nominatim público: máximo ~1 petición/segundo.
  static const Duration geocodingMinRequestInterval = Duration(
    milliseconds: 1100,
  );

  /// Espera antes de buscar mientras el usuario escribe.
  static const Duration geocodingSearchDebounce = Duration(milliseconds: 900);

  /// Entradas en caché de búsquedas recientes.
  static const int geocodingCacheMaxEntries = 40;

  /// Regiones demo disponibles para descarga offline.
  static const availableRegions = <({String id, String name, String url})>[
    (
      id: 'iberia-demo',
      name: 'Península Ibérica (demo)',
      url: 'https://example.com/maps/iberia.pmtiles',
    ),
    (
      id: 'cataluna-demo',
      name: 'Cataluña (demo)',
      url: 'https://example.com/maps/cataluna.pmtiles',
    ),
  ];
}
