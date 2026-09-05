import 'package:equatable/equatable.dart';
import 'package:moto_amg/features/navigation/domain/entities/geo_point.dart';

/// Tipo de incidencia de grupo.
enum GroupIncidentType {
  emergencia,
  averia,
  separado,
  /// Cabecera/admin pide al pelotón esperar o reunirse.
  espera,
}

extension GroupIncidentTypeX on GroupIncidentType {
  String get label => switch (this) {
        GroupIncidentType.emergencia => 'Emergencia',
        GroupIncidentType.averia => 'Avería',
        GroupIncidentType.separado => 'Separado',
        GroupIncidentType.espera => 'Esperar / reunir',
      };

  /// Mayor = más prioritario.
  int get priorityRank => switch (this) {
        GroupIncidentType.emergencia => 4,
        GroupIncidentType.averia => 3,
        GroupIncidentType.espera => 2,
        GroupIncidentType.separado => 1,
      };

  String get firestoreValue => name;

  static GroupIncidentType? tryParse(String? raw) {
    if (raw == null) {
      return null;
    }
    for (final t in GroupIncidentType.values) {
      if (t.name == raw) {
        return t;
      }
    }
    return null;
  }
}

/// Gravedad solo para emergencias.
enum GroupIncidentSeverity {
  critica,
  alta,
  moderada,
  leve,
}

extension GroupIncidentSeverityX on GroupIncidentSeverity {
  String get label => switch (this) {
        GroupIncidentSeverity.critica => 'Urgente · 112',
        GroupIncidentSeverity.alta => 'Grave',
        GroupIncidentSeverity.moderada => 'Moderada',
        GroupIncidentSeverity.leve => 'Leve',
      };

  String get shortBanner => switch (this) {
        GroupIncidentSeverity.critica => 'URGENTE · valorar 112',
        GroupIncidentSeverity.alta => 'GRAVE',
        GroupIncidentSeverity.moderada => 'MODERADA',
        GroupIncidentSeverity.leve => 'LEVE',
      };

  String get firestoreValue => name;

  static GroupIncidentSeverity? tryParse(String? raw) {
    if (raw == null) {
      return null;
    }
    for (final s in GroupIncidentSeverity.values) {
      if (s.name == raw) {
        return s;
      }
    }
    return null;
  }
}

/// Alerta activa de un miembro del grupo.
class GroupIncident extends Equatable {
  const GroupIncident({
    required this.uid,
    required this.type,
    required this.point,
    required this.at,
    this.severity,
    this.displayName,
    this.active = true,
  });

  final String uid;
  final GroupIncidentType type;
  final GeoPoint point;
  final DateTime at;
  final GroupIncidentSeverity? severity;
  final String? displayName;
  final bool active;

  bool get isCriticalEmergency =>
      type == GroupIncidentType.emergencia &&
      severity == GroupIncidentSeverity.critica;

  Map<String, dynamic> toRtdb() => {
        'type': type.firestoreValue,
        'lat': point.lat,
        'lng': point.lng,
        'at': at.toIso8601String(),
        'active': active,
        if (severity != null) 'severity': severity!.firestoreValue,
        if (displayName != null) 'displayName': displayName,
      };

  factory GroupIncident.fromRtdb(String uid, Map<dynamic, dynamic> data) {
    return GroupIncident(
      uid: uid,
      type: GroupIncidentTypeX.tryParse(data['type']?.toString()) ??
          GroupIncidentType.separado,
      point: GeoPoint(
        lat: (data['lat'] as num?)?.toDouble() ?? 0,
        lng: (data['lng'] as num?)?.toDouble() ?? 0,
      ),
      at: DateTime.tryParse(data['at']?.toString() ?? '') ?? DateTime.now(),
      severity: GroupIncidentSeverityX.tryParse(data['severity']?.toString()),
      displayName: data['displayName']?.toString(),
      active: data['active'] != false,
    );
  }

  @override
  List<Object?> get props =>
      [uid, type, point, at, severity, displayName, active];
}
