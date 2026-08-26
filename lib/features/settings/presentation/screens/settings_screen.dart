import 'package:flutter/material.dart';
import 'package:loc_motos/features/settings/presentation/screens/alert_preferences_screen.dart';
import 'package:loc_motos/features/settings/presentation/screens/fuel_cache_settings_screen.dart';
import 'package:loc_motos/features/settings/presentation/screens/offline_maps_settings_screen.dart';
import 'package:loc_motos/features/settings/presentation/screens/radar_cache_settings_screen.dart';

/// Hub de configuración de la app. Aquí se irán añadiendo más opciones.
class SettingsScreen extends StatelessWidget {
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Configuración')),
      body: ListView(
        children: [
          const SizedBox(height: 8),
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
            subtitle: const Text(
              'Descargar inventario desde el servidor LocMotos',
            ),
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
            subtitle: const Text(
              'Descargar precios MITECO desde el servidor LocMotos',
            ),
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
}
