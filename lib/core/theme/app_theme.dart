import 'package:flutter/material.dart';
import 'package:loc_motos/core/theme/app_color_theme.dart';

abstract final class AppTheme {
  static const Color _classicSeed = Color(0xFFE65100);
  static const Color _logoCyan = Color(0xFF3CBCF4);
  static const Color _logoGraphite = Color(0xFF101018);
  static const Color _logoAmber = Color(0xFFF8A004);
  static const Color _logoWhite = Color(0xFFF8F8F8);
  static const Color _slate = Color(0xFF5C6770);

  static ThemeData light(AppColorTheme palette) => _theme(
        palette: palette,
        brightness: Brightness.light,
      );

  static ThemeData dark(AppColorTheme palette) => _theme(
        palette: palette,
        brightness: Brightness.dark,
      );

  static ThemeData _theme({
    required AppColorTheme palette,
    required Brightness brightness,
  }) {
    final scheme = switch (palette) {
      AppColorTheme.classic => ColorScheme.fromSeed(
          seedColor: _classicSeed,
          brightness: brightness,
        ),
      AppColorTheme.cyan => _cyanScheme(brightness),
      AppColorTheme.amber => _amberScheme(brightness),
      AppColorTheme.neutral => _neutralScheme(brightness),
    };

    return ThemeData(
      useMaterial3: true,
      colorScheme: scheme,
      appBarTheme: AppBarTheme(
        backgroundColor: scheme.surface,
        foregroundColor: scheme.onSurface,
        elevation: 0,
        scrolledUnderElevation: 0.5,
      ),
    );
  }

  static ColorScheme _cyanScheme(Brightness brightness) {
    final dark = brightness == Brightness.dark;
    return ColorScheme.fromSeed(
      seedColor: _logoCyan,
      brightness: brightness,
      primary: dark ? _logoCyan : const Color(0xFF0288B8),
      onPrimary: dark ? _logoGraphite : _logoWhite,
      surface: dark ? _logoGraphite : const Color(0xFFF4F6F8),
      onSurface: dark ? _logoWhite : const Color(0xFF12141A),
      tertiary: _logoAmber,
      onTertiary: _logoGraphite,
    );
  }

  static ColorScheme _amberScheme(Brightness brightness) {
    final dark = brightness == Brightness.dark;
    return ColorScheme.fromSeed(
      seedColor: _logoAmber,
      brightness: brightness,
      primary: dark ? _logoAmber : const Color(0xFFC67C00),
      onPrimary: dark ? _logoGraphite : _logoWhite,
      surface: dark ? _logoGraphite : const Color(0xFFF7F4EE),
      onSurface: dark ? _logoWhite : const Color(0xFF1A1610),
      tertiary: const Color(0xFF5C6770),
      onTertiary: _logoWhite,
    );
  }

  static ColorScheme _neutralScheme(Brightness brightness) {
    final dark = brightness == Brightness.dark;
    return ColorScheme.fromSeed(
      seedColor: _slate,
      brightness: brightness,
      primary: dark ? const Color(0xFF9AA4B2) : const Color(0xFF3D4A54),
      onPrimary: dark ? _logoGraphite : _logoWhite,
      surface: dark ? const Color(0xFF1A1D21) : const Color(0xFFF4F6F8),
      onSurface: dark ? _logoWhite : const Color(0xFF12141A),
      tertiary: _slate,
      onTertiary: _logoWhite,
    );
  }
}
