import 'package:flutter/material.dart';

/// Paleta fija del HUD de navegación (independiente del tema de la app).
/// Tonos pensados para no deslumbrar de noche (menos blanco puro / naranja).
abstract final class NavigationHudTheme {
  static const panel = Color(0xFF14181E);
  static const panelElevated = Color(0xFF1E242C);
  static const accent = Color(0xFF5BA3C9);
  static const accentStrong = Color(0xFF2E7BA8);
  static const routeLine = Color(0xFF3B8DD9);
  static const routeCasing = Color(0xFF1A2430);
  static const textPrimary = Color(0xFFD5DCE4);
  static const textSecondary = Color(0xFF8B96A3);
  static const warning = Color(0xFFC9A06A);

  static const panelRadius = 20.0;
  static const panelShadow = BoxShadow(
    color: Color(0x66000000),
    blurRadius: 24,
    offset: Offset(0, 8),
  );
}
