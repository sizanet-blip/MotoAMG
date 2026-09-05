import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:moto_amg/features/groups/data/datasources/group_incident_remote_datasource.dart';
import 'package:moto_amg/features/groups/domain/entities/group_incident.dart';
import 'package:moto_amg/features/groups/domain/exceptions/group_exceptions.dart';
import 'package:moto_amg/features/groups/presentation/providers/group_providers.dart';
import 'package:moto_amg/features/navigation/domain/entities/geo_point.dart';

final groupIncidentServiceProvider = Provider<GroupIncidentService>((ref) {
  return GroupIncidentService(ref.watch(groupIncidentDatasourceProvider));
});

/// Publicar y quitar avisos del grupo (RTDB), sin pasar por el controlador global.
class GroupIncidentService {
  const GroupIncidentService(this._remote);

  final GroupIncidentRemoteDataSource _remote;

  Future<void> publish({
    required WidgetRef ref,
    required String groupId,
    required String uid,
    required String displayName,
    required GroupIncidentType type,
    required GeoPoint point,
    GroupIncidentSeverity? severity,
  }) async {
    _ensureSignedIn();
    if (groupId.isEmpty) {
      throw const GroupException('Grupo no válido.');
    }

    final existing =
        ref.read(groupIncidentsProvider(groupId)).valueOrNull ??
            const <GroupIncident>[];
    for (final incident in existing) {
      if (incident.uid != uid) {
        continue;
      }
      if (incident.type == GroupIncidentType.emergencia &&
          type != GroupIncidentType.emergencia) {
        throw const GroupException(
          'Tienes una emergencia activa. Cancélala antes o mantén el aviso.',
        );
      }
    }

    await _remote.publish(
      groupId,
      GroupIncident(
        uid: uid,
        type: type,
        point: point,
        at: DateTime.now(),
        severity: type == GroupIncidentType.emergencia
            ? (severity ?? GroupIncidentSeverity.alta)
            : null,
        displayName: displayName,
      ),
    );
  }

  Future<void> clear({
    required String groupId,
    required String uid,
  }) async {
    _ensureSignedIn();
    if (groupId.isEmpty) {
      return;
    }
    await _remote.clear(groupId: groupId, uid: uid);
  }

  void _ensureSignedIn() {
    if (FirebaseAuth.instance.currentUser == null) {
      throw const GroupException(
        'No hay sesión activa. Cierra la app y vuelve a entrar.',
      );
    }
  }
}
