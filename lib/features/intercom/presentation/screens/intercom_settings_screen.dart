import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:loc_motos/features/intercom/presentation/providers/intercom_providers.dart';

/// Defaults personales de Hablar/Oír. El ON/OFF del canal lo marca el creador.
class IntercomSettingsScreen extends ConsumerWidget {
  const IntercomSettingsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final prefs = ref.watch(intercomPreferencesProvider);
    final controller = ref.read(intercomPreferencesProvider.notifier);

    return Scaffold(
      appBar: AppBar(title: const Text('Intercom')),
      body: ListView(
        padding: const EdgeInsets.only(bottom: 32),
        children: [
          const SizedBox(height: 8),
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
            child: Text(
              'El creador del grupo activa el intercom en Opciones del grupo. '
              'Aquí solo defines si al conectar quieres hablar y oír por defecto.',
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    color: Theme.of(context).colorScheme.onSurfaceVariant,
                  ),
            ),
          ),
          SwitchListTile(
            secondary: const Icon(Icons.mic_outlined),
            title: const Text('Hablar por defecto'),
            subtitle: const Text(
              'Micrófono abierto al unirte al canal del grupo',
            ),
            value: prefs.defaultSpeak,
            onChanged: (value) => unawaited(controller.setDefaultSpeak(value)),
          ),
          SwitchListTile(
            secondary: const Icon(Icons.volume_up_outlined),
            title: const Text('Escuchar por defecto'),
            subtitle: const Text('Oír al pelotón al unirte al canal'),
            value: prefs.defaultListen,
            onChanged: (value) =>
                unawaited(controller.setDefaultListen(value)),
          ),
        ],
      ),
    );
  }
}
