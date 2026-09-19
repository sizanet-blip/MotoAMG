import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:moto_amg/core/theme/hub_style.dart';
import 'package:moto_amg/features/auth/data/repositories/mysql_auth_repository_impl.dart';
import 'package:moto_amg/features/auth/domain/entities/app_user.dart';
import 'package:moto_amg/features/auth/presentation/providers/auth_providers.dart';
import 'package:moto_amg/features/clubs/domain/entities/moto_club.dart';
import 'package:moto_amg/features/clubs/presentation/providers/club_providers.dart';
import 'package:moto_amg/features/clubs/presentation/widgets/club_invite_code_card.dart';
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
  var _readyToEnter = false;
  String? _activateError;
  String? _inviteCode;
  String? _approvedClubName;
  String? _approvedClubId;

  Future<void> _prepareApproved(ClubJoinRequest request) async {
    if (_activating || _readyToEnter) {
      return;
    }
    final clubId = request.resultingClubId;
    if (clubId == null || clubId.isEmpty) {
      return;
    }
    setState(() {
      _activating = true;
      _activateError = null;
      _approvedClubId = clubId;
      _approvedClubName = request.clubName;
      _inviteCode = request.inviteCode?.trim().isNotEmpty == true
          ? request.inviteCode!.trim()
          : null;
    });
    try {
      try {
        await ref.read(clubRemoteDataSourceProvider).setActiveClub(
              uid: widget.user.uid,
              clubId: clubId,
            );
      } catch (_) {
        // El panel ya pudo fijar current_club_id al aprobar.
      }

      var code = _inviteCode;
      if (code == null || code.isEmpty) {
        final memberships =
            await ref.read(clubRemoteDataSourceProvider).listMemberships();
        for (final m in memberships) {
          if (m.clubId == clubId && m.hasInviteCode) {
            code = m.inviteCode!.trim();
            break;
          }
        }
      }

      if (!mounted) {
        return;
      }
      setState(() {
        _activating = false;
        _readyToEnter = true;
        _inviteCode = code;
      });
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

  Future<void> _enterApp() async {
    final clubId = _approvedClubId;
    if (clubId == null || clubId.isEmpty) {
      return;
    }
    setState(() => _activating = true);
    try {
      await ref
          .read(clubRemoteDataSourceProvider)
          .clearPendingRequest(widget.user.uid);

      final updated = widget.user.copyWith(
        currentClubId: clubId,
        clearPendingClubRequestId: true,
      );
      final repo = ref.read(authRepositoryProvider);
      if (repo is MysqlAuthRepositoryImpl) {
        await repo.patchLocalUser(
          (current) => current.copyWith(
            currentClubId: clubId,
            clearPendingClubRequestId: true,
          ),
        );
      }
      ref.read(signedInUserProvider.notifier).state = updated;
      ref.invalidate(myClubMembershipsProvider);
      ref.invalidate(pendingClubRequestProvider);
    } catch (e) {
      if (mounted) {
        setState(() {
          _activating = false;
          _activateError =
              'No se pudo entrar al club. Comprueba la conexión e inténtalo.';
        });
      }
    }
  }

  Future<void> _dismissRejected(String requestId) async {
    if (_busyDismiss) {
      return;
    }
    setState(() => _busyDismiss = true);
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
    // No limpiar el pending aquí: tras aprobar hay que mostrar el código.
    if (live == null || live.uid != widget.user.uid) {
      return;
    }
    final local = ref.read(signedInUserProvider);
    if (local == null || local.uid != live.uid) {
      return;
    }
    final liveHasClub =
        live.currentClubId != null && live.currentClubId!.trim().isNotEmpty;
    if (liveHasClub &&
        local.currentClubId != live.currentClubId &&
        local.hasPendingClubRequest) {
      ref.read(signedInUserProvider.notifier).state = local.copyWith(
        currentClubId: live.currentClubId,
      );
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

    if (widget.user.isInClub && !widget.user.hasPendingClubRequest) {
      return Scaffold(
        backgroundColor: isDark ? null : HubStyle.surface,
        body: const Center(child: CircularProgressIndicator()),
      );
    }

    return Scaffold(
      backgroundColor: isDark ? null : HubStyle.surface,
      appBar: HubStyle.appBar(
        titleText: _readyToEnter ? 'Club aprobado' : 'Pendiente de aprobación',
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
            if (!_readyToEnter && !_activating && _activateError == null) {
              WidgetsBinding.instance.addPostFrameCallback((_) {
                _prepareApproved(request);
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
                      onPressed: () {
                        setState(() {
                          _activateError = null;
                          _readyToEnter = false;
                        });
                        _prepareApproved(request);
                      },
                      style: HubStyle.filledButtonStyle(),
                      child: const Text('Reintentar'),
                    ),
                  ],
                ),
              );
            }
            if (_readyToEnter) {
              final code = _inviteCode;
              final name = _approvedClubName ?? request.clubName;
              return _CenteredMessage(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(
                      Icons.check_circle_rounded,
                      size: 56,
                      color: HubStyle.accent,
                    ),
                    const SizedBox(height: 16),
                    Text(
                      'Club «$name» aprobado',
                      textAlign: TextAlign.center,
                      style: HubStyle.sectionTitle(),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      code != null && code.isNotEmpty
                          ? 'Comparte este código para que otros se unan al club.'
                          : 'Tu club ya está activo. El código estará en Mis grupos.',
                      textAlign: TextAlign.center,
                      style: HubStyle.body(),
                    ),
                    if (code != null && code.isNotEmpty) ...[
                      const SizedBox(height: 20),
                      ClubInviteCodeCard(
                        code: code,
                        clubName: name,
                      ),
                    ],
                    const SizedBox(height: 24),
                    FilledButton(
                      onPressed: _activating ? null : _enterApp,
                      style: HubStyle.filledButtonStyle(enabled: !_activating),
                      child: _activating
                          ? const SizedBox(
                              width: 22,
                              height: 22,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                color: Colors.white,
                              ),
                            )
                          : const Text('Continuar'),
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
                    'Club aprobado. Preparando…',
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
                  'Tu club o grupo «${request.clubName}» está en revisión.',
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
