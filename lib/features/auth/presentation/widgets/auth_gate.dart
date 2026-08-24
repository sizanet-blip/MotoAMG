import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:loc_motos/features/auth/presentation/providers/auth_providers.dart';
import 'package:loc_motos/features/auth/presentation/screens/display_name_screen.dart';
import 'package:loc_motos/features/auth/presentation/screens/home_screen.dart';
import 'package:loc_motos/features/auth/presentation/screens/login_screen.dart';
import 'package:loc_motos/features/auth/presentation/screens/recovery_key_screen.dart';
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
    }

    ref.listen(signedInUserProvider, (previous, next) {
      if (previous?.uid != next?.uid) {
        resetLiveListeners();
      }
    });
    ref.listen(authStateProvider, (previous, next) {
      final previousUid = previous?.asData?.value?.uid;
      final nextUid = next.asData?.value?.uid;
      if (previousUid == nextUid) {
        return;
      }
      resetLiveListeners();
    });

    final localUser = ref.watch(signedInUserProvider);
    final auth = ref.watch(authStateProvider);
    final pendingRecoveryKey = ref.watch(pendingRecoveryKeyProvider);
    if (pendingRecoveryKey != null && pendingRecoveryKey.isNotEmpty) {
      return RecoveryKeyScreen(recoveryKey: pendingRecoveryKey);
    }

    Widget forUser() {
      final user = resolveSessionUser(localUser, auth.asData?.value);
      if (user == null) {
        return const LoginScreen();
      }
      if (user.needsDisplayName) {
        return DisplayNameScreen(
          alreadySignedIn: true,
          isGuest: user.isAnonymous,
        );
      }
      return HomeScreen(user: user);
    }

    if (localUser != null && !localUser.needsDisplayName) {
      return HomeScreen(user: localUser);
    }

    return auth.when(
      loading: () {
        if (localUser != null && !localUser.needsDisplayName) {
          return HomeScreen(user: localUser);
        }
        return const Scaffold(
          body: Center(child: CircularProgressIndicator()),
        );
      },
      error: (error, _) {
        if (localUser != null && !localUser.needsDisplayName) {
          return HomeScreen(user: localUser);
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
}
