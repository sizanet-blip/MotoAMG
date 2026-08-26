import 'package:flutter/material.dart';

/// Colores de boquerel / identificación de carburante en España.
abstract final class FuelNozzleColors {
  /// Gasolina 95 — boquerel verde oscuro.
  static const gasolina95 = Color(0xFF1B7A3D);

  /// Gasolina 98 — boquerel verde claro.
  static const gasolina98 = Color(0xFF8BC34A);

  /// Gasóleo / diésel — boquerel negro (en HUD: gris claro legible + chip negro).
  static const gasoleo = Color(0xFFE8E8E8);
  static const gasoleoChip = Color(0xFF121212);

  /// GLP / Autogas — naranja.
  static const glp = Color(0xFFFF6D00);

  /// Renovables — rosa.
  static const renewable = Color(0xFFEC407A);

  static const fallback = Color(0xFFFFB74D);

  /// Color de acento (texto del precio) según el grado mostrado.
  static Color accentForGrade(String grade) {
    final g = grade.trim().toLowerCase();
    if (g == '95') {
      return gasolina95;
    }
    if (g == '98') {
      return gasolina98;
    }
    if (g.startsWith('gasóleo') ||
        g.startsWith('gasoleo') ||
        g == 'g.prem' ||
        g == 'g.b' ||
        g.contains('diésel') ||
        g.contains('diesel')) {
      return gasoleo;
    }
    if (g.contains('glp') || g.contains('autogas')) {
      return glp;
    }
    if (g.contains('hvo') ||
        g.contains('renew') ||
        g.contains('renov') ||
        g.contains('e85') ||
        g.contains('biod')) {
      return renewable;
    }
    return fallback;
  }

  /// Color del chip/indicador del boquerel (fondo).
  static Color chipForGrade(String grade) {
    final g = grade.trim().toLowerCase();
    if (g == '95') {
      return gasolina95;
    }
    if (g == '98') {
      return gasolina98;
    }
    if (g.startsWith('gasóleo') ||
        g.startsWith('gasoleo') ||
        g == 'g.prem' ||
        g == 'g.b' ||
        g.contains('diésel') ||
        g.contains('diesel')) {
      return gasoleoChip;
    }
    if (g.contains('glp') || g.contains('autogas')) {
      return glp;
    }
    if (g.contains('hvo') ||
        g.contains('renew') ||
        g.contains('renov') ||
        g.contains('e85') ||
        g.contains('biod')) {
      return renewable;
    }
    return const Color(0xFF546E7A);
  }

  static Color onChipForGrade(String grade) {
    final chip = chipForGrade(grade);
    if (chip == gasolina98) {
      return const Color(0xFF1B1B1B);
    }
    return Colors.white;
  }
}

/// Estilo visual aproximado de marca (color corporativo).
///
/// El badge del HUD usa icono de surtidor + color de marca (sin monogramas).
class FuelBrandStyle {
  const FuelBrandStyle({
    required this.primary,
    required this.onPrimary,
    this.accent,
  });

  final Color primary;
  final Color onPrimary;
  final Color? accent;

  static const fallback = FuelBrandStyle(
    primary: Color(0xFFEF6C00),
    onPrimary: Colors.white,
  );

  static FuelBrandStyle resolve(String? brandOrName) {
    final key = _normalize(brandOrName);
    if (key.isEmpty) {
      return fallback;
    }

    for (final entry in _catalog) {
      if (entry.matches(key)) {
        return entry.style;
      }
    }

    return const FuelBrandStyle(
      primary: Color(0xFF455A64),
      onPrimary: Colors.white,
    );
  }

  static String _normalize(String? raw) {
    if (raw == null) {
      return '';
    }
    return raw
        .toUpperCase()
        .replaceAll(RegExp(r'[^A-Z0-9ÁÉÍÓÚÜÑ ]'), ' ')
        .replaceAll(RegExp(r'\s+'), ' ')
        .trim();
  }
}

class _BrandEntry {
  const _BrandEntry({
    required this.tokens,
    required this.style,
  });

  final List<String> tokens;
  final FuelBrandStyle style;

  bool matches(String key) {
    for (final token in tokens) {
      if (key == token || key.startsWith('$token ') || key.contains(' $token')) {
        return true;
      }
      if (key.contains(token) && token.length >= 4) {
        return true;
      }
    }
    return false;
  }
}

const _catalog = <_BrandEntry>[
  _BrandEntry(
    tokens: ['REPSOL', 'CAMPSA', 'PETRONOR'],
    style: FuelBrandStyle(
      primary: Color(0xFFFF8200),
      onPrimary: Colors.white,
      accent: Color(0xFFE30613),
    ),
  ),
  _BrandEntry(
    tokens: ['CEPSA', 'MOEVE'],
    style: FuelBrandStyle(
      primary: Color(0xFFE30613),
      onPrimary: Colors.white,
    ),
  ),
  _BrandEntry(
    tokens: ['BP', 'BRITISH PETROLEUM'],
    style: FuelBrandStyle(
      primary: Color(0xFF009639),
      onPrimary: Colors.white,
      accent: Color(0xFF7DC242),
    ),
  ),
  _BrandEntry(
    tokens: ['SHELL'],
    style: FuelBrandStyle(
      primary: Color(0xFFDD1D21),
      onPrimary: Colors.white,
      accent: Color(0xFFFBCE07),
    ),
  ),
  _BrandEntry(
    tokens: ['GALP'],
    style: FuelBrandStyle(
      primary: Color(0xFF00843D),
      onPrimary: Colors.white,
      accent: Color(0xFFFF8200),
    ),
  ),
  _BrandEntry(
    tokens: ['TOTALENERGIES', 'TOTAL'],
    style: FuelBrandStyle(
      primary: Color(0xFFED1C24),
      onPrimary: Colors.white,
    ),
  ),
  _BrandEntry(
    tokens: ['AVIA'],
    style: FuelBrandStyle(
      primary: Color(0xFFC8102E),
      onPrimary: Colors.white,
    ),
  ),
  _BrandEntry(
    tokens: ['Q8', 'KUWAIT'],
    style: FuelBrandStyle(
      primary: Color(0xFFC8102E),
      onPrimary: Colors.white,
    ),
  ),
  _BrandEntry(
    tokens: ['DISA'],
    style: FuelBrandStyle(
      primary: Color(0xFF005EB8),
      onPrimary: Colors.white,
      accent: Color(0xFFFF8200),
    ),
  ),
  _BrandEntry(
    tokens: ['BALLENOIL'],
    style: FuelBrandStyle(
      primary: Color(0xFF00A3E0),
      onPrimary: Colors.white,
    ),
  ),
  _BrandEntry(
    tokens: ['PLENOIL', 'PLEN OIL'],
    style: FuelBrandStyle(
      primary: Color(0xFFFF6A00),
      onPrimary: Colors.white,
    ),
  ),
  _BrandEntry(
    tokens: ['ALCAMPO'],
    style: FuelBrandStyle(
      primary: Color(0xFF0072CE),
      onPrimary: Colors.white,
    ),
  ),
  _BrandEntry(
    tokens: ['CARREFOUR'],
    style: FuelBrandStyle(
      primary: Color(0xFF004E9B),
      onPrimary: Colors.white,
      accent: Color(0xFFE30613),
    ),
  ),
  _BrandEntry(
    tokens: ['EROSKI'],
    style: FuelBrandStyle(
      primary: Color(0xFF009640),
      onPrimary: Colors.white,
      accent: Color(0xFFE30613),
    ),
  ),
  _BrandEntry(
    tokens: ['MEROIL'],
    style: FuelBrandStyle(
      primary: Color(0xFF0033A0),
      onPrimary: Colors.white,
    ),
  ),
  _BrandEntry(
    tokens: ['BONAREA', 'BON ÀREA'],
    style: FuelBrandStyle(
      primary: Color(0xFF6B2D5B),
      onPrimary: Colors.white,
    ),
  ),
  _BrandEntry(
    tokens: ['ESSO', 'EXXON'],
    style: FuelBrandStyle(
      primary: Color(0xFFED1C24),
      onPrimary: Colors.white,
      accent: Color(0xFF0033A0),
    ),
  ),
  _BrandEntry(
    tokens: ['PETROPRIX'],
    style: FuelBrandStyle(
      primary: Color(0xFF1A237E),
      onPrimary: Colors.white,
    ),
  ),
];
