import 'dart:async';

import 'package:moto_amg/core/api/motoamg_api_client.dart';
import 'package:moto_amg/core/constants/app_constants.dart';
import 'package:moto_amg/features/auth/data/datasources/google_auth_datasource.dart';
import 'package:moto_amg/features/auth/data/datasources/mysql_auth_remote_datasource.dart';
import 'package:moto_amg/features/auth/domain/entities/app_user.dart';
import 'package:moto_amg/features/auth/domain/entities/user_vehicle.dart';
import 'package:moto_amg/features/auth/domain/entities/username_registration.dart';
import 'package:moto_amg/features/auth/domain/exceptions/auth_exceptions.dart';
import 'package:moto_amg/features/auth/domain/repositories/auth_repository.dart';

class MysqlAuthRepositoryImpl implements AuthRepository {
  MysqlAuthRepositoryImpl(this._remote);

  final MysqlAuthRemoteDataSource _remote;

  final _controller = StreamController<AppUser?>.broadcast();
  AppUser? _current;
  Future<AppUser?>? _restoreFuture;
  var _restoreStarted = false;

  AppUser? get currentUser => _current;

  void _emit(AppUser? user) {
    _current = user;
    if (!_controller.isClosed) {
      _controller.add(user);
    }
  }

  Future<AppUser?> ensureSessionRestored() {
    _restoreFuture ??= _remote.restoreSession().then((user) {
      _current = user;
      return user;
    });
    return _restoreFuture!;
  }

  AuthException _mapError(Object error) {
    if (error is AuthException) return error;
    if (error is MotoAmgApiException) {
      return AuthException(error.message);
    }
    return AuthException(error.toString());
  }

  Never _unsupported() {
    throw const AuthException('Usa usuario y contraseña (MySQL)');
  }

  @override
  Stream<AppUser?> watchCurrentUser() async* {
    if (!_restoreStarted) {
      _restoreStarted = true;
      final restored = await ensureSessionRestored();
      yield restored;
    } else {
      yield _current;
    }
    yield* _controller.stream;
  }

  @override
  Future<AppUser> signInWithUsername({
    required String username,
    required String password,
  }) async {
    try {
      final user = await _remote.login(
        username: username.trim(),
        password: password,
      );
      _restoreFuture = Future.value(user);
      _emit(user);
      return user;
    } catch (e) {
      throw _mapError(e);
    }
  }

  @override
  Future<AppUser> signInWithEmail({
    required String email,
    required String password,
  }) async {
    try {
      final user = await _remote.login(
        username: email.trim().toLowerCase(),
        password: password,
      );
      _restoreFuture = Future.value(user);
      _emit(user);
      return user;
    } catch (e) {
      throw _mapError(e);
    }
  }

  @override
  Future<UsernameRegistration> registerWithUsername({
    required String username,
    required String password,
  }) async {
    try {
      final trimmed = username.trim();
      final user = await _remote.register(
        username: trimmed,
        password: password,
        displayName: trimmed,
      );
      _restoreFuture = Future.value(user);
      _emit(user);
      // MySQL no usa clave de recuperación Firebase.
      return UsernameRegistration(user: user, recoveryKey: '');
    } catch (e) {
      throw _mapError(e);
    }
  }

  @override
  Future<AppUser> registerWithEmail({
    required String email,
    required String password,
    required String displayName,
  }) async {
    try {
      final mail = email.trim().toLowerCase();
      final name = displayName.trim().isEmpty ? mail.split('@').first : displayName.trim();
      final username = mail.contains('@') ? mail.split('@').first : mail;
      final user = await _remote.register(
        username: username,
        password: password,
        displayName: name,
        email: mail,
      );
      _restoreFuture = Future.value(user);
      _emit(user);
      return user;
    } catch (e) {
      throw _mapError(e);
    }
  }

  @override
  Future<void> signOut() async {
    // Emitir null antes de borrar Hive para que el stream no deje el user viejo.
    _emit(null);
    _restoreFuture = Future.value(null);
    try {
      await GoogleAuthDataSource().signOut();
    } catch (_) {}
    await _remote.signOut();
  }

  Future<AppUser> _googleAuth({required String mode}) async {
    try {
      final tokens = await GoogleAuthDataSource().signIn();
      var appUser = await _remote.loginWithGoogle(
        idToken: tokens.idToken,
        mode: mode,
        email: tokens.email,
        googleUserId: tokens.googleUserId,
      );
      final token = await _remote.sessionToken;
      if (token != null && token.isNotEmpty) {
        _remote.bindAccessToken(token);
      }
      // En registro ya aceptó políticas antes; quedará guardado en la cuenta.
      if (mode == 'register') {
        appUser = await acceptPrivacyLocal(appUser);
      }
      _restoreFuture = Future.value(appUser);
      _emit(appUser);
      return appUser;
    } on AuthCancelledException {
      rethrow;
    } catch (e) {
      throw _mapError(e);
    }
  }

  @override
  Future<AppUser> signInWithGoogle() => _googleAuth(mode: 'login');

  @override
  Future<AppUser> registerWithGoogle() => _googleAuth(mode: 'register');

  @override
  Future<AppUser> signInAnonymously({required String displayName}) async {
    try {
      final appUser = await _remote.loginAsGuest(
        displayName: displayName.trim(),
      );
      _restoreFuture = Future.value(appUser);
      _emit(appUser);
      return appUser;
    } catch (e) {
      throw _mapError(e);
    }
  }

  @override
  Future<void> sendPasswordReset(String email) async => _unsupported();

  @override
  Future<AppUser> recoverUsernamePassword({
    required String username,
    required String recoveryKey,
    required String newPassword,
  }) async =>
      _unsupported();

  @override
  Future<String> revealRecoveryKey({
    required String username,
    required String password,
  }) async =>
      _unsupported();

  @override
  Future<void> changePassword({
    required String currentPassword,
    required String newPassword,
  }) async =>
      _unsupported();

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
  }) async =>
      _unsupported();

  @override
  Future<AppUser> updateDisplayName(String displayName) async {
    final current = _current;
    if (current == null) {
      throw const AuthException('No hay sesión activa.');
    }
    final updated = current.copyWith(displayName: displayName.trim());
    await _remote.persistLocalUser(updated);
    _emit(updated);
    return updated;
  }

  @override
  Future<AppUser> acceptPrivacyPolicy() async {
    var current = _current;
    if (current == null) {
      current = await ensureSessionRestored();
    }
    if (current == null) {
      throw const AuthException('No hay sesión activa.');
    }
    final updated = current.copyWith(
      privacyAcceptedAt: DateTime.now(),
      privacyAcceptedVersion: AppConstants.privacyPolicyVersion,
    );
    await _remote.persistLocalUser(updated);
    _emit(updated);
    return updated;
  }

  @override
  Stream<AppUser?> watchUser(String uid) async* {
    final local = _current;
    if (local != null && local.uid == uid) {
      yield local;
    }
    try {
      final me = await _remote.fetchMe();
      if (me != null && me.uid == uid) {
        _emit(me);
        yield me;
        return;
      }
    } catch (_) {}
    yield local != null && local.uid == uid ? local : null;
  }

  /// Actualiza sesión local (Hive + memoria). [seed] si `_current` aún es null.
  Future<AppUser> patchLocalUser(
    AppUser Function(AppUser current) transform, {
    AppUser? seed,
  }) async {
    var current = _current;
    if (current == null && seed != null) {
      current = seed;
    }
    current ??= await ensureSessionRestored();
    if (current == null && seed != null) {
      current = seed;
    }
    if (current == null) {
      throw const AuthException('No hay sesión activa.');
    }
    final base =
        (seed != null && seed.uid == current.uid) ? seed : current;
    final updated = transform(base);
    await _remote.persistLocalUser(updated);
    _emit(updated);
    return updated;
  }

  /// Aceptar privacidad sin exigir JWT (Gmail a veces llega sin token en memoria).
  Future<AppUser> acceptPrivacyLocal(AppUser seed) async {
    final alsoUid = GoogleAuthDataSource().currentGoogleUserId;
    final updated = await _remote.acceptPrivacy(seed, alsoUid: alsoUid);
    _emit(updated);
    return updated;
  }
}
