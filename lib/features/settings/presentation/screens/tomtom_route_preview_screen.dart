import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:moto_amg/core/api_usage/tomtom_route_preview_snapshot.dart';
import 'package:moto_amg/core/utils/distance_format.dart';
import 'package:moto_amg/core/utils/navigation_duration_format.dart';
import 'package:moto_amg/features/navigation/data/models/navigation_route_model.dart';
import 'package:moto_amg/features/navigation/domain/entities/alert_preferences.dart';
import 'package:moto_amg/features/navigation/domain/entities/navigation_route.dart';
import 'package:moto_amg/features/navigation/presentation/helpers/speed_limit_compare.dart';
import 'package:moto_amg/features/navigation/presentation/models/navigation_map_camera_mode.dart';
import 'package:moto_amg/features/navigation/presentation/providers/navigation_providers.dart';
import 'package:moto_amg/features/navigation/presentation/widgets/collapsible_map_bottom_panel.dart';
import 'package:moto_amg/features/navigation/presentation/widgets/navigation_map_view.dart';
import 'package:moto_amg/features/navigation/presentation/widgets/navigation_map_zoom_controls.dart';
import 'package:maplibre_gl/maplibre_gl.dart';

enum _LimitPreviewMode { motoAmg, tomtom, differences }

/// Mapa de la última ruta consultada con TomTom (datos en memoria, sin nueva API).
class TomTomRoutePreviewScreen extends ConsumerStatefulWidget {
  const TomTomRoutePreviewScreen({
    super.key,
    required this.snapshot,
  });

  final TomTomRoutePreviewSnapshot snapshot;

  @override
  ConsumerState<TomTomRoutePreviewScreen> createState() =>
      _TomTomRoutePreviewScreenState();
}

class _TomTomRoutePreviewScreenState
    extends ConsumerState<TomTomRoutePreviewScreen> {
  MapLibreMapController? _mapController;
  _LimitPreviewMode _mode = _LimitPreviewMode.motoAmg;

  @override
  Widget build(BuildContext context) {
    final baseRoute = widget.snapshot.route;
    final compareStats = widget.snapshot.canCompare
        ? widget.snapshot.compareStats()
        : null;
    final displayRoute = _displayRoute(baseRoute);
    final mapStylesAsync = ref.watch(hybridMapStylesProvider);
    final hasNetwork =
        ref.watch(mapNetworkAvailableProvider).asData?.value ?? true;
    const mapAlertPrefs = AlertPreferences(
      radarShowOnMap: false,
      fuelShowOnMap: false,
      tollShowOnMap: false,
      curvesShowOnMap: false,
    );
    final top = MediaQuery.paddingOf(context).top + 8;

    return Scaffold(
      body: mapStylesAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (_, _) => const Center(child: Text('No se pudo cargar el mapa.')),
        data: (mapStyles) {
          return Stack(
            fit: StackFit.expand,
            children: [
              NavigationMapView(
                key: ValueKey(_mode),
                route: displayRoute,
                mapStyles: mapStyles,
                hasNetwork: hasNetwork,
                alertPreferences: mapAlertPrefs,
                showSpeedLimitSegments: true,
                speedLimitDiffs: _mode == _LimitPreviewMode.differences
                    ? compareStats?.differences
                    : null,
                cameraMode: NavigationMapCameraMode.fitRoute,
                preferDarkMap: ref.watch(effectiveMapDarkProvider),
                lowGlCompat: ref.watch(lowGlMapModeProvider),
                onControllerReady: (controller) {
                  if (_mapController == controller) {
                    return;
                  }
                  setState(() => _mapController = controller);
                },
              ),
              Positioned(
                top: top,
                left: 8,
                child: Material(
                  color: Theme.of(context)
                      .colorScheme
                      .surface
                      .withValues(alpha: 0.96),
                  shape: const CircleBorder(),
                  elevation: 2,
                  clipBehavior: Clip.antiAlias,
                  child: BackButton(
                    onPressed: () => Navigator.of(context).pop(),
                  ),
                ),
              ),
              if (_mapController != null)
                Positioned(
                  top: top,
                  right: 12,
                  child: NavigationMapZoomControls(
                    controller: _mapController!,
                  ),
                ),
              if (widget.snapshot.canCompare)
                Positioned(
                  left: 12,
                  right: 12,
                  top: top + 52,
                  child: Material(
                    elevation: 2,
                    borderRadius: BorderRadius.circular(14),
                    color: Theme.of(context)
                        .colorScheme
                        .surface
                        .withValues(alpha: 0.96),
                    child: Padding(
                      padding: const EdgeInsets.all(8),
                      child: SegmentedButton<_LimitPreviewMode>(
                        segments: const [
                          ButtonSegment(
                            value: _LimitPreviewMode.motoAmg,
                            label: Text('MotoAMG'),
                            icon: Icon(Icons.home_work_outlined, size: 18),
                          ),
                          ButtonSegment(
                            value: _LimitPreviewMode.tomtom,
                            label: Text('TomTom'),
                            icon: Icon(Icons.cloud_outlined, size: 18),
                          ),
                          ButtonSegment(
                            value: _LimitPreviewMode.differences,
                            label: Text('Diferencias'),
                            icon: Icon(Icons.compare_arrows_rounded, size: 18),
                          ),
                        ],
                        selected: {_mode},
                        onSelectionChanged: (selection) {
                          setState(() => _mode = selection.first);
                        },
                      ),
                    ),
                  ),
                ),
              Positioned(
                left: 12,
                bottom: MediaQuery.paddingOf(context).bottom + 168,
                child: _Legend(mode: _mode),
              ),
              Align(
                alignment: Alignment.bottomCenter,
                child: CollapsibleMapBottomPanel(
                  title: baseRoute.destinationDisplay,
                  subtitle: _panelSubtitle(compareStats),
                  initiallyExpanded: _mode == _LimitPreviewMode.differences,
                  maxExpandedHeight: MediaQuery.sizeOf(context).height * 0.34,
                  child: _PanelBody(
                    snapshot: widget.snapshot,
                    mode: _mode,
                    compareStats: compareStats,
                  ),
                ),
              ),
            ],
          );
        },
      ),
    );
  }

  NavigationRoute _displayRoute(NavigationRoute baseRoute) {
    if (baseRoute is! NavigationRouteModel) {
      return baseRoute;
    }
    if (!widget.snapshot.canCompare) {
      return baseRoute;
    }
    final segments = switch (_mode) {
      _LimitPreviewMode.motoAmg => widget.snapshot.motoAmgSegments,
      _LimitPreviewMode.tomtom => widget.snapshot.tomtomSegments,
      _LimitPreviewMode.differences => baseRoute.speedLimitSegments,
    };
    return baseRoute.copyWithSpeedLimits(segments);
  }

  String _panelSubtitle(SpeedLimitCompareStats? stats) {
    final route = widget.snapshot.route;
    final base =
        '${formatRideDistance(route.distanceMeters)} · '
        '${formatNavigationDurationCompact(route.durationSeconds)}';
    if (stats == null) {
      return '$base · ${widget.snapshot.segmentCount} tramos';
    }
    if (!stats.hasDifferences) {
      return '$base · sin diferencias';
    }
    return '$base · ${stats.differenceCount} tramos distintos';
  }
}

class _PanelBody extends StatelessWidget {
  const _PanelBody({
    required this.snapshot,
    required this.mode,
    required this.compareStats,
  });

  final TomTomRoutePreviewSnapshot snapshot;
  final _LimitPreviewMode mode;
  final SpeedLimitCompareStats? compareStats;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final route = snapshot.route;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(
          'Desde ${route.originDisplay}',
          style: theme.textTheme.bodyMedium,
        ),
        const SizedBox(height: 8),
        Text(
          'Consultada el ${_formatWhen(snapshot.enrichedAt)}. '
          'Datos guardados en esta sesión; no se vuelve a llamar a TomTom.',
          style: theme.textTheme.bodySmall?.copyWith(
            color: theme.colorScheme.onSurfaceVariant,
          ),
        ),
        if (compareStats != null) ...[
          const SizedBox(height: 12),
          Text(
            _modeHint(mode, compareStats!),
            style: theme.textTheme.bodySmall,
          ),
          if (mode == _LimitPreviewMode.differences &&
              compareStats!.hasDifferences) ...[
            const SizedBox(height: 10),
            for (final diff in compareStats!.differences.take(12))
              Padding(
                padding: const EdgeInsets.only(bottom: 6),
                child: Row(
                  children: [
                    Text(
                      formatRideDistance(diff.beginAlongMeters),
                      style: theme.textTheme.labelMedium?.copyWith(
                        fontFeatures: const [FontFeature.tabularFigures()],
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        'MotoAMG ${diff.motoAmgKmh ?? '—'} → '
                        'TomTom ${diff.tomtomKmh ?? '—'} km/h',
                        style: theme.textTheme.bodySmall,
                      ),
                    ),
                  ],
                ),
              ),
            if (compareStats!.differences.length > 12)
              Text(
                '… y ${compareStats!.differences.length - 12} más',
                style: theme.textTheme.bodySmall?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                ),
              ),
          ],
        ],
      ],
    );
  }

  static String _modeHint(_LimitPreviewMode mode, SpeedLimitCompareStats stats) {
    return switch (mode) {
      _LimitPreviewMode.motoAmg =>
        'Límites MotoAMG (OSM/DGT). ${stats.matchingPoints} puntos coinciden con TomTom.',
      _LimitPreviewMode.tomtom =>
        'Límites TomTom. Compara con la pestaña MotoAMG o Diferencias.',
      _LimitPreviewMode.differences => stats.hasDifferences
          ? '${stats.differenceCount} tramos donde MotoAMG y TomTom no coinciden '
              '(morado en el mapa). LM = MotoAMG, TT = TomTom.'
          : 'MotoAMG y TomTom coinciden en toda la ruta.',
    };
  }

  static String _formatWhen(DateTime at) {
    final local = at.toLocal();
    final h = local.hour.toString().padLeft(2, '0');
    final m = local.minute.toString().padLeft(2, '0');
    return '${local.day}/${local.month}/${local.year} a las $h:$m';
  }
}

class _Legend extends StatelessWidget {
  const _Legend({required this.mode});

  final _LimitPreviewMode mode;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Material(
      elevation: 2,
      borderRadius: BorderRadius.circular(12),
      color: theme.colorScheme.surface.withValues(alpha: 0.94),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              switch (mode) {
                _LimitPreviewMode.motoAmg => 'MotoAMG',
                _LimitPreviewMode.tomtom => 'TomTom',
                _LimitPreviewMode.differences => 'Diferencias',
              },
              style: theme.textTheme.labelMedium?.copyWith(
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(height: 6),
            if (mode == _LimitPreviewMode.differences) ...[
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    width: 18,
                    height: 4,
                    decoration: BoxDecoration(
                      color: const Color(0xFF7B1FA2),
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Text('No coinciden', style: theme.textTheme.bodySmall),
                ],
              ),
              const SizedBox(height: 4),
              Text('LM / TT en la señal', style: theme.textTheme.bodySmall),
            ] else ...[
              for (final entry in const [
                (50, Color(0xFF558B2F)),
                (90, Color(0xFFEF6C00)),
                (120, Color(0xFFC62828)),
              ])
                Padding(
                  padding: const EdgeInsets.only(bottom: 4),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Container(
                        width: 18,
                        height: 4,
                        decoration: BoxDecoration(
                          color: entry.$2,
                          borderRadius: BorderRadius.circular(2),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Text('${entry.$1} km/h', style: theme.textTheme.bodySmall),
                    ],
                  ),
                ),
            ],
          ],
        ),
      ),
    );
  }
}
