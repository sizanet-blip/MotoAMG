import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:loc_motos/features/navigation/domain/entities/route_preferences.dart';
import 'package:loc_motos/features/navigation/presentation/providers/navigation_providers.dart';

/// Botones Curvatura / Evitaciones (estilo Kurviger) para el sheet del itinerario.
class RoutePreferencesBar extends ConsumerWidget {
  const RoutePreferencesBar({
    super.key,
    this.enabled = true,
    this.showCurvature = true,
  });

  final bool enabled;
  final bool showCurvature;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final prefs = ref.watch(routePreferencesProvider);
    final colors = Theme.of(context).colorScheme;

    return Row(
      children: [
        if (showCurvature) ...[
          Expanded(
            child: OutlinedButton(
              onPressed: enabled
                  ? () => _openCurvatureSheet(context, ref, prefs)
                  : null,
              style: OutlinedButton.styleFrom(
                padding:
                    const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.route, size: 18, color: colors.primary),
                  const SizedBox(width: 6),
                  Flexible(
                    child: Text(
                      prefs.curvature.label,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(fontWeight: FontWeight.w600),
                    ),
                  ),
                  const Icon(Icons.expand_more, size: 18),
                ],
              ),
            ),
          ),
          const SizedBox(width: 8),
        ],
        Expanded(
          child: OutlinedButton(
            onPressed: enabled
                ? () => _openAvoidancesSheet(context, ref, prefs)
                : null,
            style: OutlinedButton.styleFrom(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.block, size: 18, color: colors.primary),
                const SizedBox(width: 6),
                const Flexible(
                  child: Text(
                    'Evitaciones',
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(fontWeight: FontWeight.w600),
                  ),
                ),
                if (prefs.activeAvoidanceCount > 0) ...[
                  const SizedBox(width: 4),
                  CircleAvatar(
                    radius: 9,
                    backgroundColor: colors.primary,
                    child: Text(
                      '${prefs.activeAvoidanceCount}',
                      style: TextStyle(
                        color: colors.onPrimary,
                        fontSize: 11,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                ],
                const Icon(Icons.expand_more, size: 18),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Future<void> _openCurvatureSheet(
    BuildContext context,
    WidgetRef ref,
    RoutePreferences prefs,
  ) async {
    await showModalBottomSheet<void>(
      context: context,
      showDragHandle: true,
      builder: (context) {
        return SafeArea(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 4, 16, 8),
                child: Text(
                  'Estilo de ruta',
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.w700,
                      ),
                ),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
                child: Text(
                  'Combina vías rápidas/secundarias y pide alternativas. '
                  'En Secundarias / Solo secundarias se elige la opción con '
                  'más giros entre las que devuelve Valhalla.',
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: Theme.of(context).colorScheme.onSurfaceVariant,
                      ),
                ),
              ),
              for (final level in RouteCurvatureLevel.values)
                ListTile(
                  title: Text(level.label),
                  subtitle: Text(level.shortHint),
                  selected: prefs.curvature == level,
                  trailing: prefs.curvature == level
                      ? Icon(
                          Icons.check_circle,
                          color: Theme.of(context).colorScheme.primary,
                        )
                      : const Icon(Icons.circle_outlined),
                  onTap: () {
                    ref
                        .read(routePreferencesProvider.notifier)
                        .setCurvature(level);
                    Navigator.pop(context);
                  },
                ),
              const SizedBox(height: 8),
            ],
          ),
        );
      },
    );
  }

  Future<void> _openAvoidancesSheet(
    BuildContext context,
    WidgetRef ref,
    RoutePreferences prefs,
  ) async {
    await showModalBottomSheet<void>(
      context: context,
      showDragHandle: true,
      builder: (context) {
        return Consumer(
          builder: (context, ref, _) {
            final current = ref.watch(routePreferencesProvider);
            final notifier = ref.read(routePreferencesProvider.notifier);
            return SafeArea(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Padding(
                    padding: const EdgeInsets.fromLTRB(16, 4, 16, 8),
                    child: Text(
                      'Evitaciones',
                      style: Theme.of(context).textTheme.titleMedium?.copyWith(
                            fontWeight: FontWeight.w700,
                          ),
                    ),
                  ),
                  SwitchListTile(
                    title: const Text('Autovías / autopistas'),
                    subtitle: const Text(
                      'Se combina con el estilo: Rápida permite más, '
                      'Solo secundarias casi ninguna',
                    ),
                    value: current.avoidHighways,
                    onChanged: notifier.setAvoidHighways,
                  ),
                  SwitchListTile(
                    title: const Text('Peajes'),
                    value: current.avoidTolls,
                    onChanged: notifier.setAvoidTolls,
                  ),
                  SwitchListTile(
                    title: const Text('Sin asfaltar'),
                    subtitle: const Text('Pistas, tracks y malas superficies'),
                    value: current.avoidUnpaved,
                    onChanged: notifier.setAvoidUnpaved,
                  ),
                  SwitchListTile(
                    title: const Text('Ferries'),
                    value: current.avoidFerries,
                    onChanged: notifier.setAvoidFerries,
                  ),
                  const SizedBox(height: 8),
                ],
              ),
            );
          },
        );
      },
    );
  }
}
