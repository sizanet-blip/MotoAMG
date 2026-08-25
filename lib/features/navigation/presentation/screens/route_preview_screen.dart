import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:loc_motos/core/utils/distance_format.dart';
import 'package:loc_motos/core/utils/navigation_duration_format.dart';
import 'package:loc_motos/features/auth/domain/entities/app_user.dart';
import 'package:loc_motos/features/navigation/domain/entities/hybrid_map_styles.dart';
import 'package:loc_motos/features/navigation/domain/entities/navigation_route.dart';
import 'package:loc_motos/features/navigation/presentation/models/navigation_map_camera_mode.dart';
import 'package:loc_motos/features/navigation/presentation/providers/navigation_providers.dart';
import 'package:loc_motos/features/navigation/presentation/screens/navigation_hud_screen.dart';
import 'package:loc_motos/features/navigation/presentation/widgets/map_network_resume_binder.dart';
import 'package:loc_motos/features/navigation/presentation/widgets/navigation_map_view.dart';
import 'package:loc_motos/features/navigation/presentation/widgets/navigation_map_zoom_controls.dart';
import 'package:loc_motos/features/navigation/presentation/widgets/offline_map_banner.dart';
import 'package:maplibre_gl/maplibre_gl.dart';

class RoutePreviewScreen extends ConsumerWidget {
  const RoutePreviewScreen({
    super.key,
    required this.route,
    required this.user,
  });

  final NavigationRoute route;
  final AppUser user;

  Future<void> _startNavigation(BuildContext context) async {
    await Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => NavigationHudScreen(route: route, user: user),
      ),
    );
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final mapStyleAsync = ref.watch(hybridMapStylesProvider);
    final networkAsync = ref.watch(mapNetworkAvailableProvider);
    // Solo “sin red” cuando el sistema lo confirma (no mientras carga).
    final hasNetwork = networkAsync.asData?.value ?? true;
    final showOfflineBanner = networkAsync.asData?.value == false;

    return MapNetworkResumeBinder(
      child: Scaffold(
        body: mapStyleAsync.when(
          loading: () => const Center(child: CircularProgressIndicator()),
          error: (_, _) =>
              const Center(child: Text('No se pudo cargar el mapa.')),
          data: (mapStyles) => Column(
            children: [
              Expanded(
                child: _RoutePreviewMapLayer(
                  route: route,
                  mapStyles: mapStyles,
                  hasNetwork: hasNetwork,
                  showOfflineBanner: showOfflineBanner,
                ),
              ),
              _RoutePreviewSheet(
                route: route,
                preferencesSummary:
                    ref.watch(routePreferencesProvider).summaryLabel,
                onStart: () => _startNavigation(context),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _RoutePreviewMapLayer extends StatefulWidget {
  const _RoutePreviewMapLayer({
    required this.route,
    required this.mapStyles,
    required this.hasNetwork,
    required this.showOfflineBanner,
  });

  final NavigationRoute route;
  final HybridMapStyles mapStyles;
  final bool hasNetwork;
  final bool showOfflineBanner;

  @override
  State<_RoutePreviewMapLayer> createState() => _RoutePreviewMapLayerState();
}

class _RoutePreviewMapLayerState extends State<_RoutePreviewMapLayer> {
  MapLibreMapController? _mapController;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final top = MediaQuery.paddingOf(context).top + 8;

    return Stack(
      fit: StackFit.expand,
      children: [
        NavigationMapView(
          route: widget.route,
          mapStyles: widget.mapStyles,
          hasNetwork: widget.hasNetwork,
          cameraMode: NavigationMapCameraMode.fitRoute,
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
            color: colors.surface.withValues(alpha: 0.96),
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
            child: NavigationMapZoomControls(controller: _mapController!),
          ),
        if (widget.showOfflineBanner)
          const Positioned(
            left: 16,
            right: 16,
            bottom: 16,
            child: OfflineMapBanner(compact: true),
          ),
      ],
    );
  }
}

class _RoutePreviewSheet extends StatelessWidget {
  const _RoutePreviewSheet({
    required this.route,
    required this.preferencesSummary,
    required this.onStart,
  });

  final NavigationRoute route;
  final String preferencesSummary;
  final VoidCallback onStart;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colors = theme.colorScheme;

    return Material(
      elevation: 12,
      borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
      color: colors.surface,
      child: SafeArea(
        top: false,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 16, 20, 16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Center(
                child: Container(
                  width: 36,
                  height: 4,
                  decoration: BoxDecoration(
                    color: colors.outlineVariant,
                    borderRadius: BorderRadius.circular(99),
                  ),
                ),
              ),
              const SizedBox(height: 16),
              Text(
                route.hasWaypoints
                    ? 'Vista previa del circuito'
                    : 'Vista previa de la ruta',
                style: theme.textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(height: 12),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  _RouteStatChip(
                    icon: Icons.straighten,
                    label: formatRideDistance(route.distanceMeters),
                  ),
                  _RouteStatChip(
                    icon: Icons.schedule,
                    label: formatNavigationDuration(route.durationSeconds),
                  ),
                  if (route.hasWaypoints)
                    _RouteStatChip(
                      icon: Icons.place_outlined,
                      label: '${route.waypoints.length} parada'
                          '${route.waypoints.length == 1 ? '' : 's'}',
                    ),
                  _RouteStatChip(
                    icon: Icons.tune,
                    label: preferencesSummary,
                  ),
                ],
              ),
              const SizedBox(height: 16),
              _RouteEndpointRow(
                icon: Icons.trip_origin,
                iconColor: const Color(0xFF2E7D32),
                title: 'Origen',
                subtitle: route.originDisplay,
              ),
              if (route.hasWaypoints) ...[
                for (var i = 0; i < route.waypoints.length; i++) ...[
                  const SizedBox(height: 8),
                  _RouteEndpointRow(
                    icon: Icons.radio_button_checked,
                    iconColor: const Color(0xFFF9A825),
                    title: 'Parada ${i + 1}',
                    subtitle:
                        '${route.waypoints[i].lat.toStringAsFixed(5)}, '
                        '${route.waypoints[i].lng.toStringAsFixed(5)}',
                  ),
                ],
              ],
              const SizedBox(height: 8),
              _RouteEndpointRow(
                icon: Icons.flag_outlined,
                iconColor: const Color(0xFFC62828),
                title: 'Destino',
                subtitle: route.destinationDisplay,
              ),
              const SizedBox(height: 16),
              FilledButton.icon(
                onPressed: onStart,
                icon: const Icon(Icons.navigation),
                label: const Text('Empezar navegación'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _RouteStatChip extends StatelessWidget {
  const _RouteStatChip({required this.icon, required this.label});

  final IconData icon;
  final String label;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: colors.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(999),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 16, color: colors.primary),
          const SizedBox(width: 6),
          Text(
            label,
            style: Theme.of(context).textTheme.labelLarge?.copyWith(
                  fontWeight: FontWeight.w600,
                ),
          ),
        ],
      ),
    );
  }
}

class _RouteEndpointRow extends StatelessWidget {
  const _RouteEndpointRow({
    required this.icon,
    required this.iconColor,
    required this.title,
    required this.subtitle,
  });

  final IconData icon;
  final Color iconColor;
  final String title;
  final String subtitle;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Row(
      children: [
        Icon(icon, color: iconColor, size: 20),
        const SizedBox(width: 10),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: theme.textTheme.labelMedium?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                ),
              ),
              Text(
                subtitle,
                style: theme.textTheme.bodyMedium,
                maxLines: 3,
                overflow: TextOverflow.ellipsis,
              ),
            ],
          ),
        ),
      ],
    );
  }
}
