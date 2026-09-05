import 'package:flutter/material.dart';
import 'package:moto_amg/core/theme/hub_style.dart';
import 'package:moto_amg/features/settings/presentation/screens/offline_maps_settings_screen.dart';

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
    return DecoratedBox(
      decoration: BoxDecoration(
        color: const Color(0xFF1F2937).withValues(alpha: 0.94),
        borderRadius: BorderRadius.circular(12),
        boxShadow: HubStyle.cardShadow,
      ),
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
            const Icon(
              Icons.wifi_off_rounded,
              size: 22,
              color: Colors.white,
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                compact
                    ? 'Sin conexión. Solo verás las zonas descargadas.'
                    : 'Sin conexión. Solo puedes ver el mapa de las zonas '
                        'que hayas descargado.',
                style: HubStyle.caption(color: Colors.white),
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
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(horizontal: 8),
              ),
              child: Text(
                'Mapas',
                style: HubStyle.caption(color: Colors.white).copyWith(
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
