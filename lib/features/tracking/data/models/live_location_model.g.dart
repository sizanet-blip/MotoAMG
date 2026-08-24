// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'live_location_model.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

LiveLocationModel _$LiveLocationModelFromJson(Map<String, dynamic> json) =>
    LiveLocationModel(
      uid: json['uid'] as String,
      groupId: json['groupId'] as String,
      lat: (json['lat'] as num).toDouble(),
      lng: (json['lng'] as num).toDouble(),
      heading: (json['heading'] as num).toDouble(),
      speed: (json['speed'] as num).toDouble(),
      updatedAt: const EpochMillisConverter().fromJson(
        (json['updatedAt'] as num).toInt(),
      ),
      displayName: json['displayName'] as String,
    );

Map<String, dynamic> _$LiveLocationModelToJson(LiveLocationModel instance) =>
    <String, dynamic>{
      'uid': instance.uid,
      'groupId': instance.groupId,
      'lat': instance.lat,
      'lng': instance.lng,
      'heading': instance.heading,
      'speed': instance.speed,
      'updatedAt': const EpochMillisConverter().toJson(instance.updatedAt),
      'displayName': instance.displayName,
    };
