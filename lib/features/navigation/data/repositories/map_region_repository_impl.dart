import 'package:loc_motos/core/constants/navigation_constants.dart';
import 'package:loc_motos/features/navigation/domain/entities/map_region.dart';
import 'package:loc_motos/features/navigation/domain/repositories/map_region_repository.dart';

/// Descarga de regiones .pmtiles (stub: simula descarga local).
class MapRegionRepositoryImpl implements MapRegionRepository {
  final _downloaded = <String, MapRegion>{};

  @override
  Future<List<MapRegion>> listAvailableRegions() async {
    return NavigationConstants.availableRegions
        .map(
          (region) => MapRegion(
            id: region.id,
            name: region.name,
            downloadUrl: region.url,
            sizeBytes: 120 * 1024 * 1024,
            isDownloaded: _downloaded.containsKey(region.id),
            localPath: _downloaded[region.id]?.localPath,
          ),
        )
        .toList();
  }

  @override
  Future<MapRegion> downloadRegion(String regionId) async {
    final catalog = NavigationConstants.availableRegions.firstWhere(
      (region) => region.id == regionId,
      orElse: () => throw StateError('Región desconocida'),
    );
    final downloaded = MapRegion(
      id: catalog.id,
      name: catalog.name,
      downloadUrl: catalog.url,
      sizeBytes: 120 * 1024 * 1024,
      localPath: 'assets/maps/${catalog.id}.pmtiles',
      isDownloaded: true,
    );
    _downloaded[regionId] = downloaded;
    return downloaded;
  }

  @override
  Future<MapRegion?> getDownloadedRegion(String regionId) async {
    return _downloaded[regionId];
  }
}
