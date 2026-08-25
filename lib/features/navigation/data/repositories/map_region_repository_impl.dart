import 'dart:convert';
import 'dart:io';

import 'package:hive_flutter/hive_flutter.dart';
import 'package:http/http.dart' as http;
import 'package:loc_motos/core/constants/navigation_constants.dart';
import 'package:loc_motos/features/navigation/domain/entities/geo_bounds.dart';
import 'package:loc_motos/features/navigation/domain/entities/map_region.dart';
import 'package:loc_motos/features/navigation/domain/exceptions/navigation_exceptions.dart';
import 'package:loc_motos/features/navigation/domain/exceptions/navigation_user_message.dart';
import 'package:loc_motos/features/navigation/domain/repositories/map_region_repository.dart';
import 'package:path_provider/path_provider.dart';

/// Descarga y almacena regiones `.pmtiles` en el almacenamiento de la app.
class MapRegionRepositoryImpl implements MapRegionRepository {
  MapRegionRepositoryImpl({http.Client? client})
      : _client = client ?? http.Client();

  final http.Client _client;
  Box<String>? _box;

  /// Si el archivo local es menor que este % del tamaño de catálogo → incompleto.
  static const _minCompleteRatio = 0.85;

  Future<Box<String>> _openBox() async {
    _box ??= await Hive.openBox<String>(NavigationConstants.mapRegionsBox);
    return _box!;
  }

  Future<Directory> _mapsDir() async {
    final root = await getApplicationSupportDirectory();
    final dir = Directory('${root.path}/maps');
    if (!await dir.exists()) {
      await dir.create(recursive: true);
    }
    return dir;
  }

  String _filePathFor(Directory mapsDir, String regionId) =>
      '${mapsDir.path}${Platform.pathSeparator}$regionId.pmtiles';

  GeoBounds _boundsForCatalog(String regionId) {
    final catalog = NavigationConstants.availableRegions
        .where((region) => region.id == regionId)
        .firstOrNull;
    if (catalog == null) {
      return const GeoBounds(west: 0, south: 0, east: 0, north: 0);
    }
    return GeoBounds(
      west: catalog.west,
      south: catalog.south,
      east: catalog.east,
      north: catalog.north,
    );
  }

  bool _looksComplete(int localBytes, int catalogBytes) {
    if (catalogBytes <= 0) {
      return localBytes > 0;
    }
    return localBytes >= catalogBytes * _minCompleteRatio;
  }

  MapRegion? _regionFromCache(String regionId, Box<String> box) {
    final raw = box.get(regionId);
    if (raw == null) {
      return null;
    }
    try {
      final json = jsonDecode(raw) as Map<String, dynamic>;
      final path = json['localPath'] as String?;
      if (path == null) {
        return null;
      }
      final file = File(path);
      if (!file.existsSync()) {
        return null;
      }
      final catalog = NavigationConstants.availableRegions
          .where((region) => region.id == regionId)
          .firstOrNull;
      final localSize = file.lengthSync();
      final expected =
          (json['sizeBytes'] as num?)?.toInt() ?? catalog?.sizeBytes ?? 0;
      if (!_looksComplete(localSize, expected)) {
        return null;
      }
      return MapRegion(
        id: regionId,
        name: json['name'] as String? ?? regionId,
        downloadUrl: json['downloadUrl'] as String? ?? '',
        sizeBytes: localSize > 0 ? localSize : expected,
        bounds: _boundsForCatalog(regionId),
        localPath: path,
        isDownloaded: true,
      );
    } catch (_) {
      return null;
    }
  }

  @override
  Future<List<MapRegion>> listAvailableRegions() async {
    final box = await _openBox();
    return NavigationConstants.availableRegions.map((catalog) {
      final cached = _regionFromCache(catalog.id, box);
      return MapRegion(
        id: catalog.id,
        name: catalog.name,
        downloadUrl: catalog.url,
        sizeBytes: catalog.sizeBytes,
        bounds: GeoBounds(
          west: catalog.west,
          south: catalog.south,
          east: catalog.east,
          north: catalog.north,
        ),
        isDownloaded: cached != null,
        localPath: cached?.localPath,
      );
    }).toList(growable: false);
  }

  @override
  Future<MapRegion?> getDownloadedRegion(String regionId) async {
    final box = await _openBox();
    return _regionFromCache(regionId, box);
  }

  @override
  Future<MapRegion> downloadRegion(
    String regionId, {
    void Function(int receivedBytes, int? totalBytes)? onProgress,
    bool Function()? isCancelled,
  }) async {
    final catalog = NavigationConstants.availableRegions
        .where((region) => region.id == regionId)
        .firstOrNull;
    if (catalog == null) {
      throw const NavigationException('Esa región no está disponible.');
    }

    final mapsDir = await _mapsDir();
    final target = File(_filePathFor(mapsDir, catalog.id));
    final temp = File('${target.path}.partial');
    if (await temp.exists()) {
      await temp.delete();
    }

    void throwIfCancelled() {
      if (isCancelled?.call() == true) {
        throw const MapRegionDownloadCancelledException();
      }
    }

    try {
      throwIfCancelled();
      final request = http.Request('GET', Uri.parse(catalog.url));
      final response = await _client.send(request).timeout(
            const Duration(minutes: 30),
          );
      if (response.statusCode == 404 || response.statusCode == 403) {
        throw const MapRegionDownloadException(
          NavigationUserMessages.mapNotOnServer,
        );
      }
      if (response.statusCode < 200 || response.statusCode >= 300) {
        throw const MapRegionDownloadException(
          NavigationUserMessages.mapDownloadFailed,
        );
      }

      final total = response.contentLength ?? catalog.sizeBytes;
      var received = 0;
      final sink = temp.openWrite();
      try {
        await for (final chunk in response.stream) {
          throwIfCancelled();
          sink.add(chunk);
          received += chunk.length;
          onProgress?.call(received, total > 0 ? total : null);
        }
      } finally {
        await sink.close();
      }

      throwIfCancelled();

      if (!_looksComplete(received, catalog.sizeBytes) &&
          (response.contentLength == null ||
              !_looksComplete(received, response.contentLength!))) {
        throw const MapRegionDownloadException(
          NavigationUserMessages.mapIncomplete,
        );
      }

      if (await target.exists()) {
        await target.delete();
      }
      await temp.rename(target.path);

      final region = MapRegion(
        id: catalog.id,
        name: catalog.name,
        downloadUrl: catalog.url,
        sizeBytes: received > 0 ? received : catalog.sizeBytes,
        bounds: GeoBounds(
          west: catalog.west,
          south: catalog.south,
          east: catalog.east,
          north: catalog.north,
        ),
        localPath: target.path,
        isDownloaded: true,
      );
      final box = await _openBox();
      await box.put(
        catalog.id,
        jsonEncode({
          'name': region.name,
          'downloadUrl': region.downloadUrl,
          'sizeBytes': region.sizeBytes,
          'localPath': region.localPath,
        }),
      );
      return region;
    } on NavigationException {
      if (await temp.exists()) {
        await temp.delete();
      }
      rethrow;
    } catch (error) {
      if (await temp.exists()) {
        await temp.delete();
      }
      throw NavigationException(navigationUserMessage(error));
    }
  }

  @override
  Future<void> deleteRegion(String regionId) async {
    final box = await _openBox();
    final cached = _regionFromCache(regionId, box);
    final path = cached?.localPath ??
        _filePathFor(await _mapsDir(), regionId);
    final file = File(path);
    if (await file.exists()) {
      await file.delete();
    }
    final partial = File('$path.partial');
    if (await partial.exists()) {
      await partial.delete();
    }
    await box.delete(regionId);
  }
}
