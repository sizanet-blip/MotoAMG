import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:moto_amg/core/onboarding/app_onboarding_provider.dart';
import 'package:moto_amg/features/auth/presentation/widgets/auth_gate.dart';
import 'package:moto_amg/features/onboarding/presentation/screens/permissions_onboarding_screen.dart';
import 'package:moto_amg/features/onboarding/presentation/screens/privacy_onboarding_screen.dart';

/// Onboarding: permisos → privacidad → app (login / sesión).
class AppBootstrap extends ConsumerWidget {
  const AppBootstrap({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final onboarding = ref.watch(appOnboardingReadyProvider);
    final privacy = ref.watch(appPrivacyAcceptedProvider);

    return onboarding.when(
      loading: () => const Scaffold(
        body: Center(child: CircularProgressIndicator()),
      ),
      error: (_, _) => const AuthGate(),
      data: (permissionsDone) {
        if (!permissionsDone) {
          return const PermissionsOnboardingScreen();
        }
        return privacy.when(
          loading: () => const Scaffold(
            body: Center(child: CircularProgressIndicator()),
          ),
          error: (_, _) => const PrivacyOnboardingScreen(),
          data: (privacyAccepted) => privacyAccepted
              ? const AuthGate()
              : const PrivacyOnboardingScreen(),
        );
      },
    );
  }
}
