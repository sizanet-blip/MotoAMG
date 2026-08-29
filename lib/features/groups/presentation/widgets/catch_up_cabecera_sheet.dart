import 'package:flutter/material.dart';
import 'package:loc_motos/core/widgets/keyboard_safe_sheet_body.dart';
import 'package:loc_motos/features/groups/domain/entities/group_voice_announcement.dart';
import 'package:loc_motos/features/navigation/presentation/widgets/route_preferences_bar.dart';

enum CatchUpCabeceraChoice { chase, destination }

extension CatchUpCabeceraChoiceX on CatchUpCabeceraChoice {
  GroupVoiceKind get voiceKind => switch (this) {
        CatchUpCabeceraChoice.chase => GroupVoiceKind.catchUpChase,
        CatchUpCabeceraChoice.destination => GroupVoiceKind.catchUpDestination,
      };
}

/// Elige ir a la cabecera (con estilo de ruta) o directo al destino del grupo.
Future<CatchUpCabeceraChoice?> showCatchUpCabeceraSheet({
  required BuildContext context,
  required String cabeceraName,
}) {
  return showModalBottomSheet<CatchUpCabeceraChoice>(
    context: context,
    isScrollControlled: true,
    showDragHandle: true,
    builder: (context) {
      return KeyboardSafeSheetBody(
        padding: const EdgeInsets.fromLTRB(20, 4, 20, 8),
        child: _CatchUpCabeceraSheet(cabeceraName: cabeceraName),
      );
    },
  );
}

class _CatchUpCabeceraSheet extends StatelessWidget {
  const _CatchUpCabeceraSheet({required this.cabeceraName});

  final String cabeceraName;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(
          'El grupo ya está en marcha',
          style: theme.textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.w700,
              ),
        ),
        const SizedBox(height: 8),
        Text(
          'Puedes ir a la cabecera ($cabeceraName) con el estilo de ruta '
          'que quieras. Cuando enganches el trazado del grupo, seguirás '
          'la ruta compartida.',
          style: theme.textTheme.bodyMedium?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
                height: 1.35,
              ),
        ),
        const SizedBox(height: 16),
        Text(
          'Cómo quieres llegar a la cabecera',
          style: theme.textTheme.labelLarge?.copyWith(
                fontWeight: FontWeight.w700,
              ),
        ),
        const SizedBox(height: 8),
        const RoutePreferencesBar(),
        const SizedBox(height: 16),
        FilledButton.icon(
          onPressed: () => Navigator.pop(
            context,
            CatchUpCabeceraChoice.chase,
          ),
          icon: const Icon(Icons.sports_motorsports_outlined),
          label: Text('Ir a $cabeceraName'),
        ),
        const SizedBox(height: 8),
        OutlinedButton(
          onPressed: () => Navigator.pop(
            context,
            CatchUpCabeceraChoice.destination,
          ),
          child: const Text('Ir al destino del grupo'),
        ),
      ],
    );
  }
}
