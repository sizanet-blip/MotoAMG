import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:moto_amg/core/theme/hub_style.dart';
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
    final isDark = Theme.of(context).brightness == Brightness.dark;
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
      backgroundColor: isDark ? null : HubStyle.surface,
      appBar: HubStyle.appBar(titleText: 'Mapas offline'),
      body: regionsAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (_, _) => Center(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  'No se pudieron cargar las regiones.',
                  textAlign: TextAlign.center,
                  style: HubStyle.body(),
                ),
                const SizedBox(height: 12),
                FilledButton(
                  style: HubStyle.filledButtonStyle(),
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
            return Center(
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Text(
                  'No hay regiones disponibles por ahora.',
                  textAlign: TextAlign.center,
                  style: HubStyle.body(),
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
            padding: const EdgeInsets.fromLTRB(20, 12, 20, 28),
            children: [
              Text(
                'Descarga un mapa para usarlo sin internet dentro de esa zona '
                '(calles, nombres e iconos). '
                'Si se corta la descarga, pulsa Continuar para reanudarla. '
                'Fuera de la región (con internet) se usa el mapa online.',
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
                  child: Padding(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 14,
                      vertical: 12,
                    ),
                    child: Row(
                      children: [
                        Container(
                          width: 44,
                          height: 44,
                          decoration: const BoxDecoration(
                            color: HubStyle.accent,
                            shape: BoxShape.circle,
                          ),
                          child: const Icon(
                            Icons.offline_pin,
                            color: Colors.white,
                            size: 22,
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Text(
                            downloaded == 0
                                ? 'Ninguna región descargada'
                                : '$downloaded de ${regions.length} descargadas'
                                    '${downloadedMb >= 1 ? ' · ${downloadedMb.round()} MB' : ''}',
                            style: HubStyle.sectionTitle(),
                          ),
                        ),
                      ],
                    ),
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
                  isDark: isDark,
                  onDownload: () => ref
                      .read(mapRegionActionProvider.notifier)
                      .download(region.id),
                  onCancel: () =>
                      ref.read(mapRegionActionProvider.notifier).cancelDownload(),
                  onDelete: () => ref
                      .read(mapRegionActionProvider.notifier)
                      .delete(region.id),
                ),
                const SizedBox(height: 10),
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
    required this.isDark,
    required this.onDownload,
    required this.onCancel,
    required this.onDelete,
  });

  final MapRegion region;
  final bool busy;
  final bool downloading;
  final double? progress;
  final ({int received, int? total})? bytes;
  final bool isDark;
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

    return DecoratedBox(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(16),
        boxShadow: isDark ? null : HubStyle.cardShadow,
      ),
      child: Material(
        color: isDark ? colors.surfaceContainerHighest : Colors.white,
        borderRadius: BorderRadius.circular(16),
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 12, 12, 12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                children: [
                  Container(
                    width: 44,
                    height: 44,
                    decoration: BoxDecoration(
                      color: region.isDownloaded
                          ? HubStyle.accent
                          : HubStyle.accent.withValues(alpha: 0.12),
                      shape: BoxShape.circle,
                    ),
                    child: Icon(
                      region.isDownloaded
                          ? Icons.download_done
                          : region.hasPartialDownload
                              ? Icons.pause_circle_outline
                              : Icons.map_outlined,
                      color: region.isDownloaded
                          ? Colors.white
                          : HubStyle.accent,
                      size: 22,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(region.name, style: HubStyle.sectionTitle()),
                        const SizedBox(height: 2),
                        Text(
                          region.isDownloaded
                              ? 'Descargado · $sizeLabel'
                              : region.hasPartialDownload
                                  ? 'Descarga a medias · $partialLabel'
                                  : '$sizeLabel aprox.',
                          style: HubStyle.caption(
                            color: region.hasPartialDownload
                                ? colors.tertiary
                                : null,
                          ),
                        ),
                      ],
                    ),
                  ),
                  if (region.isDownloaded)
                    TextButton(
                      style: HubStyle.textButtonStyle(),
                      onPressed: busy ? null : onDelete,
                      child: const Text('Eliminar'),
                    )
                  else if (downloading)
                    TextButton(
                      style: HubStyle.textButtonStyle(),
                      onPressed: onCancel,
                      child: const Text('Cancelar'),
                    )
                  else
                    FilledButton(
                      style: HubStyle.filledButtonStyle(enabled: !busy),
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
                  color: HubStyle.accent,
                ),
              ],
              if (downloading) ...[
                const SizedBox(height: 12),
                LinearProgressIndicator(
                  value: progress,
                  minHeight: 6,
                  borderRadius: BorderRadius.circular(99),
                  color: HubStyle.accent,
                ),
                const SizedBox(height: 6),
                Text(
                  _progressLabel(progress, bytes),
                  style: HubStyle.caption(),
                ),
              ],
            ],
          ),
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
