import 'package:flutter/material.dart';

abstract final class AppTheme {
  static const Color _seed = Color(0xFFE65100);

  static ThemeData get light {
    return ThemeData(
      useMaterial3: true,
      colorScheme: ColorScheme.fromSeed(
        seedColor: _seed,
        brightness: Brightness.light,
      ),
    );
  }

  static ThemeData get dark {
    return ThemeData(
      useMaterial3: true,
      colorScheme: ColorScheme.fromSeed(
        seedColor: _seed,
        brightness: Brightness.dark,
      ),
    );
  }
}
