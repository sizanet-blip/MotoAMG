import 'package:moto_amg/features/groups/domain/entities/group_voice_announcement.dart';
import 'package:moto_amg/features/tracking/data/datasources/gps_ws_location_datasource.dart';

/// Anuncios de voz efímeros del pelotón vía WebSocket GPS.
class GroupVoiceRemoteDataSource {
  GroupVoiceRemoteDataSource(this._gps);

  final GpsWsLocationDataSource _gps;

  Future<void> publish({
    required String groupId,
    required GroupVoiceAnnouncement announcement,
    Duration ttl = const Duration(seconds: 60),
  }) {
    return _gps.publishVoice(
      groupId: groupId,
      announcement: announcement,
    );
  }

  Stream<List<GroupVoiceAnnouncement>> watchGroup(String groupId) {
    return _gps.watchVoice(groupId);
  }
}
