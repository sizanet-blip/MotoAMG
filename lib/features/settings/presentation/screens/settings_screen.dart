import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:loc_motos/core/utils/spain_data_freshness.dart';
import 'package:loc_motos/features/navigation/data/datasources/spain_fuel_datasource.dart';
import 'package:loc_motos/features/navigation/data/datasources/spain_radar_datasource.dart';
import 'package:loc_motos/features/navigation/data/repositories/map_appearance_repository.dart';
import 'package:loc_motos/features/navigation/presentation/providers/navigation_providers.dart';
import 'package:loc_motos/core/theme/app_color_theme.dart';
import 'package:loc_motos/core/theme/app_color_theme_provider.dart';
import 'package:loc_motos/features/settings/presentation/screens/alert_preferences_screen.dart';
import 'package:loc_motos/features/settings/presentation/screens/app_theme_settings_screen.dart';
import 'package:loc_motos/features/settings/presentation/screens/fuel_cache_settings_screen.dart';
import 'package:loc_motos/features/settings/presentation/screens/group_ride_settings_screen.dart';
import 'package:loc_motos/features/settings/presentation/screens/hud_safety_settings_screen.dart';
import 'package:loc_motos/features/settings/presentation/screens/map_appearance_settings_screen.dart';
import 'package:loc_motos/features/settings/presentation/screens/offline_maps_settings_screen.dart';
import 'package:loc_motos/features/settings/presentation/screens/radar_cache_settings_screen.dart';

/// Hub de configuración de la app. Aquí se irán añadiendo más opciones.
class SettingsScreen extends ConsumerWidget {
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final appearance = ref.watch(mapAppearanceProvider);
    final colorTheme = ref.watch(appColorThemeProvider);
    final fuelStatus = ref.watch(spainFuelCacheStatusProvider).asData?.value;
    final radarStatus = ref.watch(spainRadarCacheStatusProvider).asData?.value;
    return Scaffold(
      appBar: AppBar(title: const Text('Configuración')),
      body: ListView(
        children: [
          const SizedBox(height: 8),
          ListTile(
            leading: const Icon(Icons.palette_outlined),
            title: const Text('Tema de la app'),
            subtitle: Text(colorTheme.label),
            trailing: const Icon(Icons.chevron_right),
            onTap: () {
              Navigator.of(context).push(
                MaterialPageRoute<void>(
                  builder: (_) => const AppThemeSettingsScreen(),
                ),
              );
            },
          ),
          ListTile(
            leading: const Icon(Icons.notifications_active_outlined),
            title: const Text('Avisos de navegación'),
            subtitle: const Text(
              'Radares, gasolineras, peajes, curvas y distancias',
            ),
            trailing: const Icon(Icons.chevron_right),
            onTap: () {
              Navigator.of(context).push(
                MaterialPageRoute<void>(
                  builder: (_) => const AlertPreferencesScreen(),
                ),
              );
            },
          ),
          ListTile(
            leading: const Icon(Icons.sports_motorsports_outlined),
            title: const Text('Pantalla al navegar'),
            subtitle: const Text(
              'Que no se apague, más brillo y botones grandes con guantes',
            ),
            trailing: const Icon(Icons.chevron_right),
            onTap: () {
              Navigator.of(context).push(
                MaterialPageRoute<void>(
                  builder: (_) => const HudSafetySettingsScreen(),
                ),
              );
            },
          ),
          ListTile(
            leading: const Icon(Icons.groups_outlined),
            title: const Text('Grupo en ruta'),
            subtitle: const Text(
              'Qué motos ver, botón en navegación y avisos si alguien se queda',
            ),
            trailing: const Icon(Icons.chevron_right),
            onTap: () {
              Navigator.of(context).push(
                MaterialPageRoute<void>(
                  builder: (_) => const GroupRideSettingsScreen(),
                ),
              );
            },
          ),
          ListTile(
            leading: Icon(switch (appearance.mode) {
              MapAppearanceMode.auto => Icons.brightness_auto_rounded,
              MapAppearanceMode.day => Icons.light_mode_rounded,
              MapAppearanceMode.night => Icons.dark_mode_rounded,
            }),
            title: const Text('Mapa día / noche'),
            subtitle: Text(
              '${appearance.mode.label} · ${appearance.mode.subtitle}',
            ),
            trailing: const Icon(Icons.chevron_right),
            onTap: () {
              Navigator.of(context).push(
                MaterialPageRoute<void>(
                  builder: (_) => const MapAppearanceSettingsScreen(),
                ),
              );
            },
          ),
          ListTile(
            leading: const Icon(Icons.map_outlined),
            title: const Text('Mapas offline'),
            subtitle: const Text('Descargar regiones para navegar sin cobertura'),
            trailing: const Icon(Icons.chevron_right),
            onTap: () {
              Navigator.of(context).push(
                MaterialPageRoute<void>(
                  builder: (_) => const OfflineMapsSettingsScreen(),
                ),
              );
            },
          ),
          ListTile(
            leading: const Icon(Icons.speed_outlined),
            title: const Text('Radares offline'),
            subtitle: Text(_radarCacheSubtitle(radarStatus)),
            trailing: const Icon(Icons.chevron_right),
            onTap: () {
              Navigator.of(context).push(
                MaterialPageRoute<void>(
                  builder: (_) => const RadarCacheSettingsScreen(),
                ),
              );
            },
          ),
          ListTile(
            leading: const Icon(Icons.local_gas_station_outlined),
            title: const Text('Gasolineras offline'),
            subtitle: Text(_fuelCacheSubtitle(fuelStatus)),
            trailing: const Icon(Icons.chevron_right),
            onTap: () {
              Navigator.of(context).push(
                MaterialPageRoute<void>(
                  builder: (_) => const FuelCacheSettingsScreen(),
                ),
              );
            },
          ),
        ],
      ),
    );
  }

  static String _fuelCacheSubtitle(SpainFuelCacheStatus? status) {
    if (status == null || !status.isReady) {
      return 'Descargar precios MITECO desde el servidor LocMotos';
    }
    final age = formatSpainDataAge(status.fetchedAt);
    final stale = isSpainFuelDataStale(status.fetchedAt);
    final prefix = stale ? 'Datos antiguos · ' : '';
    return '$prefix${status.count} estaciones · $age';
  }

  static String _radarCacheSubtitle(SpainRadarCacheStatus? status) {
    if (status == null || !status.isReady) {
      return 'Descargar inventario desde el servidor LocMotos';
    }
    final total = status.officialCount + status.osmCount;
    final stale = isSpainRadarCacheStale(
      hasOfficial: status.hasOfficial,
      officialFetchedAt: status.officialFetchedAt,
      hasOsm: status.hasOsm,
      osmFetchedAt: status.osmFetchedAt,
    );
    final prefix = stale ? 'Datos antiguos · ' : '';
    DateTime? newest;
    for (final at in [status.officialFetchedAt, status.osmFetchedAt]) {
      if (at == null) {
        continue;
      }
      if (newest == null || at.isAfter(newest)) {
        newest = at;
      }
    }
    return '$prefix$total radares · ${formatSpainDataAge(newest)}';
  }
}
