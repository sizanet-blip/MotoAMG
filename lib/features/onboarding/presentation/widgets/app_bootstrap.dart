import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:loc_motos/core/onboarding/app_onboarding_provider.dart';
import 'package:loc_motos/features/auth/presentation/widgets/auth_gate.dart';
import 'package:loc_motos/features/onboarding/presentation/screens/permissions_onboarding_screen.dart';

/// Decide si mostrar onboarding de permisos o la app normal.
class AppBootstrap extends ConsumerWidget {
  const AppBootstrap({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final onboarding = ref.watch(appOnboardingReadyProvider);

    return onboarding.when(
      loading: () => const Scaffold(
        body: Center(child: CircularProgressIndicator()),
      ),
      error: (_, _) => const AuthGate(),
      data: (complete) =>
          complete ? const AuthGate() : const PermissionsOnboardingScreen(),
    );
  }
}
