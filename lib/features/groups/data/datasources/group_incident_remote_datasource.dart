import 'package:moto_amg/features/groups/domain/entities/group_incident.dart';
import 'package:moto_amg/features/tracking/data/datasources/gps_ws_location_datasource.dart';

/// Avisos del pelotón vía el mismo WebSocket GPS (Redis en el VPS).
class GroupIncidentRemoteDataSource {
  GroupIncidentRemoteDataSource(this._gps);

  final GpsWsLocationDataSource _gps;

  Future<void> publish(String groupId, GroupIncident incident) {
    return _gps.publishIncident(groupId, incident);
  }

  Future<void> clear({
    required String groupId,
    required String uid,
  }) {
    return _gps.clearIncident(groupId: groupId, uid: uid);
  }

  Stream<List<GroupIncident>> watchGroup(String groupId) {
    return _gps.watchIncidents(groupId);
  }
}
