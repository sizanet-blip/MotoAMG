import 'dart:convert';
import 'dart:io';

import 'package:hive_flutter/hive_flutter.dart';
import 'package:http/http.dart' as http;
import 'package:moto_amg/core/constants/navigation_constants.dart';
import 'package:moto_amg/core/utils/storage_space.dart';
import 'package:moto_amg/features/navigation/domain/entities/geo_bounds.dart';
import 'package:moto_amg/features/navigation/domain/entities/map_region.dart';
import 'package:moto_amg/features/navigation/domain/exceptions/navigation_exceptions.dart';
import 'package:moto_amg/features/navigation/domain/exceptions/navigation_user_message.dart';
import 'package:moto_amg/features/navigation/domain/repositories/map_region_repository.dart';
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
    final mapsDir = await _mapsDir();
    return NavigationConstants.availableRegions.map((catalog) {
      final cached = _regionFromCache(catalog.id, box);
      final partialBytes = _readPartialBytes(
        mapsDir: mapsDir,
        regionId: catalog.id,
      );
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
        partialBytes: cached != null ? 0 : partialBytes,
      );
    }).toList(growable: false);
  }

  int _readPartialBytes({
    required Directory mapsDir,
    required String regionId,
  }) {
    final partial = File('${_filePathFor(mapsDir, regionId)}.partial');
    if (!partial.existsSync()) {
      return 0;
    }
    final length = partial.lengthSync();
    if (length <= 0) {
      return 0;
    }
    return length;
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
    try {
      return await _downloadRegionImpl(
        regionId,
        onProgress: onProgress,
        isCancelled: isCancelled,
      );
    } on NavigationException {
      rethrow;
    } catch (error) {
      throw NavigationException(navigationUserMessage(error));
    }
  }

  Future<MapRegion> _downloadRegionImpl(
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

    void throwIfCancelled() {
      if (isCancelled?.call() == true) {
        throw const MapRegionDownloadCancelledException();
      }
    }

    if (await target.exists()) {
      final existing = await target.length();
      if (_looksComplete(existing, catalog.sizeBytes)) {
        return _finalizeRegion(
          catalog: catalog,
          target: target,
          sizeBytes: existing,
        );
      }
      await target.delete();
    }

    var offset = _readPartialBytes(mapsDir: mapsDir, regionId: catalog.id);
    if (offset > 0 && _looksComplete(offset, catalog.sizeBytes)) {
      if (await target.exists()) {
        await target.delete();
      }
      await temp.rename(target.path);
      return _finalizeRegion(
        catalog: catalog,
        target: target,
        sizeBytes: offset,
      );
    }

    final bytesStillNeeded = (catalog.sizeBytes - offset).clamp(0, catalog.sizeBytes);
    await _ensureFreeSpace(
      bytesNeeded: bytesStillNeeded + mapDownloadSpaceBufferBytes,
      directoryPath: mapsDir.path,
    );

    onProgress?.call(offset, catalog.sizeBytes);

    var retriedWithoutRange = false;
    while (true) {
      throwIfCancelled();

      final request = http.Request('GET', Uri.parse(catalog.url));
      if (offset > 0 && !retriedWithoutRange) {
        request.headers['Range'] = 'bytes=$offset-';
      }

      final response = await _client.send(request).timeout(
            const Duration(minutes: 30),
          );

      if (response.statusCode == 404 || response.statusCode == 403) {
        throw const MapRegionDownloadException(
          NavigationUserMessages.mapNotOnServer,
        );
      }

      if (response.statusCode == 416) {
        final current = await temp.length();
        if (_looksComplete(current, catalog.sizeBytes)) {
          offset = current;
          break;
        }
        await temp.delete();
        offset = 0;
        retriedWithoutRange = false;
        continue;
      }

      if (offset > 0 && response.statusCode == 200) {
        await temp.delete();
        offset = 0;
        retriedWithoutRange = true;
        onProgress?.call(0, catalog.sizeBytes);
        continue;
      }

      if (response.statusCode != 200 && response.statusCode != 206) {
        throw const MapRegionDownloadException(
          NavigationUserMessages.mapDownloadFailed,
        );
      }

      var received = offset;
      final sink = temp.openWrite(
        mode: offset > 0 ? FileMode.append : FileMode.write,
      );
      try {
        await for (final chunk in response.stream) {
          throwIfCancelled();
          sink.add(chunk);
          received += chunk.length;
          onProgress?.call(received, catalog.sizeBytes);
        }
      } finally {
        await sink.close();
      }

      throwIfCancelled();
      offset = received;
      break;
    }

    if (!_looksComplete(offset, catalog.sizeBytes)) {
      throw const MapRegionDownloadException(
        NavigationUserMessages.mapIncomplete,
      );
    }

    if (await target.exists()) {
      await target.delete();
    }
    if (await temp.exists()) {
      await temp.rename(target.path);
    }

    return _finalizeRegion(
      catalog: catalog,
      target: target,
      sizeBytes: offset,
    );
  }

  Future<void> _ensureFreeSpace({
    required int bytesNeeded,
    required String directoryPath,
  }) async {
    final freeBytes = await readFreeBytesForPath(directoryPath);
    if (freeBytes == null) {
      return;
    }
    if (freeBytes < bytesNeeded) {
      throw MapRegionDownloadException(
        formatMapInsufficientSpace(
          neededBytes: bytesNeeded,
          freeBytes: freeBytes,
        ),
      );
    }
  }

  Future<MapRegion> _finalizeRegion({
    required ({
      String id,
      String name,
      String url,
      int sizeBytes,
      double west,
      double south,
      double east,
      double north,
    }) catalog,
    required File target,
    required int sizeBytes,
  }) async {
    final region = MapRegion(
      id: catalog.id,
      name: catalog.name,
      downloadUrl: catalog.url,
      sizeBytes: sizeBytes > 0 ? sizeBytes : catalog.sizeBytes,
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
