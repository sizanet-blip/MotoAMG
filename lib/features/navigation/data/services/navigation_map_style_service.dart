import 'dart:convert';

import 'package:flutter/services.dart';
import 'package:loc_motos/core/constants/navigation_constants.dart';
import 'package:loc_motos/features/navigation/data/services/map_basemap_assets_service.dart';

/// Resuelve qué estilo MapLibre usar en navegación (online vs PMTiles local).
abstract final class NavigationMapStyleService {
  /// OpenFreeMap: mapa vectorial pulido (requiere internet).
  static String onlineStyle() => NavigationConstants.onlineNavigationStyleUrl;

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

  static String defaultStyle() => onlineStyle();

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
    final layers = allLayers.where((layer) {
      final map = layer as Map<String, dynamic>;
      final id = map['id'] as String? ?? '';
      return !id.contains('building');
    }).toList();

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
}
