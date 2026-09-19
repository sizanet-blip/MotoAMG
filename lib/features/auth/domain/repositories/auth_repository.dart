import 'package:moto_amg/features/auth/domain/entities/app_user.dart';
import 'package:moto_amg/features/auth/domain/entities/user_vehicle.dart';
import 'package:moto_amg/features/auth/domain/entities/username_registration.dart';

abstract class AuthRepository {
  Stream<AppUser?> watchCurrentUser();

  Future<AppUser> signInWithGoogle();

  /// Alta con Google (solo si no existe).
  Future<AppUser> registerWithGoogle();

  Future<AppUser> signInWithEmail({
    required String email,
    required String password,
  });

  Future<AppUser> registerWithEmail({
    required String email,
    required String password,
    required String displayName,
  });

  Future<AppUser> signInWithUsername({
    required String username,
    required String password,
  });

  Future<UsernameRegistration> registerWithUsername({
    required String username,
    required String password,
  });

  Future<void> sendPasswordReset(String email);

  Future<AppUser> recoverUsernamePassword({
    required String username,
    required String recoveryKey,
    required String newPassword,
  });

  Future<String> revealRecoveryKey({
    required String username,
    required String password,
  });

  Future<AppUser> signInAnonymously({required String displayName});

  Future<AppUser> updateDisplayName(String displayName);

  Future<AppUser> updateProfile({
    required String displayName,
    String? phoneNumber,
    String? bikeBrand,
    String? bikeModel,
    String? bikeYear,
    String? bikeColor,
    String? bikePlate,
    List<UserVehicle>? vehicles,
    String? activeVehicleId,
    bool clearActiveVehicleId = false,
  });

  Future<void> changePassword({
    required String currentPassword,
    required String newPassword,
  });

  /// Aceptación de política/términos ligada a la cuenta autenticada.
  Future<AppUser> acceptPrivacyPolicy();

  Stream<AppUser?> watchUser(String uid);

  Future<void> signOut();
}
