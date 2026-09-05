import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:json_annotation/json_annotation.dart';

/// Convierte [DateTime] ↔ [Timestamp] / epoch / ISO-8601 (capa de datos).
class TimestampConverter implements JsonConverter<DateTime, Object> {
  const TimestampConverter();

  @override
  DateTime fromJson(Object json) => parseFirestoreDate(json);

  @override
  Object toJson(DateTime date) => Timestamp.fromDate(date);
}

/// Igual que [TimestampConverter], pero admite null.
class NullableTimestampConverter implements JsonConverter<DateTime?, Object?> {
  const NullableTimestampConverter();

  @override
  DateTime? fromJson(Object? json) {
    if (json == null) {
      return null;
    }
    return parseFirestoreDate(json);
  }

  @override
  Object? toJson(DateTime? date) {
    if (date == null) {
      return null;
    }
    return Timestamp.fromDate(date);
  }
}

DateTime parseFirestoreDate(Object? json) {
  if (json == null) {
    return DateTime.now();
  }
  if (json is DateTime) {
    return json;
  }
  if (json is Timestamp) {
    return json.toDate();
  }
  if (json is int) {
    return DateTime.fromMillisecondsSinceEpoch(json);
  }
  if (json is String) {
    return DateTime.parse(json);
  }
  try {
    final dynamic value = json;
    final converted = value.toDate();
    if (converted is DateTime) {
      return converted;
    }
  } catch (_) {}
  throw FormatException('No se puede convertir $json a DateTime');
}

/// Convierte [DateTime] ↔ milisegundos epoch (Realtime Database).
class EpochMillisConverter implements JsonConverter<DateTime, int> {
  const EpochMillisConverter();

  @override
  DateTime fromJson(int json) => DateTime.fromMillisecondsSinceEpoch(json);

  @override
  int toJson(DateTime date) => date.millisecondsSinceEpoch;
}
