import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:moto_amg/features/navigation/domain/entities/navigation_route.dart';
import 'package:moto_amg/features/navigation/presentation/providers/navigation_providers.dart';
import 'package:moto_amg/features/settings/presentation/providers/settings_providers.dart';

/// Llama a TomTom solo al confirmar la ruta (antes de abrir el HUD),
/// y solo si está activado en Configuración → Uso de APIs.
///
/// Si falla, sigue con la ruta (límites OSM/DGT).
Future<NavigationRoute> enrichRouteLimitsBeforeNavigation({
  required BuildContext context,
  required WidgetRef ref,
  required NavigationRoute route,
}) async {
  if (!ref.read(tomtomPreferencesProvider).enabled) {
    return route;
  }
  if (!context.mounted) {
    return route;
  }

  showDialog<void>(
    context: context,
    barrierDismissible: false,
    builder: (ctx) {
      final colors = Theme.of(ctx).colorScheme;
      return PopScope(
        canPop: false,
        child: AlertDialog(
          title: const Text('Preparando navegación'),
          content: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              SizedBox(
                width: 28,
                height: 28,
                child: CircularProgressIndicator(
                  strokeWidth: 3,
                  color: colors.primary,
                ),
              ),
              const SizedBox(width: 20),
              Expanded(
                child: Text(
                  'Actualizando límites de velocidad de la ruta…',
                  style: Theme.of(ctx).textTheme.bodyMedium,
                ),
              ),
            ],
          ),
        ),
      );
    },
  );

  var updated = route;
  try {
    final enrichment = await ref
        .read(navigationRepositoryProvider)
        .enrichRouteWithTomTomDetails(route);
    if (enrichment != null) {
      updated = enrichment.route;
      ref.read(apiUsageTrackerProvider).saveTomTomRoutePreview(enrichment);
    }
  } catch (_) {
    // Sin TomTom: OSM/DGT ya van en la ruta.
  }

  if (context.mounted) {
    Navigator.of(context, rootNavigator: true).pop();
  }
  return updated;
}
