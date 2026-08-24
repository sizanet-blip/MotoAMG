import 'package:flutter/material.dart';

/// Paleta fija del HUD de navegación (independiente del tema de la app).
abstract final class NavigationHudTheme {
  static const panel = Color(0xFF1A1D21);
  static const panelElevated = Color(0xFF252A31);
  static const accent = Color(0xFF4FC3F7);
  static const accentStrong = Color(0xFF0288D1);
  static const routeLine = Color(0xFF1A73E8);
  static const routeCasing = Color(0xFFFFFFFF);
  static const textPrimary = Color(0xFFF5F7FA);
  static const textSecondary = Color(0xFFB0BEC5);
  static const warning = Color(0xFFFFB74D);

  static const panelRadius = 20.0;
  static const panelShadow = BoxShadow(
    color: Color(0x66000000),
    blurRadius: 24,
    offset: Offset(0, 8),
  );
}
