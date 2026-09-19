import 'package:moto_amg/features/groups/domain/entities/group_stop.dart';
import 'package:moto_amg/features/tracking/data/datasources/gps_ws_location_datasource.dart';

/// Paradas del pelotón vía el mismo WebSocket GPS.
class GroupStopRemoteDataSource {
  GroupStopRemoteDataSource(this._gps);

  final GpsWsLocationDataSource _gps;

  Future<String> publish(String groupId, GroupStop stop) {
    return _gps.publishStop(groupId, stop);
  }

  Future<void> clear({
    required String groupId,
    required String stopId,
  }) {
    return _gps.clearStop(groupId: groupId, stopId: stopId);
  }

  Stream<List<GroupStop>> watchGroup(String groupId) {
    return _gps.watchStops(groupId);
  }
}
