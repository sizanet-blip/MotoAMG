import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:moto_amg/core/theme/hub_style.dart';
import 'package:moto_amg/features/auth/domain/entities/app_user.dart';
import 'package:moto_amg/features/auth/presentation/providers/auth_providers.dart';
import 'package:moto_amg/features/clubs/domain/entities/moto_club.dart';
import 'package:moto_amg/features/clubs/presentation/providers/club_providers.dart';
import 'package:moto_amg/features/groups/presentation/providers/group_providers.dart';

class ClubPendingScreen extends ConsumerStatefulWidget {
  const ClubPendingScreen({super.key, required this.user});

  final AppUser user;

  @override
  ConsumerState<ClubPendingScreen> createState() => _ClubPendingScreenState();
}

class _ClubPendingScreenState extends ConsumerState<ClubPendingScreen> {
  var _activating = false;
  var _busyDismiss = false;
  String? _activateError;

  Future<void> _activateApproved(String clubId) async {
    if (_activating) {
      return;
    }
    setState(() {
      _activating = true;
      _activateError = null;
    });
    try {
      await ref.read(clubRemoteDataSourceProvider).setActiveClub(
            uid: widget.user.uid,
            clubId: clubId,
          );
      await ref
          .read(clubRemoteDataSourceProvider)
          .clearPendingRequest(widget.user.uid);
      final local = ref.read(signedInUserProvider);
      if (local != null && local.uid == widget.user.uid) {
        ref.read(signedInUserProvider.notifier).state = local.copyWith(
          currentClubId: clubId,
          clearPendingClubRequestId: true,
        );
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _activating = false;
          _activateError =
              'No se pudo activar el club. Comprueba la conexión e inténtalo.';
        });
      }
    }
  }

  Future<void> _dismissRejected(String requestId) async {
    if (_busyDismiss) {
      return;
    }
    setState(() => _busyDismiss = true);
    // Sale ya del gate aunque Firestore tarde en borrar el pending.
    ref.read(dismissedPendingClubRequestIdProvider.notifier).state = requestId;
    final local = ref.read(signedInUserProvider);
    if (local != null && local.uid == widget.user.uid) {
      ref.read(signedInUserProvider.notifier).state = local.copyWith(
        clearPendingClubRequestId: true,
      );
    }
    try {
      await ref
          .read(clubRemoteDataSourceProvider)
          .clearPendingRequest(widget.user.uid);
    } catch (_) {
      if (!mounted) {
        return;
      }
      ref.read(dismissedPendingClubRequestIdProvider.notifier).state = null;
      setState(() => _busyDismiss = false);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('No se pudo cerrar la solicitud. Inténtalo otra vez.'),
        ),
      );
    }
  }

  void _syncFromLiveUser(AppUser? live) {
    if (live == null || live.uid != widget.user.uid) {
      return;
    }
    final local = ref.read(signedInUserProvider);
    if (local == null || local.uid != live.uid) {
      return;
    }
    final liveHasClub =
        live.currentClubId != null && live.currentClubId!.trim().isNotEmpty;
    final liveHasPending = live.pendingClubRequestId != null &&
        live.pendingClubRequestId!.trim().isNotEmpty;
    if (liveHasClub && !liveHasPending) {
      if (local.currentClubId != live.currentClubId ||
          local.hasPendingClubRequest) {
        ref.read(signedInUserProvider.notifier).state = local.copyWith(
          currentClubId: live.currentClubId,
          clearPendingClubRequestId: true,
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final requestAsync = ref.watch(pendingClubRequestProvider);
    final liveAsync = ref.watch(liveUserProvider(widget.user.uid));
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final errorColor = Theme.of(context).colorScheme.error;

    ref.listen(liveUserProvider(widget.user.uid), (previous, next) {
      next.whenData(_syncFromLiveUser);
    });
    liveAsync.whenData(_syncFromLiveUser);

    // Si el panel ya puso el club en el usuario, AuthGate saldrá solo.
    if (widget.user.isInClub && !widget.user.hasPendingClubRequest) {
      return Scaffold(
        backgroundColor: isDark ? null : HubStyle.surface,
        body: const Center(child: CircularProgressIndicator()),
      );
    }

    return Scaffold(
      backgroundColor: isDark ? null : HubStyle.surface,
      appBar: HubStyle.appBar(
        titleText: 'Pendiente de aprobación',
        automaticallyImplyLeading: false,
        actions: [
          IconButton(
            tooltip: 'Cerrar sesión',
            onPressed: () =>
                ref.read(authActionControllerProvider.notifier).signOut(),
            icon: const Icon(Icons.logout_rounded),
          ),
        ],
      ),
      body: requestAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Text('Error: $e', style: HubStyle.body()),
          ),
        ),
        data: (request) {
          if (request == null) {
            return _CenteredMessage(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const CircularProgressIndicator(color: HubStyle.accent),
                  const SizedBox(height: 20),
                  Text(
                    'Actualizando estado de tu solicitud…',
                    textAlign: TextAlign.center,
                    style: HubStyle.body(),
                  ),
                ],
              ),
            );
          }
          if (request.status == ClubJoinRequestStatus.approved &&
              request.resultingClubId != null) {
            final clubId = request.resultingClubId!;
            if (!_activating && _activateError == null) {
              WidgetsBinding.instance.addPostFrameCallback((_) {
                _activateApproved(clubId);
              });
            }
            if (_activateError != null) {
              return _CenteredMessage(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.error_outline, size: 56, color: errorColor),
                    const SizedBox(height: 16),
                    Text(
                      _activateError!,
                      textAlign: TextAlign.center,
                      style: HubStyle.body(color: HubStyle.title),
                    ),
                    const SizedBox(height: 20),
                    FilledButton(
                      onPressed: () => _activateApproved(clubId),
                      style: HubStyle.filledButtonStyle(),
                      child: const Text('Reintentar'),
                    ),
                  ],
                ),
              );
            }
            return _CenteredMessage(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const CircularProgressIndicator(color: HubStyle.accent),
                  const SizedBox(height: 20),
                  Text(
                    'Club aprobado. Activando…',
                    textAlign: TextAlign.center,
                    style: HubStyle.body(),
                  ),
                ],
              ),
            );
          }
          if (request.status == ClubJoinRequestStatus.rejected) {
            return _CenteredMessage(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.cancel_outlined, size: 56, color: errorColor),
                  const SizedBox(height: 20),
                  Text(
                    'Solicitud no aprobada',
                    textAlign: TextAlign.center,
                    style: HubStyle.sectionTitle(),
                  ),
                  if (request.reviewNote != null &&
                      request.reviewNote!.trim().isNotEmpty) ...[
                    const SizedBox(height: 12),
                    Text(
                      request.reviewNote!,
                      textAlign: TextAlign.center,
                      style: HubStyle.body(),
                    ),
                  ],
                  const SizedBox(height: 28),
                  FilledButton(
                    onPressed: _busyDismiss
                        ? null
                        : () => _dismissRejected(request.id),
                    style: HubStyle.filledButtonStyle(enabled: !_busyDismiss),
                    child: _busyDismiss
                        ? const SizedBox(
                            width: 22,
                            height: 22,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              color: Colors.white,
                            ),
                          )
                        : const Text('Volver a intentar'),
                  ),
                ],
              ),
            );
          }
          return _CenteredMessage(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  width: 72,
                  height: 72,
                  decoration: const BoxDecoration(
                    color: HubStyle.accent,
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(
                    Icons.hourglass_top_rounded,
                    size: 36,
                    color: Colors.white,
                  ),
                ),
                const SizedBox(height: 20),
                Text(
                  'Pendiente de aprobación',
                  textAlign: TextAlign.center,
                  style: HubStyle.sectionTitle(),
                ),
                const SizedBox(height: 12),
                Text(
                  'Tu peña «${request.clubName}» está en revisión.',
                  textAlign: TextAlign.center,
                  style: HubStyle.body(),
                ),
              ],
            ),
          );
        },
      ),
    );
  }
}

class _CenteredMessage extends StatelessWidget {
  const _CenteredMessage({required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        return SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 24),
          child: ConstrainedBox(
            constraints: BoxConstraints(minHeight: constraints.maxHeight - 48),
            child: Center(child: child),
          ),
        );
      },
    );
  }
}
