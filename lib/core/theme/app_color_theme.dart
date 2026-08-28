import 'package:flutter/material.dart';

/// Paletas de color de la app (independiente del mapa día/noche).
enum AppColorTheme {
  /// Tema actual: naranja Material (puede generar tonos salmón).
  classic,

  /// Cian del logo + grafito.
  cyan,

  /// Ámbar de carretera + grafito.
  amber,

  /// Casi sin color de marca; acento gris-azul.
  neutral,
}

extension AppColorThemeX on AppColorTheme {
  String get label => switch (this) {
        AppColorTheme.classic => 'Clásico',
        AppColorTheme.cyan => 'Cian',
        AppColorTheme.amber => 'Ámbar',
        AppColorTheme.neutral => 'Neutro',
      };

  String get subtitle => switch (this) {
        AppColorTheme.classic =>
          'El naranja de ahora. En algunos botones puede verse un tono carne.',
        AppColorTheme.cyan =>
          'Color del logo: pin cian sobre grafito. El más corporativo.',
        AppColorTheme.amber =>
          'Grafito con acento ámbar, tipo salpicadero de carretera.',
        AppColorTheme.neutral =>
          'Grises y mucho contraste. El color queda para avisos y acciones.',
      };

  /// Muestras para la tarjeta de ajustes.
  List<Color> get swatches => switch (this) {
        AppColorTheme.classic => const [
            Color(0xFFE65100),
            Color(0xFFFFCCBC),
            Color(0xFFBF360C),
          ],
        AppColorTheme.cyan => const [
            Color(0xFF101018),
            Color(0xFF3CBCF4),
            Color(0xFFF8A004),
          ],
        AppColorTheme.amber => const [
            Color(0xFF101018),
            Color(0xFFF8A004),
            Color(0xFFE8EEF2),
          ],
        AppColorTheme.neutral => const [
            Color(0xFF1A1D21),
            Color(0xFF5C6770),
            Color(0xFFF4F6F8),
          ],
      };
}
