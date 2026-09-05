import 'package:flutter/material.dart';
import 'package:moto_amg/core/theme/hub_style.dart';

/// Botón redondo + etiqueta (mismo lenguaje que el mapa de grupo).
class MapQuickActionTile extends StatelessWidget {
  const MapQuickActionTile({
    super.key,
    required this.icon,
    required this.label,
    required this.onTap,
    this.tooltip,
    this.emphasized = false,
    this.enabled = true,
    this.badge,
  });

  final IconData icon;
  final String label;
  final VoidCallback? onTap;
  final String? tooltip;
  final bool emphasized;
  final bool enabled;
  final String? badge;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final active = enabled && onTap != null;
    final bg = !active
        ? const Color(0xFFF3F4F6)
        : emphasized
            ? HubStyle.accent.withValues(alpha: 0.14)
            : const Color(0xFFF3F4F6);
    final fg = !active
        ? HubStyle.subtitle.withValues(alpha: 0.45)
        : emphasized
            ? HubStyle.accent
            : HubStyle.subtitle;

    return Tooltip(
      message: tooltip ?? label,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Material(
            color: bg,
            shape: const CircleBorder(),
            child: InkWell(
              customBorder: const CircleBorder(),
              onTap: active ? onTap : null,
              child: SizedBox(
                width: 44,
                height: 44,
                child: Stack(
                  alignment: Alignment.center,
                  children: [
                    Icon(icon, color: fg, size: 22),
                    if (badge != null && active)
                      Positioned(
                        right: 4,
                        top: 4,
                        child: CircleAvatar(
                          radius: 8,
                          backgroundColor: HubStyle.accent,
                          child: Text(
                            badge!,
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 10,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ),
                      ),
                  ],
                ),
              ),
            ),
          ),
          const SizedBox(height: 4),
          Text(
            label,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            textAlign: TextAlign.center,
            style: HubStyle.caption(
              color: active ? HubStyle.subtitle : colors.onSurfaceVariant,
            ),
          ),
        ],
      ),
    );
  }
}
