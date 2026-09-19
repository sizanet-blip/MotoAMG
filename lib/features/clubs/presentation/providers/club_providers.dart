import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:moto_amg/features/auth/data/datasources/mysql_club_group_remote_datasource.dart';
import 'package:moto_amg/features/auth/presentation/providers/auth_providers.dart';
import 'package:moto_amg/features/clubs/domain/entities/moto_club.dart';

final clubRemoteDataSourceProvider = Provider<MysqlClubRemoteDataSource>((ref) {
  ref.keepAlive();
  // Un solo cliente API con JWT; no recrear al completar el bootstrap.
  return MysqlClubRemoteDataSource(ref.read(motoAmgApiClientProvider));
});

/// Tras «Volver a intentar» en una solicitud rechazada: el pending remoto
/// puede tardar en borrarse; este id evita quedarse atrapado en la pantalla.
final dismissedPendingClubRequestIdProvider = StateProvider<String?>((ref) => null);

/// Solo reacciona al uid (no a cada cambio de currentClubId / nombre),
/// para no reiniciar el stream y hacer parpadear el home.
final myClubMembershipsProvider =
    StreamProvider.autoDispose<List<MotoClubMembership>>((ref) async* {
  // Esperar restore de sesión antes del primer GET autenticado.
  try {
    await ref.watch(authSessionBootstrapProvider.future);
  } catch (_) {}

  final localUid = ref.watch(signedInUserProvider.select((u) => u?.uid));
  final localAnon = ref.watch(
    signedInUserProvider.select((u) => u?.isAnonymous ?? false),
  );
  final remoteUid = ref.watch(
    authStateProvider.select((async) => async.asData?.value?.uid),
  );
  final remoteAnon = ref.watch(
    authStateProvider.select(
      (async) => async.asData?.value?.isAnonymous ?? false,
    ),
  );

  final uid = localUid ?? remoteUid;
  final anonymous = localUid != null ? localAnon : remoteAnon;
  if (uid == null || anonymous) {
    yield const [];
    return;
  }
  yield* ref.watch(clubRemoteDataSourceProvider).watchMemberships(uid);
});

final pendingClubRequestProvider =
    StreamProvider.autoDispose<ClubJoinRequest?>((ref) {
  final requestId = ref.watch(
    signedInUserProvider.select((u) => u?.pendingClubRequestId),
  );
  final remoteRequestId = ref.watch(
    authStateProvider.select(
      (async) => async.asData?.value?.pendingClubRequestId,
    ),
  );
  // Preferir pending local: tras aprobar el panel quita el pending remoto
  // pero la app lo conserva hasta mostrar el código de invitación.
  final id = (requestId != null && requestId.isNotEmpty)
      ? requestId
      : ((remoteRequestId != null && remoteRequestId.isNotEmpty)
          ? remoteRequestId
          : null);
  if (id == null || id.isEmpty) {
    return Stream.value(null);
  }
  return ref.watch(clubRemoteDataSourceProvider).watchRequest(id);
});
