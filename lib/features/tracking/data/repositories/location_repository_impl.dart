import 'package:moto_amg/features/tracking/data/datasources/gps_ws_location_datasource.dart';
import 'package:moto_amg/features/tracking/domain/entities/live_location.dart';
import 'package:moto_amg/features/tracking/domain/repositories/location_repository.dart';

class LocationRepositoryImpl implements LocationRepository {
  LocationRepositoryImpl(this._remote);

  final GpsWsLocationDataSource _remote;

  @override
  Stream<List<LiveLocation>> watchGroupLocations(String groupId) {
    return _remote.watchGroup(groupId);
  }

  @override
  Future<void> publishLocation(LiveLocation location) {
    return _remote.publish(location);
  }

  @override
  Future<void> clearLocation({
    required String groupId,
    required String uid,
  }) {
    return _remote.clear(groupId: groupId, uid: uid);
  }
}
