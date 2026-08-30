import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:loc_motos/features/auth/domain/entities/app_user.dart';
import 'package:loc_motos/features/auth/presentation/providers/auth_providers.dart';
import 'package:loc_motos/features/auth/presentation/screens/display_name_screen.dart';
import 'package:loc_motos/features/auth/presentation/screens/home_screen.dart';
import 'package:loc_motos/features/auth/presentation/screens/login_screen.dart';
import 'package:loc_motos/features/auth/presentation/screens/recovery_key_screen.dart';
import 'package:loc_motos/features/clubs/presentation/providers/club_providers.dart';
import 'package:loc_motos/features/clubs/presentation/screens/club_entry_screen.dart';
import 'package:loc_motos/features/clubs/presentation/screens/club_pending_screen.dart';
import 'package:loc_motos/features/clubs/presentation/screens/club_select_screen.dart';
import 'package:loc_motos/features/groups/presentation/providers/group_providers.dart';
import 'package:loc_motos/features/tracking/presentation/providers/tracking_providers.dart';

class AuthGate extends ConsumerWidget {
  const AuthGate({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    void resetLiveListeners() {
      ref.invalidate(rideGroupProvider);
      ref.invalidate(groupMembersProvider);
      ref.invalidate(liveUserProvider);
      ref.invalidate(groupLocationsProvider);
      ref.invalidate(myGroupsProvider);
      ref.invalidate(myClubMembershipsProvider);
      ref.read(groupMapSessionOpenProvider.notifier).state = false;
    }

    ref.listen(signedInUserProvider, (previous, next) {
      if (previous?.uid != next?.uid) {
        resetLiveListeners();
        ref.read(dismissedPendingClubRequestIdProvider.notifier).state = null;
      }
    });
    ref.listen(authStateProvider, (previous, next) {
      final previousUid = previous?.asData?.value?.uid;
      final nextUid = next.asData?.value?.uid;
      if (previousUid == nextUid) {
        return;
      }
      resetLiveListeners();
      ref.read(dismissedPendingClubRequestIdProvider.notifier).state = null;
    });

    final localUser = ref.watch(signedInUserProvider);
    final auth = ref.watch(authStateProvider);
    final pendingRecoveryKey = ref.watch(pendingRecoveryKeyProvider);
    if (pendingRecoveryKey != null && pendingRecoveryKey.isNotEmpty) {
      return RecoveryKeyScreen(recoveryKey: pendingRecoveryKey);
    }

    final sessionUser = resolveSessionUser(localUser, auth.asData?.value);
    final dismissedPendingId = ref.watch(dismissedPendingClubRequestIdProvider);

    Widget forUser() {
      final user = sessionUser;
      if (user == null) {
        return const LoginScreen();
      }
      if (user.needsDisplayName) {
        return DisplayNameScreen(
          alreadySignedIn: true,
          isGuest: user.isAnonymous,
        );
      }
      if (user.isAnonymous) {
        return HomeScreen(user: user);
      }
      return _clubGate(ref, user, dismissedPendingId);
    }

    return auth.when(
      loading: () {
        final user = sessionUser;
        if (user != null && !user.needsDisplayName) {
          if (user.isAnonymous) {
            return HomeScreen(user: user);
          }
          return _clubGate(ref, user, dismissedPendingId);
        }
        return const Scaffold(
          body: Center(child: CircularProgressIndicator()),
        );
      },
      error: (error, _) {
        if (sessionUser != null && !sessionUser.needsDisplayName) {
          if (sessionUser.isAnonymous) {
            return HomeScreen(user: sessionUser);
          }
          return _clubGate(ref, sessionUser, dismissedPendingId);
        }
        return Scaffold(
          body: Center(
            child: Padding(
              padding: const EdgeInsets.all(24),
              child: Text(
                'No se pudo leer la sesión.\n$error',
                textAlign: TextAlign.center,
              ),
            ),
          ),
        );
      },
      data: (_) => forUser(),
    );
  }

  /// Reglas:
  /// - Sin peña y sin navegación individual → obligar a unirse/registrar.
  /// - Varios clubs y ninguno activo → elegir primero.
  /// - Un solo club → activarlo solo.
  /// - Con navegación individual y sin peña → home (podrá unirse luego).
  Widget _clubGate(WidgetRef ref, AppUser user, String? dismissedPendingId) {
    final pendingId = user.pendingClubRequestId;
    final showPending = user.hasPendingClubRequest &&
        (dismissedPendingId == null || dismissedPendingId != pendingId);
    if (showPending) {
      return ClubPendingScreen(user: user);
    }

    final membershipsAsync = ref.watch(myClubMembershipsProvider);
    return membershipsAsync.when(
      loading: () {
        if (user.isInClub || user.allowSoloNavigation) {
          return HomeScreen(user: user);
        }
        return const Scaffold(
          body: Center(child: CircularProgressIndicator()),
        );
      },
      error: (_, _) {
        if (user.allowSoloNavigation || user.isInClub) {
          return HomeScreen(user: user);
        }
        return ClubEntryScreen(user: user);
      },
      data: (memberships) {
        final activeId = user.currentClubId;
        final hasValidActive = activeId != null &&
            activeId.isNotEmpty &&
            memberships.any((m) => m.clubId == activeId);

        if (memberships.length > 1 && !hasValidActive) {
          return ClubSelectScreen(user: user, memberships: memberships);
        }

        if (memberships.length == 1 && !hasValidActive) {
          return _ActivateSoleClubGate(
            user: user,
            clubId: memberships.first.clubId,
          );
        }

        if (memberships.isEmpty && !user.allowSoloNavigation) {
          return ClubEntryScreen(user: user);
        }

        return HomeScreen(user: user);
      },
    );
  }
}

/// Activa el único club una sola vez (evita bucles de microtask + rebuild).
class _ActivateSoleClubGate extends ConsumerStatefulWidget {
  const _ActivateSoleClubGate({
    required this.user,
    required this.clubId,
  });

  final AppUser user;
  final String clubId;

  @override
  ConsumerState<_ActivateSoleClubGate> createState() =>
      _ActivateSoleClubGateState();
}

class _ActivateSoleClubGateState extends ConsumerState<_ActivateSoleClubGate> {
  var _started = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _activate());
  }

  Future<void> _activate() async {
    if (_started) {
      return;
    }
    _started = true;
    try {
      await ref.read(clubRemoteDataSourceProvider).setActiveClub(
            uid: widget.user.uid,
            clubId: widget.clubId,
          );
      if (!mounted) {
        return;
      }
      final local = ref.read(signedInUserProvider);
      if (local != null && local.uid == widget.user.uid) {
        ref.read(signedInUserProvider.notifier).state = local.copyWith(
          currentClubId: widget.clubId,
          clearPendingClubRequestId: true,
        );
      }
    } catch (_) {
      _started = false;
    }
  }

  @override
  Widget build(BuildContext context) {
    if (widget.user.allowSoloNavigation) {
      return HomeScreen(user: widget.user);
    }
    return const Scaffold(
      body: Center(child: CircularProgressIndicator()),
    );
  }
}
