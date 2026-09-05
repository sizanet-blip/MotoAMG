import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

/// Tokens visuales del hub MotoAMG (inicio y pantallas alineadas).
abstract final class HubStyle {
  static const Color accent = Color(0xFF0973A9);
  static const Color title = Color(0xFF111827);
  static const Color subtitle = Color(0xFF4B5563);
  static const Color surface = Colors.white;

  static TextStyle pageTitle({Color? color}) => GoogleFonts.plusJakartaSans(
        fontSize: 22,
        fontWeight: FontWeight.w700,
        letterSpacing: -0.3,
        color: color ?? title,
      );

  static TextStyle headline({Color? color}) => GoogleFonts.plusJakartaSans(
        fontSize: 28,
        fontWeight: FontWeight.w800,
        letterSpacing: -0.6,
        height: 1.1,
        color: color ?? title,
      );

  static TextStyle sectionTitle({Color? color}) => GoogleFonts.plusJakartaSans(
        fontSize: 16,
        fontWeight: FontWeight.w700,
        letterSpacing: -0.1,
        color: color ?? title,
      );

  static TextStyle body({Color? color}) => GoogleFonts.plusJakartaSans(
        fontSize: 14,
        fontWeight: FontWeight.w500,
        height: 1.3,
        color: color ?? subtitle,
      );

  static TextStyle caption({Color? color}) => GoogleFonts.plusJakartaSans(
        fontSize: 12,
        fontWeight: FontWeight.w500,
        height: 1.25,
        color: color ?? subtitle,
      );

  static List<BoxShadow> get cardShadow => [
        BoxShadow(
          color: Colors.black.withValues(alpha: 0.08),
          blurRadius: 18,
          offset: const Offset(0, 6),
        ),
      ];

  static ButtonStyle filledButtonStyle({bool enabled = true}) {
    return FilledButton.styleFrom(
      backgroundColor: accent,
      foregroundColor: Colors.white,
      disabledBackgroundColor: accent.withValues(alpha: 0.4),
      disabledForegroundColor: Colors.white70,
      textStyle: GoogleFonts.plusJakartaSans(
        fontWeight: FontWeight.w700,
        fontSize: 15,
      ),
      padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 14),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
    );
  }

  static ButtonStyle outlinedButtonStyle() {
    return OutlinedButton.styleFrom(
      foregroundColor: accent,
      side: const BorderSide(color: accent, width: 1.4),
      textStyle: GoogleFonts.plusJakartaSans(
        fontWeight: FontWeight.w700,
        fontSize: 15,
      ),
      padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 14),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
    );
  }

  static ButtonStyle textButtonStyle() {
    return TextButton.styleFrom(
      foregroundColor: accent,
      textStyle: GoogleFonts.plusJakartaSans(
        fontWeight: FontWeight.w600,
        fontSize: 14,
      ),
    );
  }

  static InputDecoration inputDecoration({
    required String labelText,
    String? hintText,
    String? helperText,
    Widget? suffixIcon,
  }) {
    OutlineInputBorder border([Color? color]) => OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: BorderSide(color: color ?? const Color(0xFFD1D5DB)),
        );
    return InputDecoration(
      labelText: labelText,
      hintText: hintText,
      helperText: helperText,
      suffixIcon: suffixIcon,
      filled: true,
      fillColor: const Color(0xFFF9FAFB),
      labelStyle: GoogleFonts.plusJakartaSans(color: subtitle),
      hintStyle: GoogleFonts.plusJakartaSans(color: subtitle.withValues(alpha: 0.7)),
      helperStyle: caption(),
      border: border(),
      enabledBorder: border(),
      focusedBorder: border(accent),
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
    );
  }

  static PreferredSizeWidget appBar({
    required String titleText,
    List<Widget>? actions,
    Widget? leading,
  }) {
    return AppBar(
      backgroundColor: surface,
      foregroundColor: HubStyle.title,
      surfaceTintColor: Colors.transparent,
      elevation: 0,
      scrolledUnderElevation: 0,
      leading: leading,
      title: Text(titleText, style: pageTitle()),
      actions: actions,
      iconTheme: const IconThemeData(color: HubStyle.title),
    );
  }
}
