import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:loc_motos/features/groups/data/datasources/group_stop_remote_datasource.dart';
import 'package:loc_motos/features/groups/domain/entities/group_stop.dart';
import 'package:loc_motos/features/groups/domain/exceptions/group_exceptions.dart';
import 'package:loc_motos/features/groups/presentation/providers/group_providers.dart';
import 'package:loc_motos/features/navigation/domain/entities/geo_point.dart';

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
    _ensureSignedIn();
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
    _ensureSignedIn();
    if (groupId.isEmpty || stopId.isEmpty) {
      return;
    }
    await _remote.clear(groupId: groupId, stopId: stopId);
  }

  void _ensureSignedIn() {
    if (FirebaseAuth.instance.currentUser == null) {
      throw const GroupException(
        'No hay sesión activa. Cierra la app y vuelve a entrar.',
      );
    }
  }
}
