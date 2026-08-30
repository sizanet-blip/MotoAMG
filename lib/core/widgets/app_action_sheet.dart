import 'package:flutter/material.dart';

/// Ítem de la hoja de acciones secundaria (mismo patrón en mapa / vista previa).
class AppActionSheetItem {
  const AppActionSheetItem({
    required this.id,
    required this.icon,
    required this.title,
    this.subtitle,
    this.destructive = false,
    this.enabled = true,
  });

  final String id;
  final IconData icon;
  final String title;
  final String? subtitle;
  final bool destructive;
  final bool enabled;
}

/// Hoja inferior unificada: lista de acciones con icono + título + subtítulo.
Future<String?> showAppActionSheet(
  BuildContext context, {
  required List<AppActionSheetItem> items,
  String? title,
}) {
  if (items.isEmpty) {
    return Future<String?>.value(null);
  }
  final colors = Theme.of(context).colorScheme;
  return showModalBottomSheet<String>(
    context: context,
    showDragHandle: true,
    builder: (ctx) {
      return SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            if (title != null)
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 4, 20, 8),
                child: Text(
                  title,
                  style: Theme.of(ctx).textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.w700,
                      ),
                ),
              ),
            for (final item in items)
              ListTile(
                enabled: item.enabled,
                leading: Icon(
                  item.icon,
                  color: item.destructive ? colors.error : null,
                ),
                title: Text(
                  item.title,
                  style: item.destructive
                      ? TextStyle(color: colors.error)
                      : null,
                ),
                subtitle: item.subtitle == null
                    ? null
                    : Text(item.subtitle!),
                onTap: item.enabled
                    ? () => Navigator.pop(ctx, item.id)
                    : null,
              ),
            const SizedBox(height: 8),
          ],
        ),
      );
    },
  );
}
