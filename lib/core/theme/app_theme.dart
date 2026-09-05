import 'package:flutter/material.dart';
import 'package:moto_amg/core/theme/hub_style.dart';

/// Tema único de la app (alineado al hub MotoAMG).
abstract final class AppTheme {
  static const Color _logoGraphite = Color(0xFF101018);
  static const Color _logoWhite = Color(0xFFF8F8F8);
  /// Aviso / estado (no chrome de marca).
  static const Color _statusAmber = Color(0xFFB45309);

  static ThemeData get light => _theme(Brightness.light);

  static ThemeData get dark => _theme(Brightness.dark);

  static ThemeData _theme(Brightness brightness) {
    final dark = brightness == Brightness.dark;
    final scheme = ColorScheme.fromSeed(
      seedColor: HubStyle.accent,
      brightness: brightness,
      primary: dark ? const Color(0xFF5BA3C9) : HubStyle.accent,
      onPrimary: dark ? _logoGraphite : _logoWhite,
      surface: dark ? _logoGraphite : HubStyle.surface,
      onSurface: dark ? _logoWhite : HubStyle.title,
      tertiary: _statusAmber,
      onTertiary: _logoWhite,
    );

    return ThemeData(
      useMaterial3: true,
      colorScheme: scheme,
      scaffoldBackgroundColor: scheme.surface,
      appBarTheme: AppBarTheme(
        backgroundColor: scheme.surface,
        foregroundColor: scheme.onSurface,
        elevation: 0,
        scrolledUnderElevation: 0,
        surfaceTintColor: Colors.transparent,
      ),
      filledButtonTheme: FilledButtonThemeData(
        style: HubStyle.filledButtonStyle(),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: HubStyle.outlinedButtonStyle(),
      ),
      textButtonTheme: TextButtonThemeData(
        style: HubStyle.textButtonStyle(),
      ),
    );
  }
}
