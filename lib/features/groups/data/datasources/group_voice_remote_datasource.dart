import 'dart:async';

import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_database/firebase_database.dart';
import 'package:moto_amg/core/constants/app_constants.dart';
import 'package:moto_amg/features/groups/domain/entities/group_voice_announcement.dart';
import 'package:moto_amg/features/groups/domain/exceptions/group_exceptions.dart';
import 'package:moto_amg/firebase_options.dart';

class GroupVoiceRemoteDataSource {
  GroupVoiceRemoteDataSource({FirebaseDatabase? database})
      : _database = database ??
            FirebaseDatabase.instanceFor(
              app: Firebase.app(),
              databaseURL: DefaultFirebaseOptions.realtimeDatabaseUrl,
            );

  final FirebaseDatabase _database;
  static const _networkTimeout = Duration(seconds: 8);

  DatabaseReference _groupRef(String groupId) =>
      _database.ref('${AppConstants.groupVoicePath}/$groupId');

  /// Publica un aviso de voz; se borra solo tras [ttl] para no acumular basura.
  Future<void> publish({
    required String groupId,
    required GroupVoiceAnnouncement announcement,
    Duration ttl = const Duration(seconds: 60),
  }) async {
    final node = _groupRef(groupId).push();
    final payload = announcement.toRtdb();
    try {
      await node.set(payload).timeout(_networkTimeout);
    } on FirebaseException catch (error) {
      throw GroupException('No se pudo avisar al grupo (${error.code}).');
    } on TimeoutException {
      throw const GroupException('No se pudo avisar al grupo (timeout).');
    }
    // Limpieza diferida; si falla no importa.
    unawaited(
      Future<void>.delayed(ttl, () async {
        try {
          await node.remove();
        } catch (_) {}
      }),
    );
  }

  Stream<List<GroupVoiceAnnouncement>> watchGroup(String groupId) {
    return _groupRef(groupId).onValue.map((event) {
      final out = <GroupVoiceAnnouncement>[];
      for (final child in event.snapshot.children) {
        final key = child.key;
        final value = child.value;
        if (key == null || value is! Map) {
          continue;
        }
        try {
          final parsed = GroupVoiceAnnouncement.fromRtdb(
            key,
            Map<dynamic, dynamic>.from(value),
          );
          if (parsed.uid.isNotEmpty) {
            out.add(parsed);
          }
        } catch (_) {}
      }
      out.sort((a, b) => b.at.compareTo(a.at));
      return out;
    });
  }
}
