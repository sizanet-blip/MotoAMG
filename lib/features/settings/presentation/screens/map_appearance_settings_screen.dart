import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:moto_amg/core/theme/hub_style.dart';
import 'package:moto_amg/features/navigation/data/repositories/map_appearance_repository.dart';
import 'package:moto_amg/features/navigation/presentation/providers/navigation_providers.dart';

/// Elección persistente del estilo de mapa en navegación.
class MapAppearanceSettingsScreen extends ConsumerWidget {
  const MapAppearanceSettingsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final appearance = ref.watch(mapAppearanceProvider);
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      backgroundColor: isDark ? null : HubStyle.surface,
      appBar: HubStyle.appBar(titleText: 'Mapa día / noche'),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(20, 12, 20, 28),
        children: [
          Text(
            'Elige el aspecto del mapa en navegación. '
            'La preferencia se guarda en este dispositivo.',
            style: HubStyle.body(),
          ),
          const SizedBox(height: 16),
          for (final mode in MapAppearanceMode.values) ...[
            _ModeCard(
              mode: mode,
              selected: appearance.mode == mode,
              isDark: isDark,
              onTap: () =>
                  ref.read(mapAppearanceProvider.notifier).setMode(mode),
            ),
            const SizedBox(height: 10),
          ],
          const SizedBox(height: 8),
          DecoratedBox(
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(16),
              boxShadow: isDark ? null : HubStyle.cardShadow,
            ),
            child: Material(
              color: isDark
                  ? Theme.of(context).colorScheme.surfaceContainerHighest
                  : Colors.white,
              borderRadius: BorderRadius.circular(16),
              child: Padding(
                padding: const EdgeInsets.all(14),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Icon(
                      Icons.info_outline_rounded,
                      size: 20,
                      color: HubStyle.accent,
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
                        style: HubStyle.caption(),
                      ),
                    ),
                  ],
                ),
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
    required this.isDark,
    required this.onTap,
  });

  final MapAppearanceMode mode;
  final bool selected;
  final bool isDark;
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
    final cardColor = isDark
        ? Theme.of(context).colorScheme.surfaceContainerHighest
        : Colors.white;

    return DecoratedBox(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(16),
        boxShadow: isDark ? null : HubStyle.cardShadow,
        border: selected
            ? Border.all(color: HubStyle.accent, width: 1.6)
            : null,
      ),
      child: Material(
        color: cardColor,
        borderRadius: BorderRadius.circular(16),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.fromLTRB(14, 14, 8, 14),
            child: Row(
              children: [
                Container(
                  width: 48,
                  height: 48,
                  decoration: BoxDecoration(
                    color: selected
                        ? HubStyle.accent
                        : HubStyle.accent.withValues(alpha: 0.12),
                    shape: BoxShape.circle,
                  ),
                  child: Icon(
                    _icon,
                    color: selected ? Colors.white : HubStyle.accent,
                    size: 24,
                  ),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(mode.label, style: HubStyle.sectionTitle()),
                      const SizedBox(height: 4),
                      Text(_detail, style: HubStyle.caption()),
                    ],
                  ),
                ),
                Icon(
                  selected
                      ? Icons.check_circle_rounded
                      : Icons.radio_button_unchecked_rounded,
                  color: HubStyle.accent,
                  size: 26,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
