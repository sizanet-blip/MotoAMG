/// Configuración del módulo de navegación GPS híbrida.
abstract final class NavigationConstants {
  /// URL base del servidor Valhalla (sin barra final).
  /// Vacío = modo demo sin servidor.
  static const String valhallaBaseUrl = 'https://valhalla.albertomaestre.es';

  /// URL base del servidor Photon (sin barra final).
  /// Vacío = usar Nominatim público como fallback.
  static const String photonBaseUrl = 'https://photon.albertomaestre.es';

  /// Idioma de respuestas Photon. Este servidor admite: default, de, en, fr.
  /// `default` usa los nombres OSM (mejor para España que forzar inglés).
  static const String photonLanguage = 'default';

  /// Timeout para peticiones de ruta (rutas largas pueden tardar varios segundos).
  static const Duration valhallaRequestTimeout = Duration(seconds: 45);

  /// Timeout Overpass (consultas POI en ruta).
  static const Duration overpassRequestTimeout = Duration(seconds: 25);

  /// Timeout descarga inventario de radares desde el servidor LocMotos.
  static const Duration spainRadarBundleTimeout = Duration(seconds: 90);

  /// Timeout fallback DGT/SCT directo (si no hay bundle en caché).
  static const Duration spainRadarRequestTimeout = Duration(seconds: 45);

  /// Mientras la app está abierta: no volver a pedir red antes de esto.
  static const Duration spainRadarCacheTtl = Duration(hours: 12);

  /// Caché en disco: se usa sin red; se refresca al caducar si hay cobertura.
  static const Duration spainRadarDiskMaxAge = Duration(days: 14);

  static const String spainRadarBox = 'navigation_spain_radars';
  static const String spainRadarInventoryKey = 'official_inventory_v1';
  static const String spainRadarFetchedAtKey = 'official_fetched_at_v1';
  static const String spainOsmRadarInventoryKey = 'osm_inventory_v1';
  static const String spainOsmRadarFetchedAtKey = 'osm_fetched_at_v1';

  /// Inventario unificado generado en el servidor (DGT+SCT+OSM).
  /// Ver `deploy/radares/build_es_json.py`.
  static const String spainRadarBundleUrl =
      '$valhallaBaseUrl/radares/es.json';

  /// Inventario MITECO de gasolineras (precios). Ver `deploy/gasolineras/`.
  static const String spainFuelBundleUrl =
      '$valhallaBaseUrl/gasolineras/es.json';

  static const String spainFuelBox = 'navigation_spain_fuel';
  static const String spainFuelInventoryKey = 'fuel_inventory_v1';
  static const String spainFuelFetchedAtKey = 'fuel_fetched_at_v1';
  static const Duration spainFuelBundleTimeout = Duration(seconds: 90);
  static const Duration spainFuelDiskMaxAge = Duration(days: 7);

  /// Endpoint Overpass público (legacy POI; gasolineras usan bundle MITECO).
  static const String overpassInterpreterUrl =
      'https://overpass-api.de/api/interpreter';

  /// Inventario DATEX II de radares fijos/tramo DGT (excepto CAT y Euskadi).
  /// Fuente: https://nap.dgt.es/dataset/radares-fijos-dgt
  /// HTTPS obligatorio en Android (cleartext HTTP bloqueado por defecto).
  /// Fallback si no hay caché del bundle del servidor.
  static const String dgtRadaresDatexUrl =
      'https://infocar.dgt.es/datex2/dgt/PredefinedLocationsPublication/radares/content.xml';

  /// Distancia para no duplicar un radar OSM si ya hay uno oficial cerca.
  static const double radarDedupeMeters = 100;

  /// Coordenadas UTM (ETRS89 zona 31N) de cinemómetros fijos SCT.
  static const String sctRadaresFijosUrl =
      'https://transit.gencat.cat/web/.content/documents/seguretat_viaria/radars.txt';

  /// Cinemómetros en remolc SCT (mismo formato UTM).
  static const String sctRadaresRemolcUrl =
      'https://transit.gencat.cat/web/.content/documents/seguretat_viaria/radars-remolc.txt';

  /// Buffer lateral para buscar gasolineras/radares (metros).
  static const double routePoiBufferMeters = 400;

  /// Muestreo de la ruta para bboxes Overpass (metros entre anclas).
  static const double overpassSampleEveryMeters = 25000;

  /// Ventana de detección de curvas fuertes (metros).
  static const double sharpCurveWindowMeters = 120;

  /// Cambio de rumbo acumulado (grados) para marcar curva fuerte.
  static const double sharpCurveMinBearingDeltaDeg = 55;

  /// Separación mínima entre avisos de curva (metros).
  static const double sharpCurveMinSeparationMeters = 400;

  /// Límite de distancia del costing motorcycle en Valhalla (metros).
  /// Si el itinerario lo supera, el servidor puede rechazar la ruta.
  static const double valhallaMotorcycleMaxDistanceMeters = 1500000;

  /// Distancia a la que se anuncia un aviso por voz (metros).
  static const double alertAnnounceMeters = 350;

  /// Aviso de gasolinera en HUD (más lejos que radar; no es urgente).
  static const double fuelAnnounceMeters = 1200;

  /// Segunda voz de radar al estar muy cerca (metros).
  static const double radarImminentAnnounceMeters = 90;

  /// Tras anunciar, no repetir hasta pasar el punto (+ gracia).
  static const double alertPassedGraceMeters = 40;

  /// Tráfico TomTom: descartado por ahora. Ver `deploy/traffic-tomtom-phase2.md`.

  /// Perfil de costing para motos en asfalto.
  static const String valhallaCosting = 'motorcycle';

  /// Selección explícita «Sin vehículo» en el planificador.
  /// Distingue de `null` (= aún no elegido → usar vehículo activo).
  static const String navigationNoVehicleId = '__none__';

  /// Umbral de desvío (metros) antes de avisar al usuario.
  static const double deviationThresholdMeters = 80;

  /// Distancia al destino para considerar llegada (metros).
  static const double arrivalThresholdMeters = 40;

  /// No dar por llegada si aún queda más que esto a lo largo de la ruta
  /// (evita falsos positivos si el trazado pasa cerca del destino antes).
  static const double arrivalMaxAlongRemainingMeters = 120;

  /// Distancia a la que se anuncia por voz la próxima maniobra (metros).
  static const double maneuverAnnounceMeters = 280;

  /// Espera confirmando el desvío antes de pedir una ruta nueva (evita parpadeos).
  static const Duration rerouteDebounce = Duration(seconds: 2);

  /// Mínimo entre intentos de recálculo (éxito o fallo).
  static const Duration rerouteCooldown = Duration(seconds: 15);

  /// Tras pasar el punto del giro, metros de gracia antes de saltar al siguiente aviso.
  static const double maneuverPassedThresholdMeters = 20;

  /// Tras recorrer esto en un giro, el cartel pasa a "Continúa por…".
  /// (Reservado / compat; el modelo Waze usa [maneuverPassedThresholdMeters].)
  static const double maneuverTurnCompleteMeters = 35;

  /// @Deprecated — el guidance Waze ya no anticipa el cambio a 120 m.
  static const double maneuverAdvanceMeters = 25;

  /// Simulación de recorrido (pruebas en casa): ~60 km/h.
  static const double simulationSpeedMps = 16.7;

  /// Velocidad GPS real a partir de la cual se oculta el botón Simular (~7 km/h).
  static const double hideSimulatorSpeedMps = 2.0;

  /// Intervalo entre ticks del simulador.
  static const Duration simulationTickInterval = Duration(milliseconds: 500);

  /// Cámara 3D: inclinación suave (legible en movimiento).
  static const double defaultMapPitch = 35;

  /// Zoom base en ciudad / baja velocidad.
  static const double defaultNavigationZoom = 17.5;

  /// Zoom según velocidad (más lejos en carretera).
  static double navigationZoomForSpeedMps(double speedMps) {
    final kmh = speedMps * 3.6;
    if (kmh < 25) {
      return 17.8;
    }
    if (kmh < 45) {
      return 17.2;
    }
    if (kmh < 70) {
      return 16.5;
    }
    if (kmh < 100) {
      return 15.7;
    }
    return 15.1;
  }

  /// Metros por delante para sesgar un poco la cámara en curvas.
  static const double cameraLookAheadMeters = 95;

  /// Extra de inclinación (grados) al anticipar una curva en 3D.
  static const double cameraLookAheadPitchBoost = 12;

  /// Fundido día↔noche (ida y vuelta del velo).
  static const Duration mapStyleCrossfadeIn = Duration(milliseconds: 280);
  static const Duration mapStyleCrossfadeOut = Duration(milliseconds: 340);

  /// Banner maniobra: urgencia visual.
  static const double maneuverApproachingMeters = 420;
  static const double maneuverImminentMeters = 75;

  /// Accuracy GPS por encima → aviso “señal baja”.
  static const double weakGpsAccuracyMeters = 45;

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

  /// Espera antes de buscar mientras el usuario escribe (Photon propio).
  static const Duration geocodingSearchDebounce = Duration(milliseconds: 280);

  /// Timeout de una búsqueda de direcciones.
  static const Duration geocodingRequestTimeout = Duration(seconds: 8);

  /// Entradas en caché de búsquedas recientes.
  static const int geocodingCacheMaxEntries = 40;

  static const String mapRegionsBox = 'navigation_map_regions';

  static const String recentPlacesBox = 'navigation_recent_places';
  static const String recentPlacesKey = 'items';
  static const int recentPlacesMaxEntries = 8;

  static const String favoritePlacesBox = 'navigation_favorite_places';
  static const String favoritePlacesKey = 'items';
  static const int favoritePlacesMaxEntries = 30;

  static const String routePreferencesBox = 'navigation_route_preferences';
  static const String routePreferencesKey = 'prefs';

  static const String alertPreferencesBox = 'navigation_alert_preferences';
  static const String alertPreferencesKey = 'prefs_v1';

  static const String mapAppearanceBox = 'navigation_map_appearance';
  static const String mapAppearanceKey = 'mode_v1';

  static const String hudSafetyBox = 'navigation_hud_safety';
  static const String hudSafetyKey = 'prefs_v1';

  /// Estilo online nocturno (OpenFreeMap Fiord: oscuro suave, legible en ruta).
  /// Evitamos "Dark" puro: queda casi negro y poco útil para navegar.
  static const String onlineNavigationStyleDarkUrl =
      'https://tiles.openfreemap.org/styles/fiord';

  /// Distancia HUD por defecto para peajes (metros).
  static const double tollAnnounceMeters = 800;

  /// Regiones PMTiles descargables (hospedadas en Valhalla).
  /// Bounds = caja WGS84 aproximada del extract. Local: maps/offline/*.pmtiles
  static const availableRegions = <
      ({
        String id,
        String name,
        String url,
        int sizeBytes,
        double west,
        double south,
        double east,
        double north,
      })>[
    (
      id: 'andalucia',
      name: 'Andalucía',
      url: 'https://valhalla.albertomaestre.es/maps/andalucia.pmtiles',
      sizeBytes: 349748348,
      west: -7.55,
      south: 35.9,
      east: -1.6,
      north: 38.75,
    ),
    (
      id: 'aragon',
      name: 'Aragón',
      url: 'https://valhalla.albertomaestre.es/maps/aragon.pmtiles',
      sizeBytes: 369139867,
      west: -2.25,
      south: 39.8,
      east: 0.85,
      north: 42.98,
    ),
    (
      id: 'asturias',
      name: 'Asturias',
      url: 'https://valhalla.albertomaestre.es/maps/asturias.pmtiles',
      sizeBytes: 79359087,
      west: -7.2,
      south: 42.85,
      east: -4.5,
      north: 43.7,
    ),
    (
      id: 'baleares',
      name: 'Illes Balears',
      url: 'https://valhalla.albertomaestre.es/maps/baleares.pmtiles',
      sizeBytes: 52582606,
      west: 1.15,
      south: 38.6,
      east: 4.4,
      north: 40.15,
    ),
    (
      id: 'canarias',
      name: 'Canarias',
      url: 'https://valhalla.albertomaestre.es/maps/canarias.pmtiles',
      sizeBytes: 62085481,
      west: -18.2,
      south: 27.6,
      east: -13.3,
      north: 29.5,
    ),
    (
      id: 'cantabria',
      name: 'Cantabria',
      url: 'https://valhalla.albertomaestre.es/maps/cantabria.pmtiles',
      sizeBytes: 85560117,
      west: -4.85,
      south: 42.75,
      east: -3.15,
      north: 43.55,
    ),
    (
      id: 'castilla-la-mancha',
      name: 'Castilla-La Mancha',
      url: 'https://valhalla.albertomaestre.es/maps/castilla-la-mancha.pmtiles',
      sizeBytes: 447181476,
      west: -5.5,
      south: 38.0,
      east: -0.8,
      north: 41.35,
    ),
    (
      id: 'castilla-leon',
      name: 'Castilla y León',
      url: 'https://valhalla.albertomaestre.es/maps/castilla-leon.pmtiles',
      sizeBytes: 665899695,
      west: -7.1,
      south: 40.2,
      east: -1.7,
      north: 43.3,
    ),
    (
      id: 'cataluna',
      name: 'Cataluña',
      url: 'https://valhalla.albertomaestre.es/maps/cataluna.pmtiles',
      sizeBytes: 394538220,
      west: 0.15,
      south: 40.5,
      east: 3.35,
      north: 42.9,
    ),
    (
      id: 'ceuta',
      name: 'Ceuta',
      url: 'https://valhalla.albertomaestre.es/maps/ceuta.pmtiles',
      sizeBytes: 1454005,
      west: -5.4,
      south: 35.85,
      east: -5.25,
      north: 35.92,
    ),
    (
      id: 'extremadura',
      name: 'Extremadura',
      url: 'https://valhalla.albertomaestre.es/maps/extremadura.pmtiles',
      sizeBytes: 160075511,
      west: -7.55,
      south: 37.9,
      east: -4.65,
      north: 40.5,
    ),
    (
      id: 'galicia',
      name: 'Galicia',
      url: 'https://valhalla.albertomaestre.es/maps/galicia.pmtiles',
      sizeBytes: 219241639,
      west: -9.35,
      south: 41.8,
      east: -6.7,
      north: 43.8,
    ),
    (
      id: 'la-rioja',
      name: 'La Rioja',
      url: 'https://valhalla.albertomaestre.es/maps/la-rioja.pmtiles',
      sizeBytes: 44393166,
      west: -3.15,
      south: 41.9,
      east: -1.7,
      north: 42.65,
    ),
    (
      id: 'madrid',
      name: 'Comunidad de Madrid',
      url: 'https://valhalla.albertomaestre.es/maps/madrid.pmtiles',
      sizeBytes: 124663298,
      west: -4.6,
      south: 39.85,
      east: -3.05,
      north: 41.2,
    ),
    (
      id: 'melilla',
      name: 'Melilla',
      url: 'https://valhalla.albertomaestre.es/maps/melilla.pmtiles',
      sizeBytes: 1550121,
      west: -2.98,
      south: 35.26,
      east: -2.9,
      north: 35.34,
    ),
    (
      id: 'murcia',
      name: 'Región de Murcia',
      url: 'https://valhalla.albertomaestre.es/maps/murcia.pmtiles',
      sizeBytes: 103714319,
      west: -2.35,
      south: 37.35,
      east: -0.65,
      north: 38.85,
    ),
    (
      id: 'navarra',
      name: 'Navarra',
      url: 'https://valhalla.albertomaestre.es/maps/navarra.pmtiles',
      sizeBytes: 142661885,
      west: -2.5,
      south: 41.9,
      east: -0.7,
      north: 43.35,
    ),
    (
      id: 'pais-vasco',
      name: 'País Vasco',
      url: 'https://valhalla.albertomaestre.es/maps/pais-vasco.pmtiles',
      sizeBytes: 149973514,
      west: -3.45,
      south: 42.45,
      east: -1.7,
      north: 43.5,
    ),
    (
      id: 'valencia',
      name: 'Comunidad Valenciana',
      url: 'https://valhalla.albertomaestre.es/maps/valencia.pmtiles',
      sizeBytes: 223557006,
      west: -1.55,
      south: 37.85,
      east: 0.7,
      north: 40.8,
    ),
  ];
}
