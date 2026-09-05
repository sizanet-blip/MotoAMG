import 'package:moto_amg/features/tracking/domain/entities/live_location.dart';

abstract class LocationRepository {
  Stream<List<LiveLocation>> watchGroupLocations(String groupId);

  Future<void> publishLocation(LiveLocation location);

  Future<void> clearLocation({
    required String groupId,
    required String uid,
  });
}
