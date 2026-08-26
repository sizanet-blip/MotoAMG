import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:loc_motos/features/navigation/presentation/providers/navigation_providers.dart';

/// Preferencias de pantalla y controles al navegar.
class HudSafetySettingsScreen extends ConsumerWidget {
  const HudSafetySettingsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final prefs = ref.watch(hudSafetyProvider);
    final controller = ref.read(hudSafetyProvider.notifier);

    return Scaffold(
      appBar: AppBar(title: const Text('Pantalla al navegar')),
      body: ListView(
        children: [
          const SizedBox(height: 8),
          SwitchListTile(
            secondary: const Icon(Icons.smartphone_outlined),
            title: const Text('Mantener pantalla encendida'),
            subtitle: const Text(
              'Así no se apaga sola mientras estás en ruta',
            ),
            value: prefs.keepScreenOn,
            onChanged: controller.setKeepScreenOn,
          ),
          SwitchListTile(
            secondary: const Icon(Icons.wb_sunny_outlined),
            title: const Text('Más brillo en la ruta'),
            subtitle: const Text(
              'Sube el brillo al empezar a navegar y lo deja como estaba al salir',
            ),
            value: prefs.highBrightness,
            onChanged: controller.setHighBrightness,
          ),
          const Divider(height: 24),
          SwitchListTile(
            secondary: const Icon(Icons.sports_motorsports_outlined),
            title: const Text('Botones grandes (con guantes)'),
            subtitle: const Text(
              'Silenciar y cancelar más fáciles de pulsar con el casco puesto',
            ),
            value: prefs.helmetMode,
            onChanged: controller.setHelmetMode,
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
            child: Text(
              'Si lo activas, al navegar verás abajo dos botones grandes: '
              'uno para silenciar la voz y otro para cancelar la ruta.',
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: Theme.of(context).colorScheme.onSurfaceVariant,
                  ),
            ),
          ),
        ],
      ),
    );
  }
}
