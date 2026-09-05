import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:moto_amg/core/theme/hub_style.dart';
import 'package:moto_amg/core/utils/spain_data_freshness.dart';
import 'package:moto_amg/features/navigation/data/datasources/spain_fuel_datasource.dart';
import 'package:moto_amg/features/navigation/presentation/providers/navigation_providers.dart';

/// Descarga manual del inventario MITECO de gasolineras (precios).
class FuelCacheSettingsScreen extends ConsumerWidget {
  const FuelCacheSettingsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final statusAsync = ref.watch(spainFuelCacheStatusProvider);
    final download = ref.watch(fuelCacheDownloadProvider);
    final busy = download.downloading;
    final isDark = Theme.of(context).brightness == Brightness.dark;

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
      backgroundColor: isDark ? null : HubStyle.surface,
      appBar: HubStyle.appBar(titleText: 'Gasolineras offline'),
      body: statusAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (_, _) => Center(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  'No se pudo leer la caché de gasolineras.',
                  textAlign: TextAlign.center,
                  style: HubStyle.body(),
                ),
                const SizedBox(height: 12),
                FilledButton(
                  style: HubStyle.filledButtonStyle(),
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
            padding: const EdgeInsets.fromLTRB(20, 12, 20, 28),
            children: [
              Text(
                'Descarga el inventario oficial de carburantes (MITECO) desde '
                'el servidor MotoAMG. Con Wi‑Fi es rápido y luego puedes ver '
                'precios en la ruta sin consultar la red en cada viaje.',
                style: HubStyle.body(),
              ),
              const SizedBox(height: 16),
              _StatusCard(status: status, isDark: isDark),
              if (status.isReady && isSpainFuelDataStale(status.fetchedAt)) ...[
                const SizedBox(height: 12),
                _StaleWarning(
                  message: spainFuelStaleMessage(status.fetchedAt),
                ),
              ],
              const SizedBox(height: 16),
              if (busy) ...[
                LinearProgressIndicator(
                  value: download.progress?.fraction,
                  minHeight: 6,
                  borderRadius: BorderRadius.circular(99),
                  color: HubStyle.accent,
                ),
                const SizedBox(height: 8),
                Text(
                  download.progress?.label ?? 'Descargando…',
                  style: HubStyle.caption(),
                ),
                const SizedBox(height: 12),
                OutlinedButton(
                  style: HubStyle.outlinedButtonStyle(),
                  onPressed: () =>
                      ref.read(fuelCacheDownloadProvider.notifier).cancel(),
                  child: const Text('Cancelar'),
                ),
              ] else
                FilledButton.icon(
                  style: HubStyle.filledButtonStyle(),
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
                style: HubStyle.caption(),
              ),
            ],
          );
        },
      ),
    );
  }
}

class _StatusCard extends StatelessWidget {
  const _StatusCard({required this.status, required this.isDark});

  final SpainFuelCacheStatus status;
  final bool isDark;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return DecoratedBox(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(16),
        boxShadow: isDark ? null : HubStyle.cardShadow,
      ),
      child: Material(
        color: isDark ? colors.surfaceContainerHighest : Colors.white,
        borderRadius: BorderRadius.circular(16),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
          child: Row(
            children: [
              Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  color: status.isReady
                      ? HubStyle.accent
                      : HubStyle.accent.withValues(alpha: 0.12),
                  shape: BoxShape.circle,
                ),
                child: Icon(
                  status.isReady
                      ? Icons.download_done
                      : Icons.cloud_off_outlined,
                  color: status.isReady ? Colors.white : HubStyle.accent,
                  size: 22,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Inventario MITECO', style: HubStyle.sectionTitle()),
                    const SizedBox(height: 2),
                    Text(
                      status.isReady
                          ? '${status.count} estaciones · '
                              '${formatSpainDataAge(status.fetchedAt)}'
                          : 'Sin descargar',
                      style: HubStyle.caption(
                        color: status.isReady &&
                                isSpainFuelDataStale(status.fetchedAt)
                            ? colors.error
                            : null,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
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
                style: HubStyle.caption(color: colors.onErrorContainer),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
