import 'package:flutter/material.dart';

/// Lat / lng con el mismo contenedor visual que el buscador de direcciones.
class CoordinateEndpointField extends StatelessWidget {
  const CoordinateEndpointField({
    super.key,
    required this.labelText,
    required this.latController,
    required this.lngController,
    required this.enabled,
    required this.prefixIcon,
    this.onUseGps,
    this.onChanged,
  });

  final String labelText;
  final TextEditingController latController;
  final TextEditingController lngController;
  final bool enabled;
  final IconData prefixIcon;
  final VoidCallback? onUseGps;
  final VoidCallback? onChanged;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colors = theme.colorScheme;
    final hasCoords =
        latController.text.trim().isNotEmpty && lngController.text.isNotEmpty;

    return Material(
      color: colors.surfaceContainerLowest,
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(14),
        side: BorderSide(
          color: hasCoords
              ? colors.primary.withValues(alpha: 0.6)
              : colors.outlineVariant,
        ),
      ),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 12, 8, 12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                Icon(prefixIcon, color: colors.primary),
                const SizedBox(width: 12),
                Text(
                  labelText,
                  style: theme.textTheme.labelLarge?.copyWith(
                    color: colors.onSurfaceVariant,
                  ),
                ),
                const Spacer(),
                if (onUseGps != null)
                  IconButton(
                    tooltip: 'Usar mi GPS',
                    onPressed: enabled ? onUseGps : null,
                    icon: Icon(Icons.my_location, color: colors.primary),
                  ),
              ],
            ),
            const SizedBox(height: 8),
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: TextField(
                    controller: latController,
                    enabled: enabled,
                    keyboardType: const TextInputType.numberWithOptions(
                      decimal: true,
                      signed: true,
                    ),
                    decoration: const InputDecoration(
                      labelText: 'Latitud',
                      border: OutlineInputBorder(),
                      isDense: true,
                    ),
                    onChanged: (_) => onChanged?.call(),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: TextField(
                    controller: lngController,
                    enabled: enabled,
                    keyboardType: const TextInputType.numberWithOptions(
                      decimal: true,
                      signed: true,
                    ),
                    decoration: const InputDecoration(
                      labelText: 'Longitud',
                      border: OutlineInputBorder(),
                      isDense: true,
                    ),
                    onChanged: (_) => onChanged?.call(),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
