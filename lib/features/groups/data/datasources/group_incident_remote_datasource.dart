import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_database/firebase_database.dart';
import 'package:loc_motos/core/constants/app_constants.dart';
import 'package:loc_motos/features/groups/domain/entities/group_incident.dart';
import 'package:loc_motos/firebase_options.dart';

class GroupIncidentRemoteDataSource {
  GroupIncidentRemoteDataSource({FirebaseDatabase? database})
      : _database = database ??
            FirebaseDatabase.instanceFor(
              app: Firebase.app(),
              databaseURL: DefaultFirebaseOptions.android.databaseURL,
            );

  final FirebaseDatabase _database;

  DatabaseReference _ref(String groupId, [String? uid]) {
    final base =
        _database.ref('${AppConstants.groupAlertsPath}/$groupId');
    return uid == null ? base : base.child(uid);
  }

  Future<void> publish(String groupId, GroupIncident incident) async {
    await _ref(groupId, incident.uid).set(incident.toRtdb());
  }

  Future<void> clear({
    required String groupId,
    required String uid,
  }) async {
    await _ref(groupId, uid).remove();
  }

  Stream<List<GroupIncident>> watchGroup(String groupId) {
    return _ref(groupId).onValue.map((event) {
      final value = event.snapshot.value;
      if (value is! Map) {
        return const <GroupIncident>[];
      }
      final out = <GroupIncident>[];
      value.forEach((key, raw) {
        if (raw is Map && key is String) {
          final incident = GroupIncident.fromRtdb(
            key,
            Map<dynamic, dynamic>.from(raw),
          );
          if (incident.active) {
            out.add(incident);
          }
        }
      });
      out.sort((a, b) => b.at.compareTo(a.at));
      return out;
    });
  }
}
