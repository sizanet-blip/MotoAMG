import 'dart:convert';

import 'package:flutter/services.dart';
import 'package:http/http.dart' as http;
import 'package:loc_motos/core/constants/navigation_constants.dart';
import 'package:loc_motos/features/navigation/data/services/map_basemap_assets_service.dart';

/// Resuelve qué estilo MapLibre usar en navegación (online vs PMTiles local).
abstract final class NavigationMapStyleService {
  /// Subir al cambiar el parche de etiquetas (invalida caché en memoria).
  static const _onlineStylePatchVersion = 2;

  static String? _cachedOnlineStyleJson;
  static int? _cachedOnlineStyleVersion;

  /// OpenFreeMap Liberty parcheado: refs/nombres de carretera a zoom más bajo.
  /// Si falla la descarga del estilo, cae a la URL remota original.
  static Future<String> onlineStyle() async {
    final cached = _cachedOnlineStyleJson;
    if (cached != null &&
        _cachedOnlineStyleVersion == _onlineStylePatchVersion) {
      return cached;
    }
    try {
      final response = await http
          .get(Uri.parse(NavigationConstants.onlineNavigationStyleUrl))
          .timeout(const Duration(seconds: 15));
      if (response.statusCode != 200) {
        return NavigationConstants.onlineNavigationStyleUrl;
      }
      final decoded = jsonDecode(response.body);
      if (decoded is! Map<String, dynamic>) {
        return NavigationConstants.onlineNavigationStyleUrl;
      }
      _patchOpenFreeMapRoadLabels(decoded);
      final encoded = jsonEncode(decoded);
      _cachedOnlineStyleJson = encoded;
      _cachedOnlineStyleVersion = _onlineStylePatchVersion;
      return encoded;
    } catch (_) {
      return NavigationConstants.onlineNavigationStyleUrl;
    }
  }

  /// Sin teselas: fuera de packs offline y sin red (evita caché engañosa).
  static String unavailableStyle() => jsonEncode({
        'version': 8,
        'sources': <String, dynamic>{},
        'layers': [
          {
            'id': 'background',
            'type': 'background',
            'paint': {'background-color': '#d7d3cb'},
          },
        ],
      });

  static String bundledPmtilesStyle() => NavigationConstants.navigationStyleAsset;

  /// Estilo inline para `.pmtiles` en disco.
  /// MapLibre Native exige: `pmtiles://file:///ruta/absoluta`.
  static Future<String> localPmtilesStyle(String absolutePath) async {
    var path = absolutePath.trim().replaceAll('\\', '/');
    if (path.startsWith('pmtiles://')) {
      path = path.substring('pmtiles://'.length);
    }
    if (!path.startsWith('file://')) {
      // file:///abs/path (tres barras si [path] ya empieza por /).
      path = path.startsWith('/') ? 'file://$path' : 'file:///$path';
    }
    final assets = await MapBasemapAssetsService.ensureReady();
    return buildPmtilesStyle(
      'pmtiles://$path',
      glyphsUrl: assets.glyphsUrlTemplate,
      spriteUrl: assets.spriteUrl,
    );
  }

  static Future<String> buildPmtilesStyle(
    String pmtilesUrl, {
    String? glyphsUrl,
    String? spriteUrl,
  }) async {
    final layersJson = await rootBundle.loadString(
      NavigationConstants.protomapsNavigationLayersAsset,
    );
    final allLayers = jsonDecode(layersJson) as List<dynamic>;
    final layers = <Map<String, dynamic>>[];
    for (final layer in allLayers) {
      final map = Map<String, dynamic>.from(layer as Map);
      final id = map['id'] as String? ?? '';
      if (id.contains('building')) {
        continue;
      }
      if (id == 'roads_labels_major') {
        // Rutas “secundarias”: el fitBounds aleja más; hace falta ver refs antes.
        map['minzoom'] = 6;
      } else if (id == 'roads_labels_minor') {
        map['minzoom'] = 10;
      }
      layers.add(map);
    }
    layers.add(_earlyHighwayRefLayerPmtiles());

    return jsonEncode({
      'version': 8,
      'glyphs': glyphsUrl ?? NavigationConstants.mapGlyphsUrl,
      'sprite': spriteUrl ?? NavigationConstants.mapSpriteUrl,
      'sources': {
        'protomaps': {
          'type': 'vector',
          'url': pmtilesUrl,
          'attribution': NavigationConstants.mapAttribution,
        },
      },
      'layers': layers,
    });
  }

  /// OpenFreeMap: en zoom de itinerario no salían A-23/N-… (nombres desde 12.2
  /// y motorways solo en shields). En “Secundarias” el fitBounds aleja más;
  /// bajamos minzoom y priorizamos `ref` también en terciarias.
  static void _patchOpenFreeMapRoadLabels(Map<String, dynamic> style) {
    final layers = style['layers'];
    if (layers is! List) {
      return;
    }
    for (final raw in layers) {
      if (raw is! Map) {
        continue;
      }
      final layer = raw;
      final id = layer['id'] as String? ?? '';
      switch (id) {
        case 'highway-name-major':
          layer['minzoom'] = 6;
          layer['filter'] = [
            'match',
            ['get', 'class'],
            ['motorway', 'trunk', 'primary', 'secondary', 'tertiary'],
            true,
            false,
          ];
          final layout = Map<String, dynamic>.from(
            (layer['layout'] as Map?) ?? const {},
          );
          layout['text-field'] = [
            'coalesce',
            ['to-string', ['get', 'ref']],
            ['get', 'name'],
            ['get', 'name_en'],
            ['get', 'name:latin'],
          ];
          layout['symbol-spacing'] = 140;
          layout['text-size'] = [
            'interpolate',
            ['linear'],
            ['zoom'],
            6,
            10,
            9,
            12,
            12,
            14,
          ];
          layout['text-optional'] = true;
          layer['layout'] = layout;
        case 'highway-name-minor':
          layer['minzoom'] = 10;
        case 'highway-shield-non-us':
          layer['minzoom'] = 5;
          final layout = Map<String, dynamic>.from(
            (layer['layout'] as Map?) ?? const {},
          );
          layout['symbol-spacing'] = 120;
          layout['text-size'] = 11;
          // En zoom de itinerario (ruta larga) conviene forzar el escudo.
          layout['text-optional'] = false;
          layout['icon-optional'] = false;
          layer['layout'] = layout;
        default:
          break;
      }
    }

    layers.add({
      'id': 'highway-ref-text-early',
      'type': 'symbol',
      'source': 'openmaptiles',
      'source-layer': 'transportation_name',
      'minzoom': 5,
      'maxzoom': 14,
      'filter': [
        'all',
        [
          'match',
          ['geometry-type'],
          ['LineString', 'MultiLineString'],
          true,
          false,
        ],
        ['has', 'ref'],
        [
          'match',
          ['get', 'class'],
          ['motorway', 'trunk', 'primary', 'secondary', 'tertiary'],
          true,
          false,
        ],
      ],
      'layout': {
        'symbol-placement': 'line',
        'symbol-spacing': 140,
        'text-field': ['to-string', ['get', 'ref']],
        'text-font': ['Noto Sans Regular'],
        'text-size': [
          'interpolate',
          ['linear'],
          ['zoom'],
          5,
          10,
          8,
          12,
          11,
          14,
        ],
        'text-max-angle': 35,
        'text-rotation-alignment': 'map',
        'text-pitch-alignment': 'viewport',
        'text-optional': false,
      },
      'paint': {
        'text-color': '#2a2a2a',
        'text-halo-color': '#ffffff',
        'text-halo-width': 1.6,
      },
    });
  }

  static Map<String, dynamic> _earlyHighwayRefLayerPmtiles() {
    return {
      'id': 'roads_ref_early',
      'type': 'symbol',
      'source': 'protomaps',
      'source-layer': 'roads',
      'minzoom': 5,
      'maxzoom': 14,
      'filter': [
        'all',
        [
          'in',
          'kind',
          'highway',
          'major_road',
          'minor_road',
        ],
        ['has', 'ref'],
      ],
      'layout': {
        'symbol-placement': 'line',
        'symbol-spacing': 140,
        'text-field': [
          'coalesce',
          ['get', 'ref'],
          ['get', 'name'],
        ],
        'text-font': ['Noto Sans Regular'],
        'text-size': [
          'interpolate',
          ['linear'],
          ['zoom'],
          5,
          10,
          8,
          12,
          11,
          14,
        ],
        'text-max-angle': 30,
        'text-rotation-alignment': 'map',
        'text-pitch-alignment': 'viewport',
        'text-optional': false,
      },
      'paint': {
        'text-color': '#333333',
        'text-halo-color': '#ffffff',
        'text-halo-width': 1.6,
      },
    };
  }
}
