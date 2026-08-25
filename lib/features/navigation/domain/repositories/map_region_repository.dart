import 'package:loc_motos/features/navigation/domain/entities/map_region.dart';

abstract class MapRegionRepository {
  Future<List<MapRegion>> listAvailableRegions();

  Future<MapRegion> downloadRegion(
    String regionId, {
    void Function(int receivedBytes, int? totalBytes)? onProgress,
    bool Function()? isCancelled,
  });

  Future<MapRegion?> getDownloadedRegion(String regionId);

  Future<void> deleteRegion(String regionId);
}
