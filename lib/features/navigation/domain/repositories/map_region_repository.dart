import 'package:loc_motos/features/navigation/domain/entities/map_region.dart';

abstract class MapRegionRepository {
  Future<List<MapRegion>> listAvailableRegions();

  Future<MapRegion> downloadRegion(String regionId);

  Future<MapRegion?> getDownloadedRegion(String regionId);
}
