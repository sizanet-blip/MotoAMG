import 'package:flutter/material.dart';
import 'package:loc_motos/features/navigation/presentation/theme/navigation_hud_theme.dart';

class NavigationStatusBar extends StatelessWidget {
  const NavigationStatusBar({
    super.key,
    required this.speedKmh,
    required this.speedLimitKmh,
    required this.eta,
    required this.remaining,
    required this.distanceLabel,
  });

  final double speedKmh;
  final int? speedLimitKmh;
  final TimeOfDay eta;
  final Duration remaining;
  final String distanceLabel;

  @override
  Widget build(BuildContext context) {
    final etaText =
        '${eta.hour.toString().padLeft(2, '0')}:${eta.minute.toString().padLeft(2, '0')}';
    final remainingText =
        '${remaining.inHours > 0 ? '${remaining.inHours} h ' : ''}'
        '${remaining.inMinutes.remainder(60)} min';

    return DecoratedBox(
      decoration: const BoxDecoration(
        color: NavigationHudTheme.panel,
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
        boxShadow: [NavigationHudTheme.panelShadow],
      ),
      child: SafeArea(
        top: false,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(12, 16, 12, 12),
          child: Row(
            children: [
              _StatBlock(
                label: 'Velocidad',
                value: '${speedKmh.round()}',
                unit: 'km/h',
                highlight: speedLimitKmh != null && speedKmh > speedLimitKmh!,
              ),
              _Divider(),
              _StatBlock(
                label: 'Límite',
                value: speedLimitKmh?.toString() ?? '—',
                unit: 'km/h',
              ),
              _Divider(),
              _StatBlock(
                label: 'Llegada',
                value: etaText,
                unit: remainingText,
              ),
              _Divider(),
              _StatBlock(
                label: 'Restante',
                value: distanceLabel,
                unit: '',
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _Divider extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Container(
      width: 1,
      height: 44,
      margin: const EdgeInsets.symmetric(horizontal: 4),
      color: NavigationHudTheme.panelElevated,
    );
  }
}

class _StatBlock extends StatelessWidget {
  const _StatBlock({
    required this.label,
    required this.value,
    required this.unit,
    this.highlight = false,
  });

  final String label;
  final String value;
  final String unit;
  final bool highlight;

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Column(
        children: [
          Text(
            label,
            style: const TextStyle(
              color: NavigationHudTheme.textSecondary,
              fontSize: 11,
              fontWeight: FontWeight.w600,
              letterSpacing: 0.2,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            value,
            style: TextStyle(
              color: highlight ? const Color(0xFFFF5252) : NavigationHudTheme.textPrimary,
              fontSize: 20,
              fontWeight: FontWeight.w700,
              height: 1.1,
            ),
          ),
          if (unit.isNotEmpty) ...[
            const SizedBox(height: 2),
            Text(
              unit,
              style: const TextStyle(
                color: NavigationHudTheme.textSecondary,
                fontSize: 11,
              ),
              textAlign: TextAlign.center,
            ),
          ],
        ],
      ),
    );
  }
}
