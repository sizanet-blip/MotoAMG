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
    this.compact = false,
    this.sidePanel = false,
    this.embedded = false,
  });

  final double speedKmh;
  final int? speedLimitKmh;
  final TimeOfDay eta;
  final Duration remaining;
  final String distanceLabel;

  /// Landscape horizontal bar: menos padding y tipografía más pequeña.
  final bool compact;

  /// Landscape: panel vertical en el lateral (libera el centro del mapa).
  final bool sidePanel;

  /// Dentro de un panel flotante (sin borde/safe area propios).
  final bool embedded;

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

    if (sidePanel) {
      return _SideStatusPanel(
        speedKmh: speedKmh,
        speedLimitKmh: speedLimitKmh,
        etaText: etaText,
        remainingText: remainingText,
        distanceLabel: distanceLabel,
        overspeed: overspeed,
      );
    }

    final statsRow = Row(
      children: [
        _SpeedBlock(
          speedKmh: speedKmh,
          speedLimitKmh: speedLimitKmh,
          overspeed: overspeed,
          compact: compact,
        ),
        _Divider(overspeed: overspeed, compact: compact),
        _StatBlock(
          label: 'Límite',
          value: speedLimitKmh?.toString() ?? '—',
          unit: 'km/h',
          compact: compact,
        ),
        _Divider(overspeed: overspeed, compact: compact),
        _StatBlock(
          label: 'Llegada',
          value: etaText,
          unit: remainingText,
          compact: compact,
        ),
        _Divider(overspeed: overspeed, compact: compact),
        _StatBlock(
          label: 'Restante',
          value: distanceLabel,
          unit: '',
          compact: compact,
        ),
      ],
    );

    if (embedded) {
      return Padding(
        padding: EdgeInsets.symmetric(
          horizontal: compact ? 4 : 8,
          vertical: compact ? 4 : 6,
        ),
        child: statsRow,
      );
    }

    return AnimatedContainer(
      duration: const Duration(milliseconds: 220),
      decoration: BoxDecoration(
        color: overspeed
            ? const Color(0xFF3B1010)
            : NavigationHudTheme.panel,
        borderRadius: BorderRadius.vertical(
          top: Radius.circular(compact ? 14 : 24),
        ),
        boxShadow: const [NavigationHudTheme.panelShadow],
        border: overspeed
            ? Border(
                top: BorderSide(
                  color: const Color(0xFFFF5252),
                  width: compact ? 2 : 3,
                ),
              )
            : null,
      ),
      child: SafeArea(
        top: false,
        child: Padding(
          padding: EdgeInsets.fromLTRB(
            compact ? 8 : 12,
            compact ? 6 : 16,
            compact ? 8 : 12,
            compact ? 4 : 12,
          ),
          child: statsRow,
        ),
      ),
    );
  }
}

class _SideStatusPanel extends StatelessWidget {
  const _SideStatusPanel({
    required this.speedKmh,
    required this.speedLimitKmh,
    required this.etaText,
    required this.remainingText,
    required this.distanceLabel,
    required this.overspeed,
  });

  final double speedKmh;
  final int? speedLimitKmh;
  final String etaText;
  final String remainingText;
  final String distanceLabel;
  final bool overspeed;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 2, vertical: 2),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
            _SideStat(
              label: overspeed ? 'Exceso' : 'Velocidad',
              value: '${speedKmh.round()}',
              unit: speedLimitKmh != null && speedLimitKmh! > 0
                  ? 'km/h · máx $speedLimitKmh'
                  : 'km/h',
              emphasize: overspeed,
              danger: overspeed,
            ),
            const _SideDivider(),
            _SideStat(
              label: 'Límite',
              value: speedLimitKmh?.toString() ?? '—',
              unit: 'km/h',
            ),
            const _SideDivider(),
            _SideStat(
              label: 'Llegada',
              value: etaText,
              unit: remainingText,
            ),
            const _SideDivider(),
            _SideStat(
              label: 'Restante',
              value: distanceLabel,
              unit: '',
            ),
          ],
        ),
    );
  }
}

class _SideStat extends StatelessWidget {
  const _SideStat({
    required this.label,
    required this.value,
    required this.unit,
    this.emphasize = false,
    this.danger = false,
  });

  final String label;
  final String value;
  final String unit;
  final bool emphasize;
  final bool danger;

  @override
  Widget build(BuildContext context) {
    final valueColor = danger
        ? const Color(0xFFFF5252)
        : emphasize
            ? NavigationHudTheme.warning
            : NavigationHudTheme.textPrimary;
    final labelColor = danger
        ? const Color(0xFFFF8A80)
        : NavigationHudTheme.textSecondary;

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2),
      child: Column(
        children: [
          Text(
            label,
            style: TextStyle(
              color: labelColor,
              fontSize: 9,
              fontWeight: FontWeight.w700,
              letterSpacing: 0.2,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            value,
            textAlign: TextAlign.center,
            style: TextStyle(
              color: valueColor,
              fontSize: emphasize ? 18 : 15,
              fontWeight: FontWeight.w800,
              height: 1.05,
            ),
          ),
          if (unit.isNotEmpty) ...[
            const SizedBox(height: 1),
            Text(
              unit,
              textAlign: TextAlign.center,
              style: TextStyle(
                color: labelColor,
                fontSize: 9,
                fontWeight: danger ? FontWeight.w600 : FontWeight.w400,
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class _SideDivider extends StatelessWidget {
  const _SideDivider();

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Container(
        height: 1,
        color: NavigationHudTheme.panelElevated,
      ),
    );
  }
}

class _SpeedBlock extends StatelessWidget {
  const _SpeedBlock({
    required this.speedKmh,
    required this.speedLimitKmh,
    required this.overspeed,
    this.compact = false,
  });

  final double speedKmh;
  final int? speedLimitKmh;
  final bool overspeed;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 220),
        padding: EdgeInsets.symmetric(
          vertical: compact ? 2 : 6,
          horizontal: 4,
        ),
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
                fontSize: compact ? 9 : 11,
                fontWeight: FontWeight.w700,
                letterSpacing: 0.2,
              ),
            ),
            SizedBox(height: compact ? 1 : 4),
            Text(
              '${speedKmh.round()}',
              style: TextStyle(
                color: overspeed
                    ? const Color(0xFFFF5252)
                    : NavigationHudTheme.textPrimary,
                fontSize: compact
                    ? (overspeed ? 20.0 : 16.0)
                    : (overspeed ? 26.0 : 20.0),
                fontWeight: FontWeight.w800,
                height: 1.05,
              ),
            ),
            SizedBox(height: compact ? 0 : 2),
            Text(
              speedLimitKmh != null && speedLimitKmh! > 0
                  ? 'km/h · máx $speedLimitKmh'
                  : 'km/h',
              style: TextStyle(
                color: overspeed
                    ? const Color(0xFFFF8A80)
                    : NavigationHudTheme.textSecondary,
                fontSize: compact ? 9 : 11,
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
  const _Divider({this.overspeed = false, this.compact = false});

  final bool overspeed;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 1,
      height: compact ? 32 : 44,
      margin: EdgeInsets.symmetric(horizontal: compact ? 2 : 4),
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
    this.compact = false,
  });

  final String label;
  final String value;
  final String unit;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Column(
        children: [
          Text(
            label,
            style: TextStyle(
              color: NavigationHudTheme.textSecondary,
              fontSize: compact ? 9 : 11,
              fontWeight: FontWeight.w600,
              letterSpacing: 0.2,
            ),
          ),
          SizedBox(height: compact ? 1 : 4),
          Text(
            value,
            style: TextStyle(
              color: NavigationHudTheme.textPrimary,
              fontSize: compact ? 15 : 20,
              fontWeight: FontWeight.w700,
              height: 1.1,
            ),
          ),
          if (unit.isNotEmpty) ...[
            SizedBox(height: compact ? 0 : 2),
            Text(
              unit,
              style: TextStyle(
                color: NavigationHudTheme.textSecondary,
                fontSize: compact ? 9 : 11,
              ),
              textAlign: TextAlign.center,
            ),
          ],
        ],
      ),
    );
  }
}
