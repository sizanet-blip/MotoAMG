import 'dart:async';

import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_database/firebase_database.dart';
import 'package:loc_motos/core/constants/app_constants.dart';
import 'package:loc_motos/features/groups/domain/entities/group_incident.dart';
import 'package:loc_motos/features/groups/domain/exceptions/group_exceptions.dart';
import 'package:loc_motos/firebase_options.dart';

class GroupIncidentRemoteDataSource {
  GroupIncidentRemoteDataSource({FirebaseDatabase? database})
      : _database = database ??
            FirebaseDatabase.instanceFor(
              app: Firebase.app(),
              databaseURL: DefaultFirebaseOptions.realtimeDatabaseUrl,
            );

  final FirebaseDatabase _database;
  static const _networkTimeout = Duration(seconds: 8);
  static const _retryDelay = Duration(milliseconds: 700);
  static const _maxAttempts = 4;

  DatabaseReference _ref(String groupId, [String? uid]) {
    final base =
        _database.ref('${AppConstants.groupAlertsPath}/$groupId');
    return uid == null ? base : base.child(uid);
  }

  Future<void> publish(String groupId, GroupIncident incident) async {
    final node = _ref(groupId, incident.uid);
    try {
      await _withRetry(
        () => node.set(incident.toRtdb()),
        onFailure: 'enviar el aviso',
      );
    } on GroupException {
      rethrow;
    }
  }

  Future<void> clear({
    required String groupId,
    required String uid,
  }) async {
    try {
      await _withRetry(
        () => _ref(groupId, uid).remove(),
        onFailure: 'quitar el aviso',
      );
    } on GroupException {
      rethrow;
    }
  }

  Future<void> _withRetry(
    Future<void> Function() action, {
    required String onFailure,
  }) async {
    Object? lastError;
    for (var attempt = 0; attempt < _maxAttempts; attempt++) {
      if (attempt > 0) {
        await Future<void>.delayed(_retryDelay);
      }
      try {
        await action().timeout(_networkTimeout);
        return;
      } on GroupException {
        rethrow;
      } on FirebaseException catch (error) {
        throw GroupException('No se pudo $onFailure (${error.code}).');
      } on TimeoutException {
        lastError = GroupException('timeout');
      } on Exception catch (error) {
        lastError = GroupException('$error');
      }
    }
    throw lastError ??
        GroupException('No se pudo $onFailure. Inténtalo de nuevo.');
  }

  Stream<List<GroupIncident>> watchGroup(String groupId) {
    final node = _ref(groupId);
    return node.onValue.map((event) => _parseSnapshot(event.snapshot));
  }

  List<GroupIncident> _parseSnapshot(DataSnapshot snapshot) {
    final fromChildren = <GroupIncident>[];
    for (final child in snapshot.children) {
      final parsed = _parseEntry(child.key, child.value);
      if (parsed != null) {
        fromChildren.add(parsed);
      }
    }
    if (fromChildren.isNotEmpty) {
      fromChildren.sort((a, b) => b.at.compareTo(a.at));
      return fromChildren;
    }
    return _parseIncidentsMap(snapshot.value);
  }

  List<GroupIncident> _parseIncidentsMap(Object? value) {
    final map = _asMap(value);
    if (map == null) {
      return const <GroupIncident>[];
    }
    final out = <GroupIncident>[];
    for (final entry in map.entries) {
      final parsed = _parseEntry(entry.key?.toString(), entry.value);
      if (parsed != null) {
        out.add(parsed);
      }
    }
    out.sort((a, b) => b.at.compareTo(a.at));
    return out;
  }

  GroupIncident? _parseEntry(String? uid, Object? raw) {
    final map = _asMap(raw);
    if (uid == null || uid.isEmpty || map == null) {
      return null;
    }
    try {
      final incident = GroupIncident.fromRtdb(uid, map);
      return incident.active ? incident : null;
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
