import 'package:equatable/equatable.dart';

enum AuthProviderType { google, email, username, anonymous }

/// Usuario de dominio. No depende de Firebase.
class AppUser extends Equatable {
  const AppUser({
    required this.uid,
    required this.displayName,
    required this.createdAt,
    required this.provider,
    this.phoneNumber,
    this.email,
    this.username,
    this.photoUrl,
    this.currentGroupId,
    this.bikeBrand,
    this.bikeModel,
    this.bikeYear,
    this.bikeColor,
    this.bikePlate,
  });

  final String uid;
  final String displayName;
  final DateTime createdAt;
  final AuthProviderType provider;
  final String? phoneNumber;
  final String? email;
  final String? username;
  final String? photoUrl;
  final String? currentGroupId;
  final String? bikeBrand;
  final String? bikeModel;
  final String? bikeYear;
  final String? bikeColor;
  final String? bikePlate;

  bool get isAnonymous => provider == AuthProviderType.anonymous;

  bool get isUsernameAccount => provider == AuthProviderType.username;

  bool get canChangePassword =>
      provider == AuthProviderType.email ||
      provider == AuthProviderType.username;

  String get bikeLabel {
    final parts = [
      bikeBrand,
      bikeModel,
    ].where((value) => value != null && value.trim().isNotEmpty);
    return parts.map((value) => value!.trim()).join(' ');
  }

  bool get isInGroup => currentGroupId != null && currentGroupId!.isNotEmpty;

  bool get needsDisplayName => displayName.trim().isEmpty;

  AppUser copyWith({
    String? uid,
    String? displayName,
    DateTime? createdAt,
    AuthProviderType? provider,
    String? phoneNumber,
    String? email,
    String? username,
    String? photoUrl,
    String? currentGroupId,
    String? bikeBrand,
    String? bikeModel,
    String? bikeYear,
    String? bikeColor,
    String? bikePlate,
    bool clearCurrentGroupId = false,
  }) {
    return AppUser(
      uid: uid ?? this.uid,
      displayName: displayName ?? this.displayName,
      createdAt: createdAt ?? this.createdAt,
      provider: provider ?? this.provider,
      phoneNumber: phoneNumber ?? this.phoneNumber,
      email: email ?? this.email,
      username: username ?? this.username,
      photoUrl: photoUrl ?? this.photoUrl,
      currentGroupId: clearCurrentGroupId
          ? null
          : currentGroupId ?? this.currentGroupId,
      bikeBrand: bikeBrand ?? this.bikeBrand,
      bikeModel: bikeModel ?? this.bikeModel,
      bikeYear: bikeYear ?? this.bikeYear,
      bikeColor: bikeColor ?? this.bikeColor,
      bikePlate: bikePlate ?? this.bikePlate,
    );
  }

  @override
  List<Object?> get props => [
    uid,
    displayName,
    createdAt,
    provider,
    phoneNumber,
    email,
    username,
    photoUrl,
    currentGroupId,
    bikeBrand,
    bikeModel,
    bikeYear,
    bikeColor,
    bikePlate,
  ];
}
