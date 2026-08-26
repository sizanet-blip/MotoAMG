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

  bool get _overspeed {
    final limit = speedLimitKmh;
    return limit != null && limit > 0 && speedKmh > limit + 1;
  }

  @override
  Widget build(BuildContext context) {
    final etaText =
        '${eta.hour.toString().padLeft(2, '0')}:${eta.minute.toString().padLeft(2, '0')}';
    final remainingText =
        '${remaining.inHours > 0 ? '${remaining.inHours} h ' : ''}'
        '${remaining.inMinutes.remainder(60)} min';
    final overspeed = _overspeed;

    return AnimatedContainer(
      duration: const Duration(milliseconds: 220),
      decoration: BoxDecoration(
        color: overspeed
            ? const Color(0xFF3B1010)
            : NavigationHudTheme.panel,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
        boxShadow: const [NavigationHudTheme.panelShadow],
        border: overspeed
            ? const Border(
                top: BorderSide(color: Color(0xFFFF5252), width: 3),
              )
            : null,
      ),
      child: SafeArea(
        top: false,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(12, 16, 12, 12),
          child: Row(
            children: [
              _SpeedBlock(
                speedKmh: speedKmh,
                speedLimitKmh: speedLimitKmh,
                overspeed: overspeed,
              ),
              _Divider(overspeed: overspeed),
              _StatBlock(
                label: 'Límite',
                value: speedLimitKmh?.toString() ?? '—',
                unit: 'km/h',
              ),
              _Divider(overspeed: overspeed),
              _StatBlock(
                label: 'Llegada',
                value: etaText,
                unit: remainingText,
              ),
              _Divider(overspeed: overspeed),
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

class _SpeedBlock extends StatelessWidget {
  const _SpeedBlock({
    required this.speedKmh,
    required this.speedLimitKmh,
    required this.overspeed,
  });

  final double speedKmh;
  final int? speedLimitKmh;
  final bool overspeed;

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 220),
        padding: const EdgeInsets.symmetric(vertical: 6, horizontal: 4),
        decoration: BoxDecoration(
          color: overspeed
              ? const Color(0xFFFF5252).withValues(alpha: 0.22)
              : Colors.transparent,
          borderRadius: BorderRadius.circular(12),
          border: overspeed
              ? Border.all(color: const Color(0xFFFF5252), width: 1.5)
              : null,
        ),
        child: Column(
          children: [
            Text(
              overspeed ? 'Exceso' : 'Velocidad',
              style: TextStyle(
                color: overspeed
                    ? const Color(0xFFFF8A80)
                    : NavigationHudTheme.textSecondary,
                fontSize: 11,
                fontWeight: FontWeight.w700,
                letterSpacing: 0.2,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              '${speedKmh.round()}',
              style: TextStyle(
                color: overspeed
                    ? const Color(0xFFFF5252)
                    : NavigationHudTheme.textPrimary,
                fontSize: overspeed ? 26 : 20,
                fontWeight: FontWeight.w800,
                height: 1.05,
              ),
            ),
            const SizedBox(height: 2),
            Text(
              speedLimitKmh != null && speedLimitKmh! > 0
                  ? 'km/h · máx $speedLimitKmh'
                  : 'km/h',
              style: TextStyle(
                color: overspeed
                    ? const Color(0xFFFF8A80)
                    : NavigationHudTheme.textSecondary,
                fontSize: 11,
                fontWeight: overspeed ? FontWeight.w600 : FontWeight.w400,
              ),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }
}

class _Divider extends StatelessWidget {
  const _Divider({this.overspeed = false});

  final bool overspeed;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 1,
      height: 44,
      margin: const EdgeInsets.symmetric(horizontal: 4),
      color: overspeed
          ? const Color(0xFFFF5252).withValues(alpha: 0.35)
          : NavigationHudTheme.panelElevated,
    );
  }
}

class _StatBlock extends StatelessWidget {
  const _StatBlock({
    required this.label,
    required this.value,
    required this.unit,
  });

  final String label;
  final String value;
  final String unit;

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
            style: const TextStyle(
              color: NavigationHudTheme.textPrimary,
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
