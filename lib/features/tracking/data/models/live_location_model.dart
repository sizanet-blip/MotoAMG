import 'package:json_annotation/json_annotation.dart';
import 'package:loc_motos/core/utils/timestamp_converter.dart';
import 'package:loc_motos/features/tracking/domain/entities/live_location.dart';

part 'live_location_model.g.dart';

/// Modelo de datos de [LiveLocation] para Realtime Database
/// (`live_locations/{groupId}/{uid}`).
@JsonSerializable(explicitToJson: true, converters: [EpochMillisConverter()])
class LiveLocationModel extends LiveLocation {
  const LiveLocationModel({
    required super.uid,
    required super.groupId,
    required super.lat,
    required super.lng,
    required super.heading,
    required super.speed,
    required super.updatedAt,
    required super.displayName,
    super.hasSignal,
  });

  factory LiveLocationModel.fromEntity(LiveLocation location) {
    return LiveLocationModel(
      uid: location.uid,
      groupId: location.groupId,
      lat: location.lat,
      lng: location.lng,
      heading: location.heading,
      speed: location.speed,
      updatedAt: location.updatedAt,
      displayName: location.displayName,
      hasSignal: location.hasSignal,
    );
  }

  factory LiveLocationModel.fromJson(Map<String, dynamic> json) =>
      _$LiveLocationModelFromJson(json);

  Map<String, dynamic> toJson() => _$LiveLocationModelToJson(this);

  factory LiveLocationModel.fromRtdb({
    required String groupId,
    required String uid,
    required Map<dynamic, dynamic> data,
  }) {
    final map = <String, dynamic>{
      for (final entry in data.entries) '${entry.key}': entry.value,
    };
    final lat = _asFinite(map['lat']);
    final lng = _asFinite(map['lng']);
    if (lat == null || lng == null) {
      throw FormatException('Ubicación incompleta para $uid');
    }
    return LiveLocationModel(
      uid: uid,
      groupId: groupId,
      lat: lat,
      lng: lng,
      heading: _asFinite(map['heading']) ?? 0,
      speed: _asFinite(map['speed']) ?? 0,
      updatedAt: _asDate(map['updatedAt']),
      displayName: '${map['displayName'] ?? ''}',
      hasSignal: _asBool(map['hasSignal'], fallback: true),
    );
  }

  /// Payload del nodo RTDB. `uid` y `groupId` van en la ruta, no en el valor.
  Map<String, dynamic> toRtdb() {
    return {
      'lat': _finiteOrZero(lat),
      'lng': _finiteOrZero(lng),
      'heading': _finiteOrZero(heading),
      'speed': _finiteOrZero(speed),
      'updatedAt': const EpochMillisConverter().toJson(updatedAt),
      'displayName': displayName,
      'hasSignal': hasSignal,
    };
  }
}

double? _asFinite(Object? value) {
  if (value is num) {
    final number = value.toDouble();
    return number.isFinite ? number : null;
  }
  return null;
}

double _finiteOrZero(double value) => value.isFinite ? value : 0;

bool _asBool(Object? value, {required bool fallback}) {
  if (value is bool) {
    return value;
  }
  return fallback;
}

DateTime _asDate(Object? value) {
  if (value is num) {
    return DateTime.fromMillisecondsSinceEpoch(value.toInt());
  }
  return DateTime.now();
}
