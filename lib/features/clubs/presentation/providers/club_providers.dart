import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:moto_amg/features/auth/presentation/providers/auth_providers.dart';
import 'package:moto_amg/features/clubs/data/datasources/club_remote_datasource.dart';
import 'package:moto_amg/features/clubs/domain/entities/moto_club.dart';

final clubRemoteDataSourceProvider = Provider<ClubRemoteDataSource>((ref) {
  return ClubRemoteDataSource();
});

/// Tras «Volver a intentar» en una solicitud rechazada: el pending remoto
/// puede tardar en borrarse; este id evita quedarse atrapado en la pantalla.
final dismissedPendingClubRequestIdProvider = StateProvider<String?>((ref) => null);

/// Solo reacciona al uid (no a cada cambio de currentClubId / nombre),
/// para no reiniciar el stream y hacer parpadear el home.
final myClubMembershipsProvider =
    StreamProvider.autoDispose<List<MotoClubMembership>>((ref) {
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
    return Stream.value(const []);
  }
  return ref.watch(clubRemoteDataSourceProvider).watchMemberships(uid);
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
  final remoteClubId = ref.watch(
    authStateProvider.select((async) => async.asData?.value?.currentClubId),
  );
  // Misma regla que resolveSessionUser.
  final id = (remoteRequestId != null && remoteRequestId.isNotEmpty)
      ? remoteRequestId
      : ((remoteClubId != null && remoteClubId.isNotEmpty)
          ? null
          : requestId);
  if (id == null || id.isEmpty) {
    return Stream.value(null);
  }
  return ref.watch(clubRemoteDataSourceProvider).watchRequest(id);
});
