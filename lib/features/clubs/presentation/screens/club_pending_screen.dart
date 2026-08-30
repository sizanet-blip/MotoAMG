import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:loc_motos/features/auth/domain/entities/app_user.dart';
import 'package:loc_motos/features/auth/presentation/providers/auth_providers.dart';
import 'package:loc_motos/features/clubs/domain/entities/moto_club.dart';
import 'package:loc_motos/features/clubs/presentation/providers/club_providers.dart';

class ClubPendingScreen extends ConsumerStatefulWidget {
  const ClubPendingScreen({super.key, required this.user});

  final AppUser user;

  @override
  ConsumerState<ClubPendingScreen> createState() => _ClubPendingScreenState();
}

class _ClubPendingScreenState extends ConsumerState<ClubPendingScreen> {
  var _activating = false;
  var _busyDismiss = false;

  Future<void> _activateApproved(String clubId) async {
    if (_activating) {
      return;
    }
    setState(() => _activating = true);
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
    } catch (_) {
      if (mounted) {
        setState(() => _activating = false);
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

  @override
  Widget build(BuildContext context) {
    final requestAsync = ref.watch(pendingClubRequestProvider);
    final colors = Theme.of(context).colorScheme;

    // Si el panel ya puso el club en el usuario, salir del gate.
    if (widget.user.isInClub && !widget.user.hasPendingClubRequest) {
      return const Scaffold(
        body: Center(child: CircularProgressIndicator()),
      );
    }

    return Scaffold(
      appBar: AppBar(
        title: const Text('Pendiente de aprobación'),
        actions: [
          IconButton(
            tooltip: 'Cerrar sesión',
            onPressed: () =>
                ref.read(authActionControllerProvider.notifier).signOut(),
            icon: const Icon(Icons.logout),
          ),
        ],
      ),
      body: requestAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(child: Text('Error: $e')),
        data: (request) {
          if (request == null) {
            return const Center(child: CircularProgressIndicator());
          }
          if (request.status == ClubJoinRequestStatus.approved &&
              request.resultingClubId != null) {
            final clubId = request.resultingClubId!;
            if (!_activating) {
              WidgetsBinding.instance.addPostFrameCallback((_) {
                _activateApproved(clubId);
              });
            }
            return const Center(child: CircularProgressIndicator());
          }
          if (request.status == ClubJoinRequestStatus.rejected) {
            return _CenteredMessage(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.cancel_outlined, size: 56, color: colors.error),
                  const SizedBox(height: 20),
                  Text(
                    'Solicitud no aprobada',
                    textAlign: TextAlign.center,
                    style: Theme.of(context).textTheme.titleLarge?.copyWith(
                          fontWeight: FontWeight.w700,
                        ),
                  ),
                  if (request.reviewNote != null &&
                      request.reviewNote!.trim().isNotEmpty) ...[
                    const SizedBox(height: 12),
                    Text(
                      request.reviewNote!,
                      textAlign: TextAlign.center,
                      style: TextStyle(color: colors.onSurfaceVariant),
                    ),
                  ],
                  const SizedBox(height: 28),
                  FilledButton(
                    onPressed: _busyDismiss
                        ? null
                        : () => _dismissRejected(request.id),
                    child: _busyDismiss
                        ? const SizedBox(
                            width: 22,
                            height: 22,
                            child: CircularProgressIndicator(strokeWidth: 2),
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
                Icon(Icons.hourglass_top, size: 56, color: colors.primary),
                const SizedBox(height: 20),
                Text(
                  'Pendiente de aprobación',
                  textAlign: TextAlign.center,
                  style: Theme.of(context).textTheme.titleLarge?.copyWith(
                        fontWeight: FontWeight.w700,
                      ),
                ),
                const SizedBox(height: 12),
                Text(
                  'Tu club «${request.clubName}» está en revisión.',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    color: colors.onSurfaceVariant,
                    height: 1.35,
                  ),
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
