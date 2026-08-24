import 'dart:convert';

import 'package:flutter/services.dart';
import 'package:loc_motos/core/constants/navigation_constants.dart';

/// Resuelve qué estilo MapLibre usar en navegación (online vs PMTiles local).
abstract final class NavigationMapStyleService {
  /// OpenFreeMap: mapa vectorial pulido (requiere internet).
  static String onlineStyle() => NavigationConstants.onlineNavigationStyleUrl;

  static String bundledPmtilesStyle() => NavigationConstants.navigationStyleAsset;

  static String defaultStyle() => onlineStyle();

  /// Estilo inline para `.pmtiles` en disco (`pmtiles:///ruta/absoluta`).
  static Future<String> localPmtilesStyle(String absolutePath) async {
    final normalized = absolutePath.replaceAll('\\', '/');
    final pmtilesUrl = normalized.startsWith('pmtiles://')
        ? normalized
        : 'pmtiles://$normalized';
    return buildPmtilesStyle(pmtilesUrl);
  }

  static Future<String> buildPmtilesStyle(String pmtilesUrl) async {
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
      'glyphs': NavigationConstants.mapGlyphsUrl,
      'sprite': NavigationConstants.mapSpriteUrl,
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
