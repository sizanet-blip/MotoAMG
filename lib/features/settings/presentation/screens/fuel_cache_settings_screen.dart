import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:loc_motos/features/navigation/data/datasources/spain_fuel_datasource.dart';
import 'package:loc_motos/features/navigation/presentation/providers/navigation_providers.dart';

/// Descarga manual del inventario MITECO de gasolineras (precios).
class FuelCacheSettingsScreen extends ConsumerWidget {
  const FuelCacheSettingsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final statusAsync = ref.watch(spainFuelCacheStatusProvider);
    final download = ref.watch(fuelCacheDownloadProvider);
    final busy = download.downloading;
    final colors = Theme.of(context).colorScheme;

    ref.listen(fuelCacheDownloadProvider, (previous, next) {
      final message = next.snackMessage;
      if (message == null || message == previous?.snackMessage) {
        return;
      }
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(message)),
      );
    });

    return Scaffold(
      appBar: AppBar(title: const Text('Gasolineras offline')),
      body: statusAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (_, _) => Center(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Text(
                  'No se pudo leer la caché de gasolineras.',
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 12),
                FilledButton(
                  onPressed: () =>
                      ref.invalidate(spainFuelCacheStatusProvider),
                  child: const Text('Reintentar'),
                ),
              ],
            ),
          ),
        ),
        data: (status) {
          return ListView(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
            children: [
              Text(
                'Descarga el inventario oficial de carburantes (MITECO) desde '
                'el servidor LocMotos. Con Wi‑Fi es rápido y luego puedes ver '
                'precios en la ruta sin consultar la red en cada viaje.',
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                      color: colors.onSurfaceVariant,
                    ),
              ),
              const SizedBox(height: 16),
              _StatusCard(status: status),
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
                      ref.read(fuelCacheDownloadProvider.notifier).cancel(),
                  child: const Text('Cancelar'),
                ),
              ] else
                FilledButton.icon(
                  onPressed: () =>
                      ref.read(fuelCacheDownloadProvider.notifier).download(),
                  icon: const Icon(Icons.download),
                  label: Text(
                    status.isReady
                        ? 'Actualizar gasolineras'
                        : 'Descargar gasolineras',
                  ),
                ),
              const SizedBox(height: 12),
              Text(
                'El fichero se actualiza a diario en el servidor. '
                'Sin esta descarga no habrá gasolineras en los avisos de ruta.',
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

  final SpainFuelCacheStatus status;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return Material(
      color: colors.surfaceContainerHighest,
      borderRadius: BorderRadius.circular(12),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        child: Row(
          children: [
            Icon(
              status.isReady ? Icons.download_done : Icons.cloud_off_outlined,
              color: status.isReady ? colors.primary : colors.onSurfaceVariant,
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Inventario MITECO',
                    style: Theme.of(context).textTheme.titleSmall,
                  ),
                  const SizedBox(height: 2),
                  Text(
                    status.isReady
                        ? '${status.count} estaciones${_formatAt(status.fetchedAt)}'
                        : 'Sin descargar',
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                          color: colors.onSurfaceVariant,
                        ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  static String _formatAt(DateTime? at) {
    if (at == null) {
      return '';
    }
    final local = at.toLocal();
    final d =
        '${local.day.toString().padLeft(2, '0')}/${local.month.toString().padLeft(2, '0')}/${local.year}';
    final t =
        '${local.hour.toString().padLeft(2, '0')}:${local.minute.toString().padLeft(2, '0')}';
    return ' · $d $t';
  }
}
