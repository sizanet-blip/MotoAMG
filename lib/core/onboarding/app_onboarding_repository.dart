import 'package:hive_flutter/hive_flutter.dart';
import 'package:loc_motos/core/constants/app_constants.dart';

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
}
