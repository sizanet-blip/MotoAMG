import 'package:flutter/material.dart';
import 'package:loc_motos/features/settings/presentation/screens/offline_maps_settings_screen.dart';

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
        ],
      ),
    );
  }
}
