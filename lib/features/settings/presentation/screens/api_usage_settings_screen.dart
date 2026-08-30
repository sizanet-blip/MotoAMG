import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:loc_motos/core/api_usage/api_usage_tracker.dart';
import 'package:loc_motos/core/constants/navigation_constants.dart';
import 'package:loc_motos/features/settings/presentation/providers/settings_providers.dart';

/// Estado de consumo de APIs externas en esta sesión de la app.
class ApiUsageSettingsScreen extends ConsumerWidget {
  const ApiUsageSettingsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final tracker = ref.watch(apiUsageTrackerProvider);
    final tomtom = tracker.statsFor(LocMotosApi.tomtomSnapToRoads);
    final keyConfigured = NavigationConstants.tomtomApiKey.trim().isNotEmpty;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Uso de APIs'),
        actions: [
          TextButton(
            onPressed: () => tracker.reset(),
            child: const Text('Reiniciar'),
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
        children: [
          Text(
            'Contadores de esta sesión (desde que abriste la app). '
            'El cupo oficial lo ves en el panel de TomTom.',
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  color: Theme.of(context).colorScheme.onSurfaceVariant,
                ),
          ),
          const SizedBox(height: 16),
          _ApiCard(
            title: LocMotosApi.tomtomSnapToRoads.label,
            configured: keyConfigured,
            configuredLabel: keyConfigured
                ? 'API key presente en este build'
                : 'Sin API key (--dart-define)',
            stats: tomtom,
          ),
        ],
      ),
    );
  }
}

class _ApiCard extends StatelessWidget {
  const _ApiCard({
    required this.title,
    required this.configured,
    required this.configuredLabel,
    required this.stats,
  });

  final String title;
  final bool configured;
  final String configuredLabel;
  final ApiUsageStats stats;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final last = stats.last;
    final statusColor = switch (last?.outcome) {
      ApiCallOutcome.success => Colors.green.shade700,
      ApiCallOutcome.failure => theme.colorScheme.error,
      ApiCallOutcome.skipped => theme.colorScheme.onSurfaceVariant,
      null => theme.colorScheme.onSurfaceVariant,
    };
    final statusText = switch (last?.outcome) {
      ApiCallOutcome.success => 'Última: OK',
      ApiCallOutcome.failure => 'Última: Error',
      ApiCallOutcome.skipped => 'Última: Omitida',
      null => 'Aún no se ha llamado',
    };

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(title, style: theme.textTheme.titleMedium),
            const SizedBox(height: 8),
            Row(
              children: [
                Icon(
                  configured ? Icons.check_circle_outline : Icons.warning_amber,
                  size: 18,
                  color: configured
                      ? Colors.green.shade700
                      : theme.colorScheme.error,
                ),
                const SizedBox(width: 8),
                Expanded(child: Text(configuredLabel)),
              ],
            ),
            const SizedBox(height: 12),
            Text('OK: ${stats.successCount}  ·  Fallos: ${stats.failureCount}  ·  Omitidas: ${stats.skippedCount}'),
            const SizedBox(height: 8),
            Text(
              statusText,
              style: TextStyle(
                fontWeight: FontWeight.w600,
                color: statusColor,
              ),
            ),
            if (last?.message != null) ...[
              const SizedBox(height: 4),
              Text(last!.message!),
            ],
            if (last != null) ...[
              const SizedBox(height: 4),
              Text(
                _formatTime(last.at),
                style: theme.textTheme.bodySmall,
              ),
            ],
          ],
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
