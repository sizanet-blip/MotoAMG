import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:loc_motos/features/auth/data/datasources/auth_remote_datasource.dart';
import 'package:loc_motos/features/auth/data/repositories/auth_repository_impl.dart';
import 'package:loc_motos/features/auth/domain/entities/app_user.dart';
import 'package:loc_motos/features/auth/domain/exceptions/auth_exceptions.dart';
import 'package:loc_motos/features/auth/domain/repositories/auth_repository.dart';
import 'package:loc_motos/features/tracking/presentation/providers/tracking_providers.dart';

final authRepositoryProvider = Provider<AuthRepository>((ref) {
  return AuthRepositoryImpl(AuthRemoteDataSource());
});

final authStateProvider = StreamProvider<AppUser?>((ref) {
  return ref.watch(authRepositoryProvider).watchCurrentUser();
});

/// Usuario con nombre ya confirmado en esta sesión (evita quedarse en la
/// pantalla de nombre si Firebase tarda en devolver el perfil).
final signedInUserProvider = StateProvider<AppUser?>((ref) => null);

/// Clave de recuperación pendiente de mostrar (solo al crear cuenta con usuario).
final pendingRecoveryKeyProvider = StateProvider<String?>((ref) => null);

final authActionControllerProvider =
    NotifierProvider<AuthActionController, AsyncValue<void>>(
      AuthActionController.new,
    );

class AuthActionController extends Notifier<AsyncValue<void>> {
  @override
  AsyncValue<void> build() => const AsyncData(null);

  AuthRepository get _repo => ref.read(authRepositoryProvider);

  Future<void> signInWithGoogle() {
    return _run(() => _repo.signInWithGoogle());
  }

  Future<void> signInWithEmail({
    required String email,
    required String password,
  }) {
    return _run(() => _repo.signInWithEmail(email: email, password: password));
  }

  Future<void> signInWithIdentifier({
    required String identifier,
    required String password,
  }) {
    final trimmed = identifier.trim();
    if (trimmed.contains('@')) {
      return signInWithEmail(email: trimmed, password: password);
    }
    return signInWithUsername(username: trimmed, password: password);
  }

  Future<void> signInWithUsername({
    required String username,
    required String password,
  }) {
    return _run(
      () => _repo.signInWithUsername(username: username, password: password),
    );
  }

  Future<void> registerWithEmail({
    required String email,
    required String password,
    required String displayName,
  }) {
    return _run(
      () => _repo.registerWithEmail(
        email: email,
        password: password,
        displayName: displayName,
      ),
    );
  }

  Future<void> registerWithUsername({
    required String username,
    required String password,
  }) {
    return _run(() async {
      final result = await _repo.registerWithUsername(
        username: username,
        password: password,
      );
      ref.read(pendingRecoveryKeyProvider.notifier).state = result.recoveryKey;
      return result.user;
    });
  }

  Future<void> sendPasswordReset(String email) {
    return _run(() async {
      await _repo.sendPasswordReset(email);
      return null;
    });
  }

  Future<void> recoverUsernamePassword({
    required String username,
    required String recoveryKey,
    required String newPassword,
  }) {
    return _run(
      () => _repo.recoverUsernamePassword(
        username: username,
        recoveryKey: recoveryKey,
        newPassword: newPassword,
      ),
    );
  }

  Future<String> revealRecoveryKey({
    required String username,
    required String password,
  }) {
    return _repo.revealRecoveryKey(username: username, password: password);
  }

  Future<void> signInAnonymously({required String displayName}) {
    return _run(() => _repo.signInAnonymously(displayName: displayName));
  }

  Future<void> updateDisplayName(String displayName) {
    return _run(() => _repo.updateDisplayName(displayName));
  }

  Future<void> updateProfile({
    required String displayName,
    String? phoneNumber,
    String? bikeBrand,
    String? bikeModel,
    String? bikeYear,
    String? bikeColor,
    String? bikePlate,
  }) {
    return _run(
      () => _repo.updateProfile(
        displayName: displayName,
        phoneNumber: phoneNumber,
        bikeBrand: bikeBrand,
        bikeModel: bikeModel,
        bikeYear: bikeYear,
        bikeColor: bikeColor,
        bikePlate: bikePlate,
      ),
    );
  }

  Future<void> changePassword({
    required String currentPassword,
    required String newPassword,
  }) {
    return _run(() async {
      await _repo.changePassword(
        currentPassword: currentPassword,
        newPassword: newPassword,
      );
      return ref.read(signedInUserProvider);
    });
  }

  Future<void> signOut() {
    return _run(() async {
      final current = ref.read(signedInUserProvider);
      final groupId = current?.currentGroupId;
      if (current != null && groupId != null && groupId.isNotEmpty) {
        try {
          await ref.read(locationRepositoryProvider).clearLocation(
            groupId: groupId,
            uid: current.uid,
          );
        } catch (_) {}
      }
      // Quitar la pantalla del grupo *antes* de cerrar Firebase. Si no,
      // Firestore emite permission-denied y el stream se queda roto.
      ref.read(signedInUserProvider.notifier).state = null;
      ref.read(pendingRecoveryKeyProvider.notifier).state = null;
      ref.invalidate(groupLocationsProvider);
      ref.invalidate(ownDevicePositionProvider);
      ref.invalidate(ownGpsLostProvider);
      await _repo.signOut();
      return null;
    }, clearUser: true);
  }

  Future<void> _run(
    Future<AppUser?> Function() action, {
    bool clearUser = false,
  }) async {
    state = const AsyncLoading();
    try {
      final user = await action();
      if (clearUser) {
        ref.read(signedInUserProvider.notifier).state = null;
      } else if (user != null && user.displayName.trim().isNotEmpty) {
        ref.read(signedInUserProvider.notifier).state = user;
      }
      ref.invalidate(authStateProvider);
      state = const AsyncData(null);
    } on AuthCancelledException {
      state = const AsyncData(null);
    } on AuthException catch (error, stackTrace) {
      state = AsyncError(error, stackTrace);
    } catch (error, stackTrace) {
      state = AsyncError(AuthException(error.toString()), stackTrace);
    }
  }
}

AppUser? resolveSessionUser(AppUser? local, AppUser? remote) {
  if (local != null && !local.needsDisplayName) {
    return local;
  }
  if (remote != null && !remote.needsDisplayName) {
    return remote;
  }
  return local ?? remote;
}
