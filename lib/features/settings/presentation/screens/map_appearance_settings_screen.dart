import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:loc_motos/features/navigation/data/repositories/map_appearance_repository.dart';
import 'package:loc_motos/features/navigation/presentation/providers/navigation_providers.dart';

/// Elección persistente del estilo de mapa en navegación.
class MapAppearanceSettingsScreen extends ConsumerWidget {
  const MapAppearanceSettingsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final appearance = ref.watch(mapAppearanceProvider);
    final colors = Theme.of(context).colorScheme;

    return Scaffold(
      appBar: AppBar(title: const Text('Mapa día / noche')),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
        children: [
          Text(
            'Elige el aspecto del mapa en navegación. '
            'La preferencia se guarda en este dispositivo.',
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  color: colors.onSurfaceVariant,
                ),
          ),
          const SizedBox(height: 16),
          for (final mode in MapAppearanceMode.values) ...[
            _ModeCard(
              mode: mode,
              selected: appearance.mode == mode,
              onTap: () =>
                  ref.read(mapAppearanceProvider.notifier).setMode(mode),
            ),
            const SizedBox(height: 10),
          ],
          const SizedBox(height: 8),
          DecoratedBox(
            decoration: BoxDecoration(
              color: colors.surfaceContainerHighest.withValues(alpha: 0.55),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Padding(
              padding: const EdgeInsets.all(12),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Icon(
                    Icons.info_outline_rounded,
                    size: 20,
                    color: colors.primary,
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      'Modo automático: calcula amanecer y atardecer según la fecha '
                      'y tu posición GPS (cambia entre verano e invierno).\n\n'
                      'El mapa nocturno necesita internet (estilo suave, no negro puro).\n'
                      'Los mapas offline descargados solo están en versión clara: '
                      'sin cobertura verás ese mapa aunque hayas elegido noche.\n\n'
                      'También puedes cambiarlo mientras navegas, con el botón '
                      'de sol/luna de la esquina superior derecha.',
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                            color: colors.onSurfaceVariant,
                            height: 1.35,
                          ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _ModeCard extends StatelessWidget {
  const _ModeCard({
    required this.mode,
    required this.selected,
    required this.onTap,
  });

  final MapAppearanceMode mode;
  final bool selected;
  final VoidCallback onTap;

  IconData get _icon => switch (mode) {
        MapAppearanceMode.auto => Icons.brightness_auto_rounded,
        MapAppearanceMode.day => Icons.light_mode_rounded,
        MapAppearanceMode.night => Icons.dark_mode_rounded,
      };

  String get _detail => switch (mode) {
        MapAppearanceMode.auto =>
          'Usa el amanecer y el atardecer de tu ubicación: '
              'en verano anochece más tarde y en invierno más temprano. '
              'De noche, con internet, usa un mapa oscuro suave (no negro puro). '
              'Sin cobertura se usa el offline (claro).',
        MapAppearanceMode.day =>
          'Siempre mapa claro, con o sin internet.',
        MapAppearanceMode.night =>
          'Prefiere mapa nocturno suave cuando hay internet. '
              'Sin cobertura se usa el mapa offline descargado (claro), '
              'porque ese pack no tiene versión oscura.',
      };

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return Material(
      color: selected
          ? colors.primaryContainer.withValues(alpha: 0.55)
          : colors.surfaceContainerHighest.withValues(alpha: 0.35),
      borderRadius: BorderRadius.circular(14),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(14),
        child: Padding(
          padding: const EdgeInsets.fromLTRB(12, 12, 8, 12),
          child: Row(
            children: [
              CircleAvatar(
                radius: 22,
                backgroundColor: selected
                    ? colors.primary
                    : colors.surfaceContainerHighest,
                foregroundColor:
                    selected ? colors.onPrimary : colors.onSurfaceVariant,
                child: Icon(_icon, size: 22),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      mode.label,
                      style: Theme.of(context).textTheme.titleSmall?.copyWith(
                            fontWeight: FontWeight.w800,
                          ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      _detail,
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                            color: colors.onSurfaceVariant,
                            height: 1.3,
                          ),
                    ),
                  ],
                ),
              ),
              Radio<MapAppearanceMode>(
                value: mode,
                // ignore: deprecated_member_use
                groupValue: selected ? mode : null,
                // ignore: deprecated_member_use
                onChanged: (_) => onTap(),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
