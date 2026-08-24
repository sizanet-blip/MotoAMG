import 'package:loc_motos/features/auth/domain/entities/app_user.dart';
import 'package:loc_motos/features/auth/domain/entities/username_registration.dart';

abstract class AuthRepository {
  Stream<AppUser?> watchCurrentUser();

  Future<AppUser> signInWithGoogle();

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
  });

  Future<void> changePassword({
    required String currentPassword,
    required String newPassword,
  });

  Stream<AppUser?> watchUser(String uid);

  Future<void> signOut();
}
