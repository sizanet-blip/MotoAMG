import 'package:flutter/material.dart';

/// Estilo unificado de menús emergentes (cuenta, perfil, navegación…).
abstract final class AppPopupMenus {
  static const Offset offset = Offset(0, 8);

  static ShapeBorder shapeOf(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return RoundedRectangleBorder(
      borderRadius: BorderRadius.circular(16),
      side: BorderSide(
        color: colors.outlineVariant.withValues(alpha: 0.55),
      ),
    );
  }

  static Color colorOf(BuildContext context) =>
      Theme.of(context).colorScheme.surfaceContainerHigh;

  static Color surfaceTintOf(BuildContext context) =>
      Theme.of(context).colorScheme.surface;

  static const double elevation = 10;
  static const Color shadowColor = Colors.black38;

  /// Aplica el look profesional a un [PopupMenuButton].
  static PopupMenuThemeData themeOf(BuildContext context) {
    return PopupMenuThemeData(
      color: colorOf(context),
      elevation: elevation,
      shadowColor: shadowColor,
      surfaceTintColor: surfaceTintOf(context),
      shape: shapeOf(context),
      textStyle: Theme.of(context).textTheme.bodyMedium?.copyWith(
            fontWeight: FontWeight.w600,
          ),
    );
  }
}

/// Fila de menú con icono tintado (mismo lenguaje visual que el menú de cuenta).
class AppPopupMenuTile extends StatelessWidget {
  const AppPopupMenuTile({
    super.key,
    required this.icon,
    required this.label,
    this.tint,
    this.destructive = false,
    this.selected = false,
  });

  final IconData icon;
  final String label;

  /// Color del icono; por defecto primary (o error si [destructive]).
  final Color? tint;
  final bool destructive;
  final bool selected;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final color = tint ??
        (destructive
            ? colors.error
            : (selected ? colors.primary : colors.primary));

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        children: [
          Container(
            width: 34,
            height: 34,
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.14),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(icon, size: 18, color: color),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              label,
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    fontWeight:
                        destructive || selected ? FontWeight.w700 : FontWeight.w600,
                    color: destructive ? color : colors.onSurface,
                  ),
            ),
          ),
          if (selected) ...[
            const SizedBox(width: 8),
            Icon(Icons.check_rounded, size: 18, color: colors.primary),
          ],
        ],
      ),
    );
  }
}

/// Ítem de menú listo para usar con [AppPopupMenuTile].
PopupMenuItem<T> appPopupMenuItem<T>({
  required T value,
  required IconData icon,
  required String label,
  Color? tint,
  bool destructive = false,
  bool selected = false,
  bool enabled = true,
  EdgeInsets padding = const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
}) {
  return PopupMenuItem<T>(
    value: value,
    enabled: enabled,
    padding: padding,
    child: AppPopupMenuTile(
      icon: icon,
      label: label,
      tint: tint,
      destructive: destructive,
      selected: selected,
    ),
  );
}
