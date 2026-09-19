import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:moto_amg/features/groups/data/datasources/group_stop_remote_datasource.dart';
import 'package:moto_amg/features/groups/domain/entities/group_stop.dart';
import 'package:moto_amg/features/groups/domain/exceptions/group_exceptions.dart';
import 'package:moto_amg/features/groups/presentation/providers/group_providers.dart';
import 'package:moto_amg/features/navigation/domain/entities/geo_point.dart';

final groupStopServiceProvider = Provider<GroupStopService>((ref) {
  return GroupStopService(ref.watch(groupStopDatasourceProvider));
});

class GroupStopService {
  const GroupStopService(this._remote);

  final GroupStopRemoteDataSource _remote;

  Future<void> publish({
    required String groupId,
    required String uid,
    required String displayName,
    required GroupStopType type,
    required GeoPoint point,
  }) async {
    if (groupId.isEmpty) {
      throw const GroupException('Grupo no válido.');
    }

    await _remote.publish(
      groupId,
      GroupStop(
        id: '',
        type: type,
        point: point,
        at: DateTime.now(),
        createdBy: uid,
        displayName: displayName,
      ),
    );
  }

  Future<void> clear({
    required String groupId,
    required String stopId,
  }) async {
    if (groupId.isEmpty || stopId.isEmpty) {
      return;
    }
    await _remote.clear(groupId: groupId, stopId: stopId);
  }
}
