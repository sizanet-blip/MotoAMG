import 'package:hive_flutter/hive_flutter.dart';
import 'package:moto_amg/core/constants/app_constants.dart';

class AppOnboardingRepository {
  Box<bool>? _box;

  Future<Box<bool>> _open() async {
    _box ??= await Hive.openBox<bool>(AppConstants.onboardingBox);
    return _box!;
  }

  Future<bool> isComplete() async {
    final box = await _open();
    return box.get(AppConstants.onboardingCompleteKey, defaultValue: false) ??
        false;
  }

  Future<void> markComplete() async {
    final box = await _open();
    await box.put(AppConstants.onboardingCompleteKey, true);
  }

  Future<bool> isPrivacyAccepted() async {
    final box = await _open();
    return box.get(AppConstants.privacyAcceptedKey, defaultValue: false) ??
        false;
  }

  Future<void> markPrivacyAccepted() async {
    final box = await _open();
    await box.put(AppConstants.privacyAcceptedKey, true);
  }
}
