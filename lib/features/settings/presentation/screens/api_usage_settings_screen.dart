import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:moto_amg/core/api_usage/api_usage_tracker.dart';
import 'package:moto_amg/core/constants/navigation_constants.dart';
import 'package:moto_amg/core/theme/hub_style.dart';
import 'package:moto_amg/features/navigation/presentation/providers/navigation_providers.dart';
import 'package:moto_amg/features/settings/presentation/providers/settings_providers.dart';
import 'package:moto_amg/features/settings/presentation/screens/tomtom_route_preview_screen.dart';

/// TomTom on/off + contadores de consumo de APIs en esta sesión.
class ApiUsageSettingsScreen extends ConsumerWidget {
  const ApiUsageSettingsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final tracker = ref.watch(apiUsageTrackerProvider);
    final tomtomPrefs = ref.watch(tomtomPreferencesProvider);
    final tomtom = tracker.statsFor(MotoAmgApi.tomtomSnapToRoads);
    final lastRoute = tracker.lastTomTomRoute;
    final keyConfigured = NavigationConstants.tomtomApiKey.trim().isNotEmpty;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final colors = Theme.of(context).colorScheme;

    return Scaffold(
      backgroundColor: isDark ? null : HubStyle.surface,
      appBar: HubStyle.appBar(
        titleText: 'Uso de APIs',
        actions: [
          TextButton(
            style: HubStyle.textButtonStyle(),
            onPressed: () => tracker.reset(),
            child: const Text('Reiniciar'),
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(20, 12, 20, 28),
        children: [
          Text(
            'TomTom mejora los límites de velocidad al empezar a navegar. '
            'Por defecto está desactivado (solo OSM/DGT).',
            style: HubStyle.body(),
          ),
          const SizedBox(height: 12),
          DecoratedBox(
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(16),
              boxShadow: isDark ? null : HubStyle.cardShadow,
            ),
            child: Material(
              color: isDark ? colors.surfaceContainerHighest : Colors.white,
              borderRadius: BorderRadius.circular(16),
              clipBehavior: Clip.antiAlias,
              child: SwitchListTile(
                secondary: Container(
                  width: 44,
                  height: 44,
                  decoration: const BoxDecoration(
                    color: HubStyle.accent,
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(
                    Icons.speed_rounded,
                    color: Colors.white,
                    size: 22,
                  ),
                ),
                title: Text('Límites TomTom', style: HubStyle.sectionTitle()),
                subtitle: Text(
                  tomtomPrefs.enabled
                      ? 'Activo: se llama al confirmar «Empezar navegación»'
                      : 'Desactivado: límites solo OSM/DGT',
                  style: HubStyle.caption(),
                ),
                value: tomtomPrefs.enabled,
                activeThumbColor: HubStyle.accent,
                activeTrackColor: HubStyle.accent.withValues(alpha: 0.45),
                onChanged: keyConfigured
                    ? (value) => ref
                        .read(tomtomPreferencesProvider.notifier)
                        .setEnabled(value)
                    : null,
              ),
            ),
          ),
          if (!keyConfigured) ...[
            const SizedBox(height: 8),
            Text(
              'Los límites TomTom no están disponibles en esta versión de la app.',
              style: HubStyle.caption(color: colors.error),
            ),
          ],
          const SizedBox(height: 20),
          Text(
            'Contadores de esta sesión (desde que abriste la app). '
            'El cupo oficial lo ves en el panel de TomTom.',
            style: HubStyle.body(),
          ),
          const SizedBox(height: 16),
          _ApiCard(
            title: MotoAmgApi.tomtomSnapToRoads.label,
            configured: keyConfigured,
            configuredLabel: keyConfigured
                ? 'Listo para usar'
                : 'No disponible en esta versión',
            enabledInSettings: tomtomPrefs.enabled,
            stats: tomtom,
            isDark: isDark,
          ),
          if (lastRoute != null) ...[
            const SizedBox(height: 12),
            FilledButton.icon(
              style: HubStyle.filledButtonStyle(),
              onPressed: () {
                Navigator.of(context).push(
                  MaterialPageRoute<void>(
                    builder: (_) => TomTomRoutePreviewScreen(
                      snapshot: lastRoute,
                    ),
                  ),
                );
              },
              icon: const Icon(Icons.map_outlined),
              label: const Text('Ver y comparar última ruta'),
            ),
            const SizedBox(height: 4),
            Text(
              '${lastRoute.route.originDisplay} → ${lastRoute.route.destinationDisplay} · '
              '${lastRoute.segmentCount} tramos · '
              'consultada a las ${_formatTime(lastRoute.enrichedAt)}',
              style: HubStyle.caption(),
            ),
          ] else ...[
            const SizedBox(height: 12),
            Text(
              'Cuando empieces a navegar con TomTom activado, podrás revisar '
              'aquí la ruta, comparar MotoAMG con TomTom y ver diferencias '
              'sin volver a consultar la API.',
              style: HubStyle.caption(),
            ),
          ],
        ],
      ),
    );
  }

  static String _formatTime(DateTime at) {
    final local = at.toLocal();
    final h = local.hour.toString().padLeft(2, '0');
    final m = local.minute.toString().padLeft(2, '0');
    return '$h:$m';
  }
}

class _ApiCard extends StatelessWidget {
  const _ApiCard({
    required this.title,
    required this.configured,
    required this.configuredLabel,
    required this.enabledInSettings,
    required this.stats,
    required this.isDark,
  });

  final String title;
  final bool configured;
  final String configuredLabel;
  final bool enabledInSettings;
  final ApiUsageStats stats;
  final bool isDark;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final last = stats.last;
    final statusColor = switch (last?.outcome) {
      ApiCallOutcome.success => Colors.green.shade700,
      ApiCallOutcome.failure => colors.error,
      ApiCallOutcome.skipped => HubStyle.subtitle,
      null => HubStyle.subtitle,
    };
    final statusText = switch (last?.outcome) {
      ApiCallOutcome.success => 'Última: OK',
      ApiCallOutcome.failure => 'Última: Error',
      ApiCallOutcome.skipped => 'Última: Omitida',
      null => 'Aún no se ha llamado',
    };

    return DecoratedBox(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(16),
        boxShadow: isDark ? null : HubStyle.cardShadow,
      ),
      child: Material(
        color: isDark ? colors.surfaceContainerHighest : Colors.white,
        borderRadius: BorderRadius.circular(16),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(title, style: HubStyle.sectionTitle()),
              const SizedBox(height: 8),
              Row(
                children: [
                  Icon(
                    configured
                        ? Icons.check_circle_outline
                        : Icons.warning_amber,
                    size: 18,
                    color: configured ? Colors.green.shade700 : colors.error,
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(configuredLabel, style: HubStyle.body()),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              Text(
                enabledInSettings
                    ? 'Preferencia: activado'
                    : 'Preferencia: desactivado',
                style: HubStyle.caption(),
              ),
              const SizedBox(height: 12),
              Text(
                'OK: ${stats.successCount}  ·  Fallos: ${stats.failureCount}  ·  '
                'Omitidas: ${stats.skippedCount}',
                style: HubStyle.body(),
              ),
              const SizedBox(height: 8),
              Text(
                statusText,
                style: HubStyle.sectionTitle(color: statusColor),
              ),
              if (last?.message != null) ...[
                const SizedBox(height: 4),
                Text(last!.message!, style: HubStyle.body()),
              ],
              if (last != null) ...[
                const SizedBox(height: 4),
                Text(_formatTime(last.at), style: HubStyle.caption()),
              ],
            ],
          ),
        ),
      ),
    );
  }

  static String _formatTime(DateTime at) {
    final local = at.toLocal();
    final h = local.hour.toString().padLeft(2, '0');
    final m = local.minute.toString().padLeft(2, '0');
    final s = local.second.toString().padLeft(2, '0');
    return 'Hora: $h:$m:$s';
  }
}
