import 'package:flutter/material.dart';
import 'package:moto_amg/core/theme/hub_style.dart';
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
              style: HubStyle.sectionTitle(),
            ),
            const SizedBox(height: 6),
            Text(
              'Todo el grupo verá el pin. Útil para café, gasolina o '
              'reagruparse.',
              style: HubStyle.caption(),
            ),
            const SizedBox(height: 16),
            for (final type in GroupStopType.values)
              ListTile(
                contentPadding: EdgeInsets.zero,
                leading: Icon(
                  iconForGroupStopType(type),
                  color: HubStyle.accent,
                ),
                title: Text(
                  type.label,
                  style: HubStyle.body(color: HubStyle.title),
                ),
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
    return DecoratedBox(
      decoration: BoxDecoration(
        color: HubStyle.accent.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(compact ? 10 : 12),
        boxShadow: HubStyle.cardShadow,
      ),
      child: Padding(
        padding: EdgeInsets.symmetric(
          horizontal: compact ? 8 : 12,
          vertical: compact ? 6 : 8,
        ),
        child: Row(
          children: [
            const Icon(Icons.map_outlined, size: 18, color: HubStyle.accent),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                'Ruta del grupo · $destinationLabel',
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: HubStyle.caption(color: HubStyle.title).copyWith(
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
