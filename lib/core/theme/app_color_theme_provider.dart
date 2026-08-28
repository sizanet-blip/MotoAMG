import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:loc_motos/core/theme/app_color_theme.dart';
import 'package:loc_motos/core/theme/app_color_theme_repository.dart';

final appColorThemeRepositoryProvider = Provider<AppColorThemeRepository>((ref) {
  return AppColorThemeRepository();
});

final appColorThemeProvider =
    NotifierProvider<AppColorThemeController, AppColorTheme>(
  AppColorThemeController.new,
);

class AppColorThemeController extends Notifier<AppColorTheme> {
  @override
  AppColorTheme build() {
    Future.microtask(_hydrate);
    return AppColorTheme.cyan;
  }

  Future<void> _hydrate() async {
    state = await ref.read(appColorThemeRepositoryProvider).load();
  }

  Future<void> setTheme(AppColorTheme theme) async {
    state = theme;
    await ref.read(appColorThemeRepositoryProvider).save(theme);
  }
}
