import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:moto_amg/features/auth/data/datasources/auth_remote_datasource.dart';
import 'package:moto_amg/features/auth/data/repositories/auth_repository_impl.dart';
import 'package:moto_amg/features/auth/domain/entities/app_user.dart';
import 'package:moto_amg/features/auth/domain/entities/user_vehicle.dart';
import 'package:moto_amg/features/auth/domain/exceptions/auth_exceptions.dart';
import 'package:moto_amg/features/auth/domain/repositories/auth_repository.dart';
import 'package:moto_amg/features/auth/presentation/providers/home_landing_provider.dart';
import 'package:moto_amg/features/tracking/presentation/providers/tracking_providers.dart';

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
    List<UserVehicle>? vehicles,
    String? activeVehicleId,
    bool clearActiveVehicleId = false,
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
        vehicles: vehicles,
        activeVehicleId: activeVehicleId,
        clearActiveVehicleId: clearActiveVehicleId,
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

  Future<void> acceptPrivacyPolicy() {
    return _run(() => _repo.acceptPrivacyPolicy());
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
      ref.read(homeLandingSectionProvider.notifier).state =
          HomeLandingSection.hub;
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
      } else if (user != null) {
        // Mantener sesión local también sin displayName (p. ej. tras aceptar
        // privacidad) para que AuthGate no pierda el progreso.
        final previous = ref.read(signedInUserProvider);
        if (user.displayName.trim().isNotEmpty ||
            previous == null ||
            previous.uid == user.uid) {
          ref.read(signedInUserProvider.notifier).state = user;
        }
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
  if (local != null &&
      remote != null &&
      local.uid == remote.uid &&
      !local.needsDisplayName) {
    // El StateProvider local evita el flash del nombre, pero los campos de
    // peña/grupo deben seguir el documento de Firestore.
    final remotePending = remote.pendingClubRequestId;
    final remoteHasPending =
        remotePending != null && remotePending.trim().isNotEmpty;
    final remoteHasClub = remote.currentClubId != null &&
        remote.currentClubId!.trim().isNotEmpty;
    // Si el panel (o la app) ya asignó club y borró el pending en Firestore,
    // no reinyectar un pending local antiguo.
    final pendingClubRequestId = remoteHasPending
        ? remotePending
        : (remoteHasClub ? null : local.pendingClubRequestId);

    return AppUser(
      uid: local.uid,
      displayName: local.displayName,
      createdAt: remote.createdAt,
      provider: local.provider,
      phoneNumber: remote.phoneNumber ?? local.phoneNumber,
      email: remote.email ?? local.email,
      username: remote.username ?? local.username,
      photoUrl: remote.photoUrl ?? local.photoUrl,
      currentGroupId: remote.currentGroupId,
      currentClubId: remote.currentClubId ?? local.currentClubId,
      pendingClubRequestId: pendingClubRequestId,
      allowSoloNavigation: remote.allowSoloNavigation,
      bikeBrand: remote.bikeBrand ?? local.bikeBrand,
      bikeModel: remote.bikeModel ?? local.bikeModel,
      bikeYear: remote.bikeYear ?? local.bikeYear,
      bikeColor: remote.bikeColor ?? local.bikeColor,
      bikePlate: remote.bikePlate ?? local.bikePlate,
      vehicles: remote.vehicles.isNotEmpty ? remote.vehicles : local.vehicles,
      activeVehicleId: remote.activeVehicleId ?? local.activeVehicleId,
      privacyAcceptedAt: remote.privacyAcceptedAt ?? local.privacyAcceptedAt,
      privacyAcceptedVersion:
          remote.privacyAcceptedVersion ?? local.privacyAcceptedVersion,
    );
  }
  if (local != null && !local.needsDisplayName) {
    return local;
  }
  if (remote != null && !remote.needsDisplayName) {
    return remote;
  }
  return local ?? remote;
}
