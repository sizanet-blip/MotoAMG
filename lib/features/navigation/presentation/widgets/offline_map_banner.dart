import 'package:flutter/material.dart';
import 'package:loc_motos/features/settings/presentation/screens/offline_maps_settings_screen.dart';

/// Aviso de sin red + acceso a descarga de mapas offline.
class OfflineMapBanner extends StatelessWidget {
  const OfflineMapBanner({
    super.key,
    this.compact = false,
  });

  /// Menos padding / texto más corto (p. ej. preview).
  final bool compact;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;

    return Material(
      color: colors.inverseSurface.withValues(alpha: 0.94),
      borderRadius: BorderRadius.circular(12),
      elevation: 2,
      child: Padding(
        padding: EdgeInsets.fromLTRB(
          14,
          compact ? 8 : 10,
          8,
          compact ? 8 : 10,
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            Icon(
              Icons.wifi_off_rounded,
              size: 22,
              color: colors.onInverseSurface,
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                compact
                    ? 'Sin conexión. Solo verás las zonas descargadas.'
                    : 'Sin conexión. Solo puedes ver el mapa de las zonas '
                        'que hayas descargado.',
                style: textTheme.bodySmall?.copyWith(
                  color: colors.onInverseSurface,
                ),
              ),
            ),
            TextButton(
              onPressed: () {
                Navigator.of(context).push(
                  MaterialPageRoute<void>(
                    builder: (_) => const OfflineMapsSettingsScreen(),
                  ),
                );
              },
              style: TextButton.styleFrom(
                foregroundColor: colors.onInverseSurface,
                padding: const EdgeInsets.symmetric(horizontal: 8),
              ),
              child: const Text('Mapas'),
            ),
          ],
        ),
      ),
    );
  }
}
