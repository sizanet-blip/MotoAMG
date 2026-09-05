import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:moto_amg/core/utils/storage_space.dart';
import 'package:moto_amg/features/navigation/domain/entities/map_region.dart';
import 'package:moto_amg/features/navigation/domain/exceptions/navigation_user_message.dart';
import 'package:moto_amg/features/navigation/presentation/providers/navigation_providers.dart';

/// Descarga de regiones PMTiles para mapas offline.
class OfflineMapsSettingsScreen extends ConsumerWidget {
  const OfflineMapsSettingsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final regionsAsync = ref.watch(availableMapRegionsProvider);
    final action = ref.watch(mapRegionActionProvider);
    final busy = action.isLoading;
    final downloadingId = ref.watch(mapDownloadingRegionIdProvider);
    final progress = ref.watch(mapDownloadProgressProvider);
    final bytes = ref.watch(mapDownloadBytesProvider);
    final colors = Theme.of(context).colorScheme;

    ref.listen(mapRegionActionProvider, (previous, next) {
      next.whenOrNull(
        error: (error, _) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text(navigationUserMessage(error))),
          );
        },
        data: (_) {
          if (previous?.isLoading != true) {
            return;
          }
          final kind = ref.read(mapRegionLastActionProvider);
          final message = switch (kind) {
            'download' => 'Mapa listo para usar sin internet.',
            'delete' => 'Mapa eliminado del dispositivo.',
            _ => null,
          };
          if (message == null) {
            return;
          }
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text(message)),
          );
        },
      );
    });

    return Scaffold(
      appBar: AppBar(title: const Text('Mapas offline')),
      body: regionsAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (_, _) => Center(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Text(
                  'No se pudieron cargar las regiones.',
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 12),
                FilledButton(
                  onPressed: () =>
                      ref.invalidate(availableMapRegionsProvider),
                  child: const Text('Reintentar'),
                ),
              ],
            ),
          ),
        ),
        data: (regions) {
          if (regions.isEmpty) {
            return const Center(
              child: Padding(
                padding: EdgeInsets.all(24),
                child: Text(
                  'No hay regiones disponibles por ahora.',
                  textAlign: TextAlign.center,
                ),
              ),
            );
          }
          final downloaded =
              regions.where((region) => region.isDownloaded).length;
          final downloadedMb = regions
                  .where((region) => region.isDownloaded)
                  .fold<int>(0, (sum, region) => sum + region.sizeBytes) /
              (1024 * 1024);

          return ListView(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
            children: [
              Text(
                'Descarga un mapa para usarlo sin internet dentro de esa zona '
                '(calles, nombres e iconos). '
                'Si se corta la descarga, pulsa Continuar para reanudarla. '
                'Fuera de la región (con internet) se usa el mapa online.',
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                      color: colors.onSurfaceVariant,
                    ),
              ),
              const SizedBox(height: 12),
              Material(
                color: colors.surfaceContainerHighest,
                borderRadius: BorderRadius.circular(12),
                child: Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 14,
                    vertical: 12,
                  ),
                  child: Row(
                    children: [
                      Icon(Icons.offline_pin, color: colors.primary),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Text(
                          downloaded == 0
                              ? 'Ninguna región descargada'
                              : '$downloaded de ${regions.length} descargadas'
                                  '${downloadedMb >= 1 ? ' · ${downloadedMb.round()} MB' : ''}',
                          style: Theme.of(context).textTheme.titleSmall,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 16),
              for (final region in regions) ...[
                _RegionCard(
                  region: region,
                  busy: busy,
                  downloading: downloadingId == region.id,
                  progress: downloadingId == region.id ? progress : null,
                  bytes: downloadingId == region.id ? bytes : null,
                  onDownload: () => ref
                      .read(mapRegionActionProvider.notifier)
                      .download(region.id),
                  onCancel: () =>
                      ref.read(mapRegionActionProvider.notifier).cancelDownload(),
                  onDelete: () => ref
                      .read(mapRegionActionProvider.notifier)
                      .delete(region.id),
                ),
                const SizedBox(height: 8),
              ],
            ],
          );
        },
      ),
    );
  }
}

class _RegionCard extends StatelessWidget {
  const _RegionCard({
    required this.region,
    required this.busy,
    required this.downloading,
    required this.progress,
    required this.bytes,
    required this.onDownload,
    required this.onCancel,
    required this.onDelete,
  });

  final MapRegion region;
  final bool busy;
  final bool downloading;
  final double? progress;
  final ({int received, int? total})? bytes;
  final VoidCallback onDownload;
  final VoidCallback onCancel;
  final VoidCallback onDelete;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final sizeLabel = formatStorageMb(region.sizeBytes);
    final partialLabel = region.hasPartialDownload
        ? '${formatStorageMb(region.partialBytes)} de $sizeLabel'
        : null;

    return Card(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 12, 12, 12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                Icon(
                  region.isDownloaded
                      ? Icons.download_done
                      : region.hasPartialDownload
                          ? Icons.pause_circle_outline
                          : Icons.map_outlined,
                  color: region.isDownloaded
                      ? colors.primary
                      : region.hasPartialDownload
                          ? colors.tertiary
                          : colors.onSurfaceVariant,
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        region.name,
                        style: Theme.of(context).textTheme.titleMedium,
                      ),
                      const SizedBox(height: 2),
                      Text(
                        region.isDownloaded
                            ? 'Descargado · $sizeLabel'
                            : region.hasPartialDownload
                                ? 'Descarga a medias · $partialLabel'
                                : '$sizeLabel aprox.',
                        style: Theme.of(context).textTheme.bodySmall?.copyWith(
                              color: region.hasPartialDownload
                                  ? colors.tertiary
                                  : colors.onSurfaceVariant,
                            ),
                      ),
                    ],
                  ),
                ),
                if (region.isDownloaded)
                  TextButton(
                    onPressed: busy ? null : onDelete,
                    child: const Text('Eliminar'),
                  )
                else if (downloading)
                  TextButton(
                    onPressed: onCancel,
                    child: const Text('Cancelar'),
                  )
                else
                  FilledButton(
                    onPressed: busy ? null : onDownload,
                    child: Text(
                      region.hasPartialDownload ? 'Continuar' : 'Descargar',
                    ),
                  ),
              ],
            ),
            if (region.hasPartialDownload && !downloading) ...[
              const SizedBox(height: 10),
              LinearProgressIndicator(
                value: region.partialProgress,
                minHeight: 5,
                borderRadius: BorderRadius.circular(99),
              ),
            ],
            if (downloading) ...[
              const SizedBox(height: 12),
              LinearProgressIndicator(
                value: progress,
                minHeight: 6,
                borderRadius: BorderRadius.circular(99),
              ),
              const SizedBox(height: 6),
              Text(
                _progressLabel(progress, bytes),
                style: Theme.of(context).textTheme.bodySmall,
              ),
            ],
          ],
        ),
      ),
    );
  }

  static String _progressLabel(
    double? progress,
    ({int received, int? total})? bytes,
  ) {
    if (bytes == null) {
      return 'Preparando descarga…';
    }
    final received = formatStorageMb(bytes.received);
    if (bytes.total != null && bytes.total! > 0) {
      final total = formatStorageMb(bytes.total!);
      final pct = progress == null
          ? ''
          : ' · ${(progress * 100).clamp(0, 100).round()} %';
      return '$received / $total$pct';
    }
    return 'Descargando… $received';
  }
}
