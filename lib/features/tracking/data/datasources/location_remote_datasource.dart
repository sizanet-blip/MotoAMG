import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_database/firebase_database.dart';
import 'package:loc_motos/core/constants/app_constants.dart';
import 'package:loc_motos/features/tracking/data/models/live_location_model.dart';
import 'package:loc_motos/features/tracking/domain/entities/live_location.dart';
import 'package:loc_motos/features/tracking/domain/exceptions/location_exceptions.dart';
import 'package:loc_motos/firebase_options.dart';

class LocationRemoteDataSource {
  LocationRemoteDataSource({FirebaseDatabase? database})
    : _database =
          database ??
          FirebaseDatabase.instanceFor(
            app: Firebase.app(),
            databaseURL: DefaultFirebaseOptions.android.databaseURL,
          );

  final FirebaseDatabase _database;

  DatabaseReference _groupRef(String groupId) {
    return _database.ref('${AppConstants.liveLocationsPath}/$groupId');
  }

  DatabaseReference _userRef(String groupId, String uid) {
    return _groupRef(groupId).child(uid);
  }

  Future<void> publish(LiveLocation location) async {
    try {
      final model = LiveLocationModel.fromEntity(location);
      await _userRef(location.groupId, location.uid).set(model.toRtdb());
    } on FirebaseException catch (error) {
      throw LocationException(
        'No se pudo enviar la ubicación. ${error.message ?? error.code}',
      );
    }
  }

  Future<void> clear({required String groupId, required String uid}) async {
    try {
      await _userRef(groupId, uid).remove();
    } on FirebaseException catch (error) {
      throw LocationException(
        'No se pudo borrar la ubicación. ${error.message ?? error.code}',
      );
    }
  }

  Stream<List<LiveLocation>> watchGroup(String groupId) {
    final ref = _groupRef(groupId);
    return ref.onValue.map((event) => _parseSnapshot(groupId, event.snapshot));
  }

  List<LiveLocation> _parseSnapshot(String groupId, DataSnapshot snapshot) {
    final fromChildren = <LiveLocation>[];
    for (final child in snapshot.children) {
      final parsed = _parseEntry(groupId, child.key, child.value);
      if (parsed != null) {
        fromChildren.add(parsed);
      }
    }
    if (fromChildren.isNotEmpty) {
      return fromChildren;
    }

    final value = _asMap(snapshot.value);
    if (value == null) {
      return const <LiveLocation>[];
    }
    final fromValue = <LiveLocation>[];
    value.forEach((key, data) {
      final parsed = _parseEntry(groupId, key?.toString(), data);
      if (parsed != null) {
        fromValue.add(parsed);
      }
    });
    return fromValue;
  }

  LiveLocation? _parseEntry(String groupId, String? uid, Object? data) {
    final map = _asMap(data);
    if (uid == null || uid.isEmpty || map == null) {
      return null;
    }
    try {
      return LiveLocationModel.fromRtdb(
        groupId: groupId,
        uid: uid,
        data: map,
      );
    } catch (_) {
      return null;
    }
  }

  Map<dynamic, dynamic>? _asMap(Object? value) {
    if (value is Map) {
      return Map<dynamic, dynamic>.from(value);
    }
    return null;
  }
}
