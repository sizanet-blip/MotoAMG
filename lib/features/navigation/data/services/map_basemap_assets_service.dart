import 'dart:convert';
import 'dart:io';

import 'package:flutter/services.dart';
import 'package:path_provider/path_provider.dart';

/// Extrae glyphs/sprites empaquetados a disco para MapLibre offline.
abstract final class MapBasemapAssetsService {
  static const _assetPrefix = 'assets/maps/basemaps/';
  static const _version = 'protomaps-basemaps-assets-v4-light-2';

  static Future<MapBasemapAssetPaths>? _pending;

  /// Rutas `file://` listas para el estilo MapLibre.
  static Future<MapBasemapAssetPaths> ensureReady() {
    return _pending ??= _ensureReady();
  }

  static Future<MapBasemapAssetPaths> _ensureReady() async {
    final support = await getApplicationSupportDirectory();
    final root = Directory('${support.path}/map_basemap_assets');
    final stamp = File('${root.path}${Platform.pathSeparator}.version');

    if (await stamp.exists() &&
        (await stamp.readAsString()).trim() == _version &&
        await File(
          '${root.path}${Platform.pathSeparator}sprites${Platform.pathSeparator}v4${Platform.pathSeparator}light.json',
        ).exists()) {
      return MapBasemapAssetPaths.fromRoot(root.path);
    }

    if (await root.exists()) {
      await root.delete(recursive: true);
    }
    await root.create(recursive: true);

    final manifest = await AssetManifest.loadFromAssetBundle(rootBundle);
    final keys = manifest
        .listAssets()
        .where((key) => key.startsWith(_assetPrefix))
        .toList(growable: false);

    for (final key in keys) {
      final relative = key.substring(_assetPrefix.length);
      if (relative.isEmpty) {
        continue;
      }
      // Flutter trata `foo@2x.png` como variante de resolución; en assets
      // usamos `foo_2x.*` y al extraer recuperamos el nombre MapLibre.
      final diskRelative = relative
          .replaceAll('light_2x.png', 'light@2x.png')
          .replaceAll('light_2x.json', 'light@2x.json');
      final out = File(
        '${root.path}${Platform.pathSeparator}${diskRelative.replaceAll('/', Platform.pathSeparator)}',
      );
      await out.parent.create(recursive: true);
      final data = await rootBundle.load(key);
      await out.writeAsBytes(
        data.buffer.asUint8List(data.offsetInBytes, data.lengthInBytes),
        flush: true,
      );
    }

    await stamp.writeAsString(_version, flush: true);
    return MapBasemapAssetPaths.fromRoot(root.path);
  }
}

final class MapBasemapAssetPaths {
  const MapBasemapAssetPaths({
    required this.glyphsUrlTemplate,
    required this.spriteUrl,
  });

  factory MapBasemapAssetPaths.fromRoot(String absoluteRoot) {
    final normalized = absoluteRoot.replaceAll('\\', '/');
    final rootUri = normalized.startsWith('/')
        ? 'file://$normalized'
        : 'file:///$normalized';
    return MapBasemapAssetPaths(
      glyphsUrlTemplate: '$rootUri/fonts/{fontstack}/{range}.pbf',
      spriteUrl: '$rootUri/sprites/v4/light',
    );
  }

  final String glyphsUrlTemplate;
  final String spriteUrl;

  @override
  String toString() => jsonEncode({
        'glyphs': glyphsUrlTemplate,
        'sprite': spriteUrl,
      });
}
