import 'package:hive_flutter/hive_flutter.dart';
import 'package:loc_motos/core/constants/app_constants.dart';
import 'package:loc_motos/core/theme/app_color_theme.dart';

class AppColorThemeRepository {
  Box<String>? _box;

  Future<Box<String>> _open() async {
    _box ??= await Hive.openBox<String>(AppConstants.colorThemeBox);
    return _box!;
  }

  Future<AppColorTheme> load() async {
    final box = await _open();
    final raw = box.get(AppConstants.colorThemeKey);
    if (raw == null || raw.isEmpty) {
      return AppColorTheme.classic;
    }
    return AppColorTheme.values.firstWhere(
      (theme) => theme.name == raw,
      orElse: () => AppColorTheme.classic,
    );
  }

  Future<void> save(AppColorTheme theme) async {
    final box = await _open();
    await box.put(AppConstants.colorThemeKey, theme.name);
  }
}
