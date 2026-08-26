import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:loc_motos/core/utils/spain_data_freshness.dart';
import 'package:loc_motos/features/navigation/data/datasources/spain_radar_datasource.dart';
import 'package:loc_motos/features/navigation/presentation/providers/navigation_providers.dart';

/// Descarga manual del inventario de radares (DGT/SCT + OSM España).
class RadarCacheSettingsScreen extends ConsumerWidget {
  const RadarCacheSettingsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final statusAsync = ref.watch(spainRadarCacheStatusProvider);
    final download = ref.watch(radarCacheDownloadProvider);
    final busy = download.downloading;
    final colors = Theme.of(context).colorScheme;

    ref.listen(radarCacheDownloadProvider, (previous, next) {
      final message = next.snackMessage;
      if (message == null || message == previous?.snackMessage) {
        return;
      }
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(message)),
      );
    });

    return Scaffold(
      appBar: AppBar(title: const Text('Radares offline')),
      body: statusAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (_, _) => Center(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Text(
                  'No se pudo leer la caché de radares.',
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 12),
                FilledButton(
                  onPressed: () =>
                      ref.invalidate(spainRadarCacheStatusProvider),
                  child: const Text('Reintentar'),
                ),
              ],
            ),
          ),
        ),
        data: (status) {
          final stale = isSpainRadarCacheStale(
            hasOfficial: status.hasOfficial,
            officialFetchedAt: status.officialFetchedAt,
            hasOsm: status.hasOsm,
            osmFetchedAt: status.osmFetchedAt,
          );
          final staleMessage = spainRadarCacheStaleMessage(
            hasOfficial: status.hasOfficial,
            officialFetchedAt: status.officialFetchedAt,
            hasOsm: status.hasOsm,
            osmFetchedAt: status.osmFetchedAt,
          );
          return ListView(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
            children: [
              Text(
                'Descarga el inventario de España desde el servidor LocMotos '
                '(DGT, SCT y OpenStreetMap). Con Wi‑Fi es rápido y luego '
                'puedes usarlo en las rutas sin cobertura.',
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                      color: colors.onSurfaceVariant,
                    ),
              ),
              const SizedBox(height: 16),
              _StatusCard(status: status),
              if (status.isReady && stale) ...[
                const SizedBox(height: 12),
                _StaleWarning(message: staleMessage),
              ],
              const SizedBox(height: 16),
              if (busy) ...[
                LinearProgressIndicator(
                  value: download.progress?.fraction,
                  minHeight: 6,
                  borderRadius: BorderRadius.circular(99),
                ),
                const SizedBox(height: 8),
                Text(
                  download.progress?.label ?? 'Descargando…',
                  style: Theme.of(context).textTheme.bodySmall,
                ),
                const SizedBox(height: 12),
                OutlinedButton(
                  onPressed: () =>
                      ref.read(radarCacheDownloadProvider.notifier).cancel(),
                  child: const Text('Cancelar'),
                ),
              ] else
                FilledButton.icon(
                  onPressed: () =>
                      ref.read(radarCacheDownloadProvider.notifier).download(),
                  icon: const Icon(Icons.download),
                  label: Text(
                    status.isReady ? 'Actualizar radares' : 'Descargar radares',
                  ),
                ),
              const SizedBox(height: 12),
              Text(
                'El fichero lo genera el servidor a diario. '
                'Actualízalo de vez en cuando para tener datos recientes.',
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: colors.onSurfaceVariant,
                    ),
              ),
            ],
          );
        },
      ),
    );
  }
}

class _StatusCard extends StatelessWidget {
  const _StatusCard({required this.status});

  final SpainRadarCacheStatus status;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return Material(
      color: colors.surfaceContainerHighest,
      borderRadius: BorderRadius.circular(12),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        child: Column(
          children: [
            _StatusRow(
              icon: status.hasOfficial
                  ? Icons.download_done
                  : Icons.cloud_off_outlined,
              title: 'Oficiales (DGT / SCT)',
              detail: status.hasOfficial
                  ? '${status.officialCount} radares · '
                      '${formatSpainDataAge(status.officialFetchedAt)}'
                  : 'Sin descargar',
              stale: status.hasOfficial &&
                  isSpainRadarDataStale(status.officialFetchedAt),
              ok: status.hasOfficial,
            ),
            const Divider(height: 20),
            _StatusRow(
              icon: status.hasOsm
                  ? Icons.download_done
                  : Icons.cloud_off_outlined,
              title: 'OpenStreetMap España',
              detail: status.hasOsm
                  ? '${status.osmCount} radares · '
                      '${formatSpainDataAge(status.osmFetchedAt)}'
                  : 'Sin descargar',
              stale:
                  status.hasOsm && isSpainRadarDataStale(status.osmFetchedAt),
              ok: status.hasOsm,
            ),
          ],
        ),
      ),
    );
  }
}

class _StatusRow extends StatelessWidget {
  const _StatusRow({
    required this.icon,
    required this.title,
    required this.detail,
    required this.ok,
    this.stale = false,
  });

  final IconData icon;
  final String title;
  final String detail;
  final bool ok;
  final bool stale;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return Row(
      children: [
        Icon(icon, color: ok ? colors.primary : colors.onSurfaceVariant),
        const SizedBox(width: 10),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(title, style: Theme.of(context).textTheme.titleSmall),
              const SizedBox(height: 2),
              Text(
                detail,
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: stale ? colors.error : colors.onSurfaceVariant,
                    ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _StaleWarning extends StatelessWidget {
  const _StaleWarning({required this.message});

  final String message;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return Material(
      color: colors.errorContainer.withValues(alpha: 0.45),
      borderRadius: BorderRadius.circular(12),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(Icons.warning_amber_rounded, color: colors.error, size: 22),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                message,
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: colors.onErrorContainer,
                    ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
