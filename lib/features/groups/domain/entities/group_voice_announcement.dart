import 'package:equatable/equatable.dart';

/// Aviso de voz efímero para el pelotón (p. ej. rezagado al enganchar).
enum GroupVoiceKind {
  catchUpChase,
  catchUpDestination,
  incidentCleared,
}

extension GroupVoiceKindX on GroupVoiceKind {
  String get firestoreValue => switch (this) {
        GroupVoiceKind.catchUpChase => 'catch_up_chase',
        GroupVoiceKind.catchUpDestination => 'catch_up_destination',
        GroupVoiceKind.incidentCleared => 'incident_cleared',
      };

  static GroupVoiceKind? tryParse(String? raw) {
    return switch (raw) {
      'catch_up_chase' => GroupVoiceKind.catchUpChase,
      'catch_up_destination' => GroupVoiceKind.catchUpDestination,
      'incident_cleared' => GroupVoiceKind.incidentCleared,
      _ => null,
    };
  }
}

class GroupVoiceAnnouncement extends Equatable {
  const GroupVoiceAnnouncement({
    required this.id,
    required this.uid,
    required this.kind,
    required this.at,
    this.displayName,
  });

  final String id;
  final String uid;
  final GroupVoiceKind kind;
  final DateTime at;
  final String? displayName;

  String get dedupeKey => '$id|$uid|${at.toIso8601String()}';

  /// Frase para TTS en todo el grupo (tercera persona).
  String spokenMessage() {
    final name = (displayName ?? '').trim();
    final label = name.isEmpty ? 'Un compañero' : name;
    return switch (kind) {
      GroupVoiceKind.catchUpChase => '$label se dirige al grupo',
      GroupVoiceKind.catchUpDestination =>
        '$label va al destino del grupo directamente',
      GroupVoiceKind.incidentCleared => '$label ya está OK',
    };
  }

  Map<String, dynamic> toRtdb() => {
        'uid': uid,
        'kind': kind.firestoreValue,
        'at': at.toIso8601String(),
        if (displayName != null && displayName!.trim().isNotEmpty)
          'displayName': displayName!.trim(),
      };

  factory GroupVoiceAnnouncement.fromRtdb(
    String id,
    Map<dynamic, dynamic> data,
  ) {
    final kind = GroupVoiceKindX.tryParse(data['kind']?.toString()) ??
        GroupVoiceKind.catchUpChase;
    return GroupVoiceAnnouncement(
      id: id,
      uid: data['uid']?.toString() ?? '',
      kind: kind,
      at: DateTime.tryParse(data['at']?.toString() ?? '') ?? DateTime.now(),
      displayName: data['displayName']?.toString(),
    );
  }

  @override
  List<Object?> get props => [id, uid, kind, at, displayName];
}
