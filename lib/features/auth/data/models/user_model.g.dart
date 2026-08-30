// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'user_model.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

UserModel _$UserModelFromJson(Map<String, dynamic> json) => UserModel(
      uid: json['uid'] as String,
      displayName: json['displayName'] as String,
      createdAt: const TimestampConverter().fromJson(json['createdAt'] as Object),
      provider: const AuthProviderTypeConverter().fromJson(
        json['provider'] as String,
      ),
      phoneNumber: json['phoneNumber'] as String?,
      email: json['email'] as String?,
      username: json['username'] as String?,
      photoUrl: json['photoUrl'] as String?,
      currentGroupId: json['currentGroupId'] as String?,
      currentClubId: json['currentClubId'] as String?,
      pendingClubRequestId: json['pendingClubRequestId'] as String?,
      allowSoloNavigation: json['allowSoloNavigation'] as bool? ?? false,
      bikeBrand: json['bikeBrand'] as String?,
      bikeModel: json['bikeModel'] as String?,
      bikeYear: json['bikeYear'] as String?,
      bikeColor: json['bikeColor'] as String?,
      bikePlate: json['bikePlate'] as String?,
      vehicles: parseUserVehicles(json['vehicles']),
      activeVehicleId: json['activeVehicleId'] as String?,
    );

Map<String, dynamic> _$UserModelToJson(UserModel instance) => <String, dynamic>{
      'uid': instance.uid,
      'displayName': instance.displayName,
      'createdAt': const TimestampConverter().toJson(instance.createdAt),
      'provider': const AuthProviderTypeConverter().toJson(instance.provider),
      'phoneNumber': instance.phoneNumber,
      'email': instance.email,
      'username': instance.username,
      'photoUrl': instance.photoUrl,
      'currentGroupId': instance.currentGroupId,
      'currentClubId': instance.currentClubId,
      'pendingClubRequestId': instance.pendingClubRequestId,
      'allowSoloNavigation': instance.allowSoloNavigation,
      'bikeBrand': instance.bikeBrand,
      'bikeModel': instance.bikeModel,
      'bikeYear': instance.bikeYear,
      'bikeColor': instance.bikeColor,
      'bikePlate': instance.bikePlate,
      'vehicles': [for (final v in instance.vehicles) v.toJson()],
      'activeVehicleId': instance.activeVehicleId,
    };
