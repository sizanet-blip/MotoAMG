import 'package:loc_motos/features/auth/data/datasources/auth_remote_datasource.dart';
import 'package:loc_motos/features/auth/domain/entities/app_user.dart';
import 'package:loc_motos/features/auth/domain/entities/user_vehicle.dart';
import 'package:loc_motos/features/auth/domain/entities/username_registration.dart';
import 'package:loc_motos/features/auth/domain/exceptions/auth_exceptions.dart';
import 'package:loc_motos/features/auth/domain/repositories/auth_repository.dart';

class AuthRepositoryImpl implements AuthRepository {
  AuthRepositoryImpl(this._remote);

  final AuthRemoteDataSource _remote;

  @override
  Stream<AppUser?> watchCurrentUser() {
    return _remote.userChanges().asyncMap((firebaseUser) async {
      if (firebaseUser == null) {
        return null;
      }
      final latest = _remote.currentFirebaseUser ?? firebaseUser;
      try {
        final stored = await _remote.fetchUser(latest.uid);
        if (stored != null && stored.displayName.trim().isNotEmpty) {
          return stored;
        }
      } catch (_) {
        // Perfil ilegible o Firestore no listo; seguimos con Auth.
      }
      return _remote.userFromFirebase(latest);
    });
  }

  @override
  Future<AppUser> signInWithGoogle() async {
    final credential = await _remote.signInWithGoogle();
    final user = credential.user;
    if (user == null) {
      throw const AuthException('Google no devolvió un usuario.');
    }
    final appUser = _remote.userFromFirebase(user);
    return _saveProfile(appUser);
  }

  @override
  Future<AppUser> signInWithEmail({
    required String email,
    required String password,
  }) async {
    final credential = await _remote.signInWithEmail(
      email: email.trim().toLowerCase(),
      password: password,
    );
    final user = credential.user;
    if (user == null) {
      throw const AuthException('No se pudo iniciar sesión.');
    }
    return _saveProfile(_remote.userFromFirebase(user));
  }

  @override
  Future<AppUser> signInWithUsername({
    required String username,
    required String password,
  }) async {
    final credential = await _remote.signInWithUsername(
      username: username,
      password: password,
    );
    final user = credential.user;
    if (user == null) {
      throw const AuthException('No se pudo iniciar sesión.');
    }
    return _saveProfile(_remote.userFromFirebase(user));
  }

  @override
  Future<UsernameRegistration> registerWithUsername({
    required String username,
    required String password,
  }) async {
    final result = await _remote.registerWithUsername(
      username: username,
      password: password,
    );
    final user = result.credential.user;
    if (user == null) {
      throw const AuthException('No se pudo crear la cuenta.');
    }
    await _remote.updateFirebaseDisplayName(username.trim());
    final refreshed = _remote.currentFirebaseUser ?? user;
    final appUser = _remote.userFromFirebase(refreshed).copyWith(
      displayName: username.trim(),
      provider: AuthProviderType.username,
      username: result.username,
    );
    return UsernameRegistration(
      user: await _saveProfile(appUser),
      recoveryKey: result.recoveryKey,
    );
  }

  @override
  Future<AppUser> registerWithEmail({
    required String email,
    required String password,
    required String displayName,
  }) async {
    final credential = await _remote.registerWithEmail(
      email: email.trim().toLowerCase(),
      password: password,
    );
    final user = credential.user;
    if (user == null) {
      throw const AuthException('No se pudo crear la cuenta.');
    }
    await _remote.updateFirebaseDisplayName(displayName);
    await _remote.sendEmailVerification();
    final refreshed = _remote.currentFirebaseUser ?? user;
    final appUser = _remote.userFromFirebase(refreshed).copyWith(
      displayName: displayName,
      provider: AuthProviderType.email,
    );
    return _saveProfile(appUser);
  }

  @override
  Future<void> sendPasswordReset(String email) {
    return _remote.sendPasswordReset(email.trim().toLowerCase());
  }

  @override
  Future<AppUser> recoverUsernamePassword({
    required String username,
    required String recoveryKey,
    required String newPassword,
  }) async {
    final credential = await _remote.recoverUsernamePassword(
      username: username,
      recoveryKey: recoveryKey,
      newPassword: newPassword,
    );
    final user = credential.user;
    if (user == null) {
      throw const AuthException('No se pudo recuperar la cuenta.');
    }
    return _saveProfile(_remote.userFromFirebase(user));
  }

  @override
  Future<String> revealRecoveryKey({
    required String username,
    required String password,
  }) {
    return _remote.revealRecoveryKey(username: username, password: password);
  }

  @override
  Future<AppUser> signInAnonymously({required String displayName}) async {
    final credential = await _remote.signInAnonymously();
    final user = credential.user;
    if (user == null) {
      throw const AuthException('No se pudo crear la sesión sin cuenta.');
    }
    await _remote.updateFirebaseDisplayName(displayName);
    final refreshed = _remote.currentFirebaseUser ?? user;
    final appUser = _remote.userFromFirebase(refreshed).copyWith(
      displayName: displayName,
      provider: AuthProviderType.anonymous,
    );
    return _saveProfile(appUser);
  }

  @override
  Future<AppUser> updateDisplayName(String displayName) async {
    await _remote.updateFirebaseDisplayName(displayName);
    final user = _remote.currentFirebaseUser;
    if (user == null) {
      throw const AuthException('No hay sesión activa.');
    }
    return _saveProfile(
      _remote.userFromFirebase(user).copyWith(displayName: displayName),
    );
  }

  @override
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
  }) async {
    final firebaseUser = _remote.currentFirebaseUser;
    if (firebaseUser == null) {
      throw const AuthException('No hay sesión activa.');
    }
    AppUser current = _remote.userFromFirebase(firebaseUser);
    try {
      current = await _remote.fetchUser(firebaseUser.uid) ?? current;
    } catch (_) {}

    final nextVehicles = vehicles ?? current.vehicles;
    final nextActiveId = clearActiveVehicleId
        ? null
        : (activeVehicleId ?? current.activeVehicleId);
    UserVehicle? active;
    if (nextActiveId != null) {
      for (final v in nextVehicles) {
        if (v.id == nextActiveId) {
          active = v;
          break;
        }
      }
    }
    active ??= nextVehicles.isNotEmpty ? nextVehicles.first : null;

    final updated = AppUser(
      uid: current.uid,
      displayName: displayName.trim(),
      createdAt: current.createdAt,
      provider: current.provider,
      phoneNumber: phoneNumber,
      email: current.email,
      username: current.username,
      photoUrl: current.photoUrl,
      currentGroupId: current.currentGroupId,
      vehicles: nextVehicles,
      activeVehicleId: active?.id ?? nextActiveId,
      // Legacy mirror for group maps / old clients.
      bikeBrand: active?.brand ?? bikeBrand,
      bikeModel: active?.model ?? bikeModel,
      bikeYear: active?.year ?? bikeYear,
      bikeColor: active?.color ?? bikeColor,
      bikePlate: active?.plate ?? bikePlate,
    );
    return _remote.saveProfile(updated);
  }

  @override
  Future<void> changePassword({
    required String currentPassword,
    required String newPassword,
  }) async {
    final firebaseUser = _remote.currentFirebaseUser;
    if (firebaseUser == null) {
      throw const AuthException('No hay sesión activa.');
    }
    AppUser current = _remote.userFromFirebase(firebaseUser);
    try {
      current = await _remote.fetchUser(firebaseUser.uid) ?? current;
    } catch (_) {}
    if (current.isUsernameAccount) {
      final username = current.username ?? current.displayName;
      await _remote.changeUsernamePassword(
        username: username,
        currentPassword: currentPassword,
        newPassword: newPassword,
      );
      return;
    }
    if (current.provider != AuthProviderType.email) {
      throw const AuthException(
        'Esta cuenta no usa contraseña. Entras con Google.',
      );
    }
    await _remote.changeEmailPassword(
      currentPassword: currentPassword,
      newPassword: newPassword,
    );
  }

  @override
  Stream<AppUser?> watchUser(String uid) async* {
    try {
      await for (final stored in _remote.watchUser(uid)) {
        yield stored;
      }
    } catch (_) {
      yield null;
    }
  }

  @override
  Future<void> signOut() => _remote.signOut();

  Future<AppUser> _saveProfile(AppUser user) async {
    try {
      return await _remote.upsertUser(user);
    } on AuthException {
      return user;
    }
  }
}
