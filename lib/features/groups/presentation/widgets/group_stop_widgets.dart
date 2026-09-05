import 'package:flutter/material.dart';
import 'package:moto_amg/core/widgets/keyboard_safe_sheet_body.dart';
import 'package:moto_amg/features/groups/domain/entities/group_stop.dart';

/// Elige el tipo de parada al marcar un punto en el mapa.
Future<GroupStopType?> showGroupStopTypeSheet(BuildContext context) {
  return showModalBottomSheet<GroupStopType>(
    context: context,
    isScrollControlled: true,
    showDragHandle: true,
    builder: (context) {
      return KeyboardSafeSheetBody(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              'Marcar parada en el mapa',
              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w700,
                  ),
            ),
            const SizedBox(height: 6),
            Text(
              'Todo el grupo verá el pin. Útil para café, gasolina o '
              'reagruparse.',
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: Theme.of(context).colorScheme.onSurfaceVariant,
                  ),
            ),
            const SizedBox(height: 16),
            for (final type in GroupStopType.values)
              ListTile(
                contentPadding: EdgeInsets.zero,
                leading: Icon(iconForGroupStopType(type)),
                title: Text(type.label),
                onTap: () => Navigator.of(context).pop(type),
              ),
          ],
        ),
      );
    },
  );
}

IconData iconForGroupStopType(GroupStopType type) => switch (type) {
      GroupStopType.cafe => Icons.local_cafe_outlined,
      GroupStopType.gasolinera => Icons.local_gas_station_outlined,
      GroupStopType.esperarAqui => Icons.place_outlined,
      GroupStopType.reunion => Icons.groups_outlined,
    };

/// Aviso breve cuando hay ruta compartida: el mapa de grupo es el modo principal.
class GroupMapModeBanner extends StatelessWidget {
  const GroupMapModeBanner({
    super.key,
    required this.destinationLabel,
    this.compact = false,
  });

  final String destinationLabel;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return Material(
      color: colors.primaryContainer.withValues(alpha: 0.92),
      borderRadius: BorderRadius.circular(compact ? 8 : 10),
      child: Padding(
        padding: EdgeInsets.symmetric(
          horizontal: compact ? 8 : 12,
          vertical: compact ? 6 : 8,
        ),
        child: Row(
          children: [
            Icon(Icons.map_outlined, size: 18, color: colors.onPrimaryContainer),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                'Ruta del grupo · $destinationLabel',
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: colors.onPrimaryContainer,
                      fontWeight: FontWeight.w600,
                    ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
