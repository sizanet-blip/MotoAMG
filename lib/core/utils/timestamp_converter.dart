import 'package:json_annotation/json_annotation.dart';

/// Convierte [DateTime] ↔ milisegundos epoch (Realtime Database / JSON API).
class EpochMillisConverter implements JsonConverter<DateTime, int> {
  const EpochMillisConverter();

  @override
  DateTime fromJson(int json) => DateTime.fromMillisecondsSinceEpoch(json);

  @override
  int toJson(DateTime date) => date.millisecondsSinceEpoch;
}

DateTime parseFlexibleDate(Object? json) {
  if (json == null) {
    return DateTime.now();
  }
  if (json is DateTime) {
    return json;
  }
  if (json is int) {
    return DateTime.fromMillisecondsSinceEpoch(json);
  }
  if (json is String) {
    return DateTime.parse(json);
  }
  throw FormatException('No se puede convertir $json a DateTime');
}
