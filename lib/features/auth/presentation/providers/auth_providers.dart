import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:moto_amg/core/api/motoamg_api_client.dart';
import 'package:moto_amg/core/constants/app_constants.dart';
import 'package:moto_amg/features/auth/data/datasources/mysql_auth_remote_datasource.dart';
import 'package:moto_amg/features/auth/data/repositories/mysql_auth_repository_impl.dart';
import 'package:moto_amg/features/auth/domain/entities/app_user.dart';
import 'package:moto_amg/features/auth/domain/entities/user_vehicle.dart';
import 'package:moto_amg/features/auth/domain/exceptions/auth_exceptions.dart';
import 'package:moto_amg/features/auth/domain/repositories/auth_repository.dart';
import 'package:moto_amg/features/auth/presentation/providers/home_landing_provider.dart';
import 'package:moto_amg/features/tracking/presentation/providers/tracking_providers.dart';

final mysqlAuthSessionStoreProvider = Provider<MysqlAuthSessionStore>((ref) {
  ref.keepAlive();
  return MysqlAuthSessionStore();
});

final motoAmgApiClientProvider = Provider<MotoAmgApiClient>((ref) {
  ref.keepAlive();
  // read (no watch): un solo cliente; si se recrea, se pierde el JWT en memoria.
  final session = ref.read(mysqlAuthSessionStoreProvider);
  return MotoAmgApiClient(tokenResolver: session.readToken);
});

final mysqlAuthRemoteDataSourceProvider =
    Provider<MysqlAuthRemoteDataSource>((ref) {
  ref.keepAlive();
  return MysqlAuthRemoteDataSource(
    ref.read(motoAmgApiClientProvider),
    ref.read(mysqlAuthSessionStoreProvider),
  );
});

final authRepositoryProvider = Provider<AuthRepository>((ref) {
  ref.keepAlive();
  return MysqlAuthRepositoryImpl(ref.read(mysqlAuthRemoteDataSourceProvider));
});

/// Tras "Cerrar sesión" queda en true hasta el próximo login exitoso.
/// Evita que bootstrap/remote resuciten la sesión (carrera → home).
final authLoggedOutProvider = StateProvider<bool>((ref) => false);

/// Restaura JWT/Hive al arrancar y rellena [signedInUserProvider].
final authSessionBootstrapProvider = FutureProvider<AppUser?>((ref) async {
  final repo = ref.watch(authRepositoryProvider);
  if (repo is! MysqlAuthRepositoryImpl) return null;
  if (ref.read(authLoggedOutProvider)) return null;
  final user = await repo.ensureSessionRestored();
  if (user != null) {
    // Evitar mutar providers durante el build del FutureProvider.
    Future.microtask(() {
      if (ref.read(authLoggedOutProvider)) return;
      final local = ref.read(signedInUserProvider);
      // No pisar una sesión distinta; si local es null, hidratar al arranque.
      if (local == null) {
        ref.read(signedInUserProvider.notifier).state = user;
      } else if (local.uid == user.uid) {
        ref.read(signedInUserProvider.notifier).state = user;
      }
    });
  }
  return user;
});

final authStateProvider = StreamProvider<AppUser?>((ref) {
  // Dispara restore en paralelo al stream.
  ref.watch(authSessionBootstrapProvider);
  return ref.watch(authRepositoryProvider).watchCurrentUser();
});

/// Usuario con nombre ya confirmado en esta sesión.
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

  Future<void> registerWithGoogle() {
    return _run(() => _repo.registerWithGoogle());
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
    return _run(() async {
      final user = await _repo.registerWithEmail(
        email: email,
        password: password,
        displayName: displayName,
      );
      final repo = _repo;
      if (repo is MysqlAuthRepositoryImpl) {
        return repo.acceptPrivacyLocal(user);
      }
      return user;
    });
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
      final key = result.recoveryKey.trim();
      ref.read(pendingRecoveryKeyProvider.notifier).state =
          key.isEmpty ? null : key;
      final repo = _repo;
      if (repo is MysqlAuthRepositoryImpl) {
        return repo.acceptPrivacyLocal(result.user);
      }
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
    return _run(() async {
      final local = ref.read(signedInUserProvider);
      final remote = ref.read(authStateProvider).asData?.value;
      final session = resolveSessionUser(local, remote);
      final repo = _repo;
      if (repo is MysqlAuthRepositoryImpl) {
        final seed = session ?? local ?? remote;
        if (seed == null) {
          throw const AuthException('No hay sesión activa.');
        }
        return repo.patchLocalUser(
          (current) => current.copyWith(
            privacyAcceptedAt: DateTime.now(),
            privacyAcceptedVersion: AppConstants.privacyPolicyVersion,
          ),
          seed: seed,
        );
      }
      return repo.acceptPrivacyPolicy();
    });
  }

  Future<void> signOut() {
    return _run(() async {
      // Primero el pestillo: AuthGate deja de confiar en bootstrap/remote.
      ref.read(authLoggedOutProvider.notifier).state = true;
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
      ref.read(signedInUserProvider.notifier).state = null;
      ref.read(pendingRecoveryKeyProvider.notifier).state = null;
      ref.read(homeLandingSectionProvider.notifier).state =
          HomeLandingSection.hub;
      ref.invalidate(groupLocationsProvider);
      ref.invalidate(ownDevicePositionProvider);
      ref.invalidate(ownGpsLostProvider);
      await _repo.signOut();
      ref.invalidate(authStateProvider);
      ref.invalidate(authSessionBootstrapProvider);
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
        ref.read(authLoggedOutProvider.notifier).state = true;
      } else if (user != null) {
        ref.read(authLoggedOutProvider.notifier).state = false;
        final previous = ref.read(signedInUserProvider);
        if (user.displayName.trim().isNotEmpty ||
            previous == null ||
            previous.uid == user.uid) {
          ref.read(signedInUserProvider.notifier).state = user;
        }
      }
      // No invalidar authState: provoca loading/carreras y pantallas pilladas.
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
    final remotePending = remote.pendingClubRequestId;
    final remoteHasPending =
        remotePending != null && remotePending.trim().isNotEmpty;
    final remoteHasClub = remote.currentClubId != null &&
        remote.currentClubId!.trim().isNotEmpty;
    final localHasPending = local.pendingClubRequestId != null &&
        local.pendingClubRequestId!.trim().isNotEmpty;
    final localHasClub = local.currentClubId != null &&
        local.currentClubId!.trim().isNotEmpty;

    // Si la app ya activó el club y limpió el pending, no resucitar el pending remoto.
    // Si aún hay pending local (p. ej. mostrar código tras aprobar), conservarlo
    // aunque el panel ya haya puesto current_club_id.
    final pendingClubRequestId = (localHasClub && !localHasPending)
        ? null
        : (remoteHasPending
            ? remotePending
            : (localHasPending
                ? local.pendingClubRequestId
                : (remoteHasClub ? null : local.pendingClubRequestId)));

    return AppUser(
      uid: local.uid,
      displayName: local.displayName,
      createdAt: remote.createdAt,
      provider: local.provider,
      phoneNumber: remote.phoneNumber ?? local.phoneNumber,
      email: remote.email ?? local.email,
      username: remote.username ?? local.username,
      photoUrl: remote.photoUrl ?? local.photoUrl,
      currentGroupId: remote.currentGroupId ?? local.currentGroupId,
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
      // Privacidad vive en el dispositivo/sesión: no dejar que /me la borre.
      privacyAcceptedAt: local.privacyAcceptedAt ?? remote.privacyAcceptedAt,
      privacyAcceptedVersion: () {
        final localVer = local.privacyAcceptedVersion?.trim() ?? '';
        if (localVer.isNotEmpty) return local.privacyAcceptedVersion;
        return remote.privacyAcceptedVersion;
      }(),
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
