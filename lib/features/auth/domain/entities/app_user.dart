import 'package:equatable/equatable.dart';
import 'package:moto_amg/core/constants/app_constants.dart';
import 'package:moto_amg/features/auth/domain/entities/user_vehicle.dart';

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
    this.currentClubId,
    this.pendingClubRequestId,
    this.allowSoloNavigation = false,
    this.bikeBrand,
    this.bikeModel,
    this.bikeYear,
    this.bikeColor,
    this.bikePlate,
    this.vehicles = const [],
    this.activeVehicleId,
    this.privacyAcceptedAt,
    this.privacyAcceptedVersion,
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

  /// Club activo (acceso a la app).
  final String? currentClubId;

  /// Solicitud de alta de club o grupo pendiente de aprobación en el panel.
  final String? pendingClubRequestId;

  /// Si true, puede usar la app sin club (lo marca el admin en Yii2).
  final bool allowSoloNavigation;

  /// Campos legacy (compatibilidad grupos / docs antiguos).
  final String? bikeBrand;
  final String? bikeModel;
  final String? bikeYear;
  final String? bikeColor;
  final String? bikePlate;

  final List<UserVehicle> vehicles;
  final String? activeVehicleId;

  /// Momento en que esta cuenta aceptó la política vigente.
  final DateTime? privacyAcceptedAt;

  /// Versión de política aceptada (ver [AppConstants.privacyPolicyVersion]).
  final String? privacyAcceptedVersion;

  bool get isAnonymous => provider == AuthProviderType.anonymous;

  bool get isUsernameAccount => provider == AuthProviderType.username;

  bool get canChangePassword =>
      provider == AuthProviderType.email ||
      provider == AuthProviderType.username;

  /// Vehículos con migración desde `bike*` si la lista está vacía.
  List<UserVehicle> get resolvedVehicles {
    if (vehicles.isNotEmpty) {
      return vehicles;
    }
    final hasLegacy = [
      bikeBrand,
      bikeModel,
      bikeYear,
      bikeColor,
      bikePlate,
    ].any((v) => v != null && v.trim().isNotEmpty);
    if (!hasLegacy) {
      return const [];
    }
    return [
      UserVehicle(
        id: 'legacy_bike',
        kind: VehicleKind.motorcycle,
        fuelType: VehicleFuelType.unspecified,
        brand: bikeBrand,
        model: bikeModel,
        year: bikeYear,
        color: bikeColor,
        plate: bikePlate,
      ),
    ];
  }

  UserVehicle? get activeVehicle {
    final list = resolvedVehicles;
    if (list.isEmpty) {
      return null;
    }
    if (activeVehicleId != null) {
      for (final v in list) {
        if (v.id == activeVehicleId) {
          return v;
        }
      }
    }
    return list.first;
  }

  String get bikeLabel {
    final active = activeVehicle;
    if (active != null) {
      return active.displayLabel;
    }
    final parts = [
      bikeBrand,
      bikeModel,
    ].where((value) => value != null && value.trim().isNotEmpty);
    return parts.map((value) => value!.trim()).join(' ');
  }

  bool get isInGroup => currentGroupId != null && currentGroupId!.isNotEmpty;

  bool get isInClub => currentClubId != null && currentClubId!.isNotEmpty;

  bool get hasPendingClubRequest =>
      pendingClubRequestId != null && pendingClubRequestId!.isNotEmpty;

  /// Invitados saltan el gate de club (solo unirse a salida con código).
  bool get needsClubGate {
    if (isAnonymous) {
      return false;
    }
    if (allowSoloNavigation) {
      return false;
    }
    if (isInClub) {
      return false;
    }
    return true;
  }

  bool get needsDisplayName => displayName.trim().isEmpty;

  /// Cada cuenta debe aceptar la versión vigente (no basta con el dispositivo).
  bool get needsPrivacyAcceptance {
    final version = privacyAcceptedVersion?.trim() ?? '';
    return version != AppConstants.privacyPolicyVersion;
  }

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
    String? currentClubId,
    String? pendingClubRequestId,
    bool? allowSoloNavigation,
    String? bikeBrand,
    String? bikeModel,
    String? bikeYear,
    String? bikeColor,
    String? bikePlate,
    List<UserVehicle>? vehicles,
    String? activeVehicleId,
    DateTime? privacyAcceptedAt,
    String? privacyAcceptedVersion,
    bool clearCurrentGroupId = false,
    bool clearCurrentClubId = false,
    bool clearPendingClubRequestId = false,
    bool clearActiveVehicleId = false,
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
      currentClubId: clearCurrentClubId
          ? null
          : currentClubId ?? this.currentClubId,
      pendingClubRequestId: clearPendingClubRequestId
          ? null
          : pendingClubRequestId ?? this.pendingClubRequestId,
      allowSoloNavigation: allowSoloNavigation ?? this.allowSoloNavigation,
      bikeBrand: bikeBrand ?? this.bikeBrand,
      bikeModel: bikeModel ?? this.bikeModel,
      bikeYear: bikeYear ?? this.bikeYear,
      bikeColor: bikeColor ?? this.bikeColor,
      bikePlate: bikePlate ?? this.bikePlate,
      vehicles: vehicles ?? this.vehicles,
      activeVehicleId: clearActiveVehicleId
          ? null
          : activeVehicleId ?? this.activeVehicleId,
      privacyAcceptedAt: privacyAcceptedAt ?? this.privacyAcceptedAt,
      privacyAcceptedVersion:
          privacyAcceptedVersion ?? this.privacyAcceptedVersion,
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
        currentClubId,
        pendingClubRequestId,
        allowSoloNavigation,
        bikeBrand,
        bikeModel,
        bikeYear,
        bikeColor,
        bikePlate,
        vehicles,
        activeVehicleId,
        privacyAcceptedAt,
        privacyAcceptedVersion,
      ];
}
