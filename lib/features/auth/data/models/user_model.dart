import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:json_annotation/json_annotation.dart';
import 'package:loc_motos/core/utils/timestamp_converter.dart';
import 'package:loc_motos/features/auth/data/models/auth_provider_converter.dart';
import 'package:loc_motos/features/auth/domain/entities/app_user.dart';

part 'user_model.g.dart';

/// Modelo de datos de [AppUser] para Cloud Firestore (`users/{uid}`).
@JsonSerializable(
  explicitToJson: true,
  converters: [TimestampConverter(), AuthProviderTypeConverter()],
)
class UserModel extends AppUser {
  const UserModel({
    required super.uid,
    required super.displayName,
    required super.createdAt,
    required super.provider,
    super.phoneNumber,
    super.email,
    super.username,
    super.photoUrl,
    super.currentGroupId,
    super.bikeBrand,
    super.bikeModel,
    super.bikeYear,
    super.bikeColor,
    super.bikePlate,
  });

  factory UserModel.fromEntity(AppUser user) {
    return UserModel(
      uid: user.uid,
      displayName: user.displayName,
      createdAt: user.createdAt,
      provider: user.provider,
      phoneNumber: user.phoneNumber,
      email: user.email,
      username: user.username,
      photoUrl: user.photoUrl,
      currentGroupId: user.currentGroupId,
      bikeBrand: user.bikeBrand,
      bikeModel: user.bikeModel,
      bikeYear: user.bikeYear,
      bikeColor: user.bikeColor,
      bikePlate: user.bikePlate,
    );
  }

  factory UserModel.fromJson(Map<String, dynamic> json) =>
      _$UserModelFromJson(json);

  Map<String, dynamic> toJson() => _$UserModelToJson(this);

  factory UserModel.fromFirestore(
    DocumentSnapshot<Map<String, dynamic>> snapshot,
  ) {
    final data = snapshot.data();
    if (data == null) {
      throw StateError('El usuario ${snapshot.id} no tiene datos');
    }
    return UserModel.fromJson({
      ...data,
      'uid': snapshot.id,
      'displayName': data['displayName'] ?? '',
      'provider': data['provider'] ??
          ((data['isAnonymous'] == true)
              ? 'anonymous'
              : ((data['email'] as String?)?.isNotEmpty == true
                  ? 'email'
                  : 'google')),
      'createdAt': parseFirestoreDate(data['createdAt']),
    });
  }

  /// Payload de documento. El `uid` es el ID del documento, no un campo.
  Map<String, dynamic> toFirestore() {
    return toJson()..remove('uid');
  }
}
