import 'dart:async';

import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_database/firebase_database.dart';
import 'package:moto_amg/core/constants/app_constants.dart';
import 'package:moto_amg/features/groups/domain/entities/group_stop.dart';
import 'package:moto_amg/features/groups/domain/exceptions/group_exceptions.dart';
import 'package:moto_amg/firebase_options.dart';

class GroupStopRemoteDataSource {
  GroupStopRemoteDataSource({FirebaseDatabase? database})
      : _database = database ??
            FirebaseDatabase.instanceFor(
              app: Firebase.app(),
              databaseURL: DefaultFirebaseOptions.realtimeDatabaseUrl,
            );

  final FirebaseDatabase _database;
  static const _networkTimeout = Duration(seconds: 8);
  static const _retryDelay = Duration(milliseconds: 700);
  static const _maxAttempts = 4;

  DatabaseReference _ref(String groupId, [String? stopId]) {
    final base = _database.ref('${AppConstants.groupStopsPath}/$groupId');
    return stopId == null ? base : base.child(stopId);
  }

  Future<String> publish(String groupId, GroupStop stop) async {
    final node = stop.id.isEmpty ? _ref(groupId).push() : _ref(groupId, stop.id);
    try {
      await _withRetry(
        () => node.set(stop.toRtdb()),
        onFailure: 'marcar la parada',
      );
      return node.key ?? stop.id;
    } on GroupException {
      rethrow;
    }
  }

  Future<void> clear({
    required String groupId,
    required String stopId,
  }) async {
    try {
      await _withRetry(
        () => _ref(groupId, stopId).remove(),
        onFailure: 'quitar la parada',
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

  Stream<List<GroupStop>> watchGroup(String groupId) {
    return _ref(groupId).onValue.map((event) => _parseSnapshot(event.snapshot));
  }

  List<GroupStop> _parseSnapshot(DataSnapshot snapshot) {
    final out = <GroupStop>[];
    for (final child in snapshot.children) {
      final parsed = _parseEntry(child.key, child.value);
      if (parsed != null) {
        out.add(parsed);
      }
    }
    out.sort((a, b) => b.at.compareTo(a.at));
    return out;
  }

  GroupStop? _parseEntry(String? id, Object? raw) {
    final map = raw is Map ? Map<dynamic, dynamic>.from(raw) : null;
    if (id == null || id.isEmpty || map == null) {
      return null;
    }
    try {
      final stop = GroupStop.fromRtdb(id, map);
      return stop.active ? stop : null;
    } catch (_) {
      return null;
    }
  }
}
