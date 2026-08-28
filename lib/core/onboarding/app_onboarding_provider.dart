import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:loc_motos/core/onboarding/app_onboarding_repository.dart';

final appOnboardingRepositoryProvider = Provider<AppOnboardingRepository>((ref) {
  return AppOnboardingRepository();
});

final appOnboardingReadyProvider = FutureProvider<bool>((ref) async {
  return ref.read(appOnboardingRepositoryProvider).isComplete();
});

final appOnboardingControllerProvider = Provider<AppOnboardingController>((ref) {
  return AppOnboardingController(ref);
});

class AppOnboardingController {
  AppOnboardingController(this._ref);

  final Ref _ref;

  Future<void> complete() async {
    await _ref.read(appOnboardingRepositoryProvider).markComplete();
    _ref.invalidate(appOnboardingReadyProvider);
  }
}
